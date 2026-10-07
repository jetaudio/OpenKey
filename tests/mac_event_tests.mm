#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#include "Engine.h"
#include "test_config.h"
#include <iostream>
#include <cstdlib>

int vSendKeyStepByStep=0, vFixChromiumBrowser=0, vPerformLayoutCompat=0;
static int recoveryCalls=0, backspaceCreates=0, assertions=0, switches=0;
static NSArray *testWindows=@[];
static pid_t testFocusedPID=0;
static AXError testFocusError=kAXErrorSuccess;
static NSDictionary *testInputSource;
static CFTypeRef borrowedLanguage=NULL;
static int sourceReleases=0, borrowedReleases=0;
struct SentEvent { CGEventType type; CGKeyCode key; CGEventFlags flags; std::u16string text; };
static std::vector<SentEvent> sent;
static void captureEvent(CGEventTapProxy, CGEventRef);
static CGEventRef createKeyboardEvent(CGEventSourceRef, CGKeyCode, bool);
static CFArrayRef windowList(CGWindowListOption, CGWindowID);
static AXError focusedElement(AXUIElementRef, CFStringRef, CFTypeRef *);
static AXError getFocusedPID(AXUIElementRef, pid_t *);
static TISInputSourceRef copyInputSource(void);
static void *inputSourceProperty(TISInputSourceRef, CFStringRef);
static void releaseObject(CFTypeRef);

// Intercept every post: these tests never send keys to the user's applications.
#define CGEventTapPostEvent captureEvent
#define CGEventCreateKeyboardEvent createKeyboardEvent
#define CGWindowListCopyWindowInfo windowList
#define AXUIElementCopyAttributeValue focusedElement
#define AXUIElementGetPid getFocusedPID
#define TISCopyCurrentKeyboardInputSource copyInputSource
#define TISGetInputSourceProperty inputSourceProperty
#define CFRelease releaseObject
#include "../Sources/OpenKey/macOS/ModernKey/OpenKey.mm"
#undef CGEventTapPostEvent
#undef CGEventCreateKeyboardEvent
#undef CGWindowListCopyWindowInfo
#undef AXUIElementCopyAttributeValue
#undef AXUIElementGetPid
#undef TISCopyCurrentKeyboardInputSource
#undef TISGetInputSourceProperty
#undef CFRelease

AppDelegate *appDelegate=nil;
ViewController *viewController=nil;
extern "C" void OpenKeyReEnableEventTap(void) { ++recoveryCalls; }

@interface TestDelegate : NSObject
- (void)setInputMethod:(int)language willNotify:(BOOL)notify;
@end
@implementation TestDelegate
- (void)setInputMethod:(int)language willNotify:(BOOL)notify { vLanguage=language; ++switches; }
@end

static void expect(bool condition, const char *label) {
    ++assertions;
    if (!condition) { std::cerr << "FAIL: " << label << '\n'; std::exit(1); }
}
static CGEventRef createKeyboardEvent(CGEventSourceRef source, CGKeyCode key, bool down) {
    if (key == KEY_DELETE) ++backspaceCreates;
    return CGEventCreateKeyboardEvent(source, key, down);
}
static void captureEvent(CGEventTapProxy proxy, CGEventRef event) {
    UniChar text[64]; UniCharCount count=0;
    CGEventKeyboardGetUnicodeString(event, 64, &count, text);
    sent.push_back({CGEventGetType(event), (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode),
        CGEventGetFlags(event), std::u16string((char16_t *)text, count)});
}
static CFArrayRef windowList(CGWindowListOption option, CGWindowID window) {
    return (CFArrayRef)CFRetain((__bridge CFArrayRef)testWindows);
}
static AXError focusedElement(AXUIElementRef element, CFStringRef attribute, CFTypeRef *value) {
    if (testFocusError != kAXErrorSuccess) return testFocusError;
    *value = AXUIElementCreateApplication(testFocusedPID);
    return kAXErrorSuccess;
}
static AXError getFocusedPID(AXUIElementRef element, pid_t *pid) { *pid=testFocusedPID; return kAXErrorSuccess; }
static TISInputSourceRef copyInputSource(void) {
    return testInputSource == nil ? NULL : (TISInputSourceRef)CFRetain((__bridge CFTypeRef)testInputSource);
}
static void *inputSourceProperty(TISInputSourceRef source, CFStringRef key) {
    return (__bridge void *)testInputSource[@"languages"];
}
static void releaseObject(CFTypeRef object) {
    if (object == borrowedLanguage) { ++borrowedReleases; return; }
    if (object == (__bridge CFTypeRef)testInputSource) ++sourceReleases;
    CFRelease(object);
}

static NSDictionary *spotlight(double alpha, int layer) {
    return @{(__bridge NSString *)kCGWindowOwnerName:@"Spotlight",
        (__bridge NSString *)kCGWindowAlpha:@(alpha), (__bridge NSString *)kCGWindowLayer:@(layer),
        (__bridge NSString *)kCGWindowOwnerPID:@4242};
}
static std::u16string typedText() {
    std::u16string result;
    expect(sent.size()%2 == 0, "paired down/up events");
    for (size_t i=0; i<sent.size(); i+=2) {
        expect(sent[i].type == kCGEventKeyDown && sent[i+1].type == kCGEventKeyUp, "event ordering");
        expect(sent[i].text == sent[i+1].text, "identical down/up payloads");
        expect(sent[i].text.size() <= 16, "bounded Unicode event payload");
        result += sent[i].text;
    }
    return result;
}
static void callbackKey(CGEventType type, CGKeyCode key, CGEventFlags flags) {
    CGEventRef event=CGEventCreateKeyboardEvent(NULL,key,type==kCGEventKeyDown);
    CGEventSetType(event,type); CGEventSetFlags(event,flags);
    OpenKeyCallback(NULL,type,event,NULL);
    CFRelease(event);
}

int main() { @autoreleasepool {
    TestDelegate *delegate=[TestDelegate new]; appDelegate=(AppDelegate *)delegate;
    myEventSource=CGEventSourceCreate(kCGEventSourceStatePrivate);
    pData=(vKeyHookState *)vKeyInit();
    _syncKey={2}; _lastFlag=kCGEventFlagMaskAlternate;
    expect(OpenKeyCallback(NULL,kCGEventTapDisabledByTimeout,NULL,NULL)==NULL, "timeout handled before dereferencing event");
    expect(OpenKeyCallback(NULL,kCGEventTapDisabledByUserInput,NULL,NULL)==NULL, "user-input disable handled");
    expect(recoveryCalls==2 && _lastFlag==0 && _syncKey.empty(), "recover tap and discard stale state");

    vLanguage=0; vUseMacro=0; vSwitchKeyStatus=0xFE0010FE;
    callbackKey(kCGEventFlagsChanged,63,kCGEventFlagMaskSecondaryFn);
    callbackKey(kCGEventFlagsChanged,63,0);
    expect(switches==1 && vLanguage==1, "Fn alone switches exactly once");
    callbackKey(kCGEventFlagsChanged,63,0);
    expect(switches==1, "duplicate release does not switch");
    vLanguage=0;
    callbackKey(kCGEventFlagsChanged,63,kCGEventFlagMaskSecondaryFn);
    callbackKey(kCGEventKeyDown,KEY_LEFT,kCGEventFlagMaskSecondaryFn);
    callbackKey(kCGEventFlagsChanged,63,0);
    expect(switches==1, "Fn+arrow does not switch on release");
    callbackKey(kCGEventFlagsChanged,63,kCGEventFlagMaskSecondaryFn | kCGEventFlagMaskControl);
    callbackKey(kCGEventFlagsChanged,59,kCGEventFlagMaskSecondaryFn);
    callbackKey(kCGEventFlagsChanged,63,0);
    expect(switches==1, "Fn+Control does not become a single Fn press on partial release");
    vSwitchKeyStatus=0x7A000206;
    _lastFlag=kCGEventFlagMaskAlternate; _flag=0; _keycode=KEY_Z;
    expect(!checkHotKey(vSwitchKeyStatus), "stale Option flag does not match plain Z");
    _flag=kCGEventFlagMaskAlternate;
    expect(checkHotKey(vSwitchKeyStatus), "Option+Z uses current modifiers");
    _flag|=kCGEventFlagMaskSecondaryFn;
    expect(!checkHotKey(vSwitchKeyStatus), "unexpected Fn modifier rejected");

    vSwitchKeyStatus=0xFE0000FE; vLanguage=1; vOtherLanguage=1; _lastFlag=0;
    for (NSArray *languages in @[@[@"en"], @[@"vi"], @[]]) {
        testInputSource=@{@"languages":languages};
        borrowedLanguage=languages.count == 0 ? NULL : (__bridge CFTypeRef)languages[0];
        int before=sourceReleases;
        callbackKey(kCGEventKeyDown,KEY_B,0);
        expect(sourceReleases==before+1, "copied input source released on every branch");
        expect(borrowedReleases==0, "borrowed input source language is never released");
    }
    testInputSource=@{}; borrowedLanguage=NULL;
    int before=sourceReleases;
    callbackKey(kCGEventKeyDown,KEY_B,0);
    expect(sourceReleases==before+1, "missing language array is safe and source is released");
    vOtherLanguage=0;

    testWindows=@[spotlight(1,1)]; _eventTargetPID=4242;
    expect(isSpotlightVisible(), "active Spotlight target");
    _eventTargetPID=5050;
    expect(!isSpotlightVisible(), "fading Spotlight does not select text in another app");
    testWindows=@[spotlight(0,1)]; _eventTargetPID=4242;
    expect(!isSpotlightVisible(), "zero-alpha Spotlight ignored");
    testWindows=@[spotlight(1,0)];
    expect(!isSpotlightVisible(), "background Spotlight ignored");
    testWindows=@[spotlight(1,1)]; _eventTargetPID=0; testFocusedPID=4242;
    expect(isSpotlightVisible(), "focused element fallback when target PID is unavailable");
    testFocusedPID=5050;
    expect(!isSpotlightVisible(), "fallback excludes focus in another app");
    testFocusError=kAXErrorCannotComplete;
    expect(!isSpotlightVisible(), "focus timeout does not enable selection replacement");

    sent.clear(); vCodeTable=2; _syncKey.clear(); backspaceCreates=0;
    SendBackspace(); SendBackspace();
    expect(backspaceCreates==4 && sent.size()==4, "fresh backspace pair for each deletion");
    SendShiftAndLeftArrow();
    expect(_syncKey.empty(), "deletion/selection is safe without sync history");

    for (int code : {0,2,3}) {
        sent.clear(); _syncKey.clear(); vCodeTable=code; pData->code=vWillProcess;
        pData->newCharCount=21;
        for (int i=0; i<21; ++i) pData->charData[i]=CHAR_CODE_MASK | (code==2 ? 0xF961 : code==3 ? 0x2061 : 0x00E1);
        SendNewCharString();
        std::u16string expected;
        for (int i=0; i<21; ++i) expected += code==2 ? u"a\u00f9" : code==3 ? u"a\u0301" : u"\u00e1";
        expect(typedText()==expected, "long replacement preserves every encoded character");
    }
    sent.clear(); vCodeTable=0; pData->code=vReplaceMaro; pData->macroData.clear();
    std::u16string macro=u"abcdefghijklmno🚀abcdefghijklmnopABCDEFGHIJKLMNOPabcdefghijklmnop";
    for (char16_t character : macro) pData->macroData.push_back(PURE_CHARACTER_MASK | character);
    SendNewCharString(true);
    expect(typedText()==macro, "long macro including surrogate pair remains intact");
    expect(sent[0].text.size()==15, "surrogate pair is not split between events");

    sent.clear(); pData->code=vRestore; pData->newCharCount=16;
    for (int i=0; i<16; ++i) pData->charData[i]=CHAR_CODE_MASK | 'a';
    _keycode=KEY_A; _flag=kCGEventFlagMaskShift; _willSendControlKey=false;
    SendNewCharString();
    expect(typedText()==u"aaaaaaaaaaaaaaaaA", "restore appends the shifted key once after chunk boundary");
    sent.clear(); _keycode=KEY_TAB; _willSendControlKey=false;
    SendNewCharString();
    expect(typedText()==u"aaaaaaaaaaaaaaaa" && _willSendControlKey, "restore passes original control key through once");
    OpenKeyFree();
    std::cout << "macOS event regression tests: " << assertions << " assertions passed.\n";
} }
