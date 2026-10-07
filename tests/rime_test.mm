// Types through OKRime with the data from scripts/fetch-rime.sh.
#import <Cocoa/Cocoa.h>
#import <Carbon/Carbon.h>
#import "OKRime.h"

static int assertions = 0;
static void expect(BOOL condition, NSString *label) {
    ++assertions;
    if (!condition) { NSLog(@"FAIL: %@", label); exit(1); }
}

static NSString *typeKeys(OKRime *rime, NSString *keys, int finalKey) {
    for (NSUInteger i = 0; i < keys.length; i++) [rime processKeysym:[keys characterAtIndex:i] mask:0];
    if (finalKey) [rime processKeysym:finalKey mask:0];
    return [rime takeCommit] ?: @"";
}

static int keysym(CGKeyCode code, CGEventFlags flags, int *mask, UniChar character = 0, BOOL composing = NO) {
    CGEventRef event = CGEventCreateKeyboardEvent(NULL, code, true);
    CGEventSetFlags(event, flags);
    // Real key events carry the shifted character; synthesized ones need it set.
    if (character) CGEventKeyboardSetUnicodeString(event, 1, &character);
    int result = [OKRime keysymForEvent:event keyCode:code flags:flags composing:composing mask:mask];
    CFRelease(event);
    return result;
}

// Pages forward until the character is on screen, then selects it.
static BOOL pickByPaging(OKRime *rime, NSString *character) {
    OKRimeComposition *page = [rime composition];
    for (int guard = 0; guard < 40 && ![page.candidates containsObject:character]; guard++) {
        [rime processKeysym:0xff56 mask:0];
        page = [rime composition];
    }
    return [rime selectCandidateOnCurrentPage:[page.candidates indexOfObject:character]];
}

int main(int argc, const char *argv[]) { @autoreleasepool {
    NSString *root = [NSString stringWithUTF8String:argv[1]];
    NSString *user = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID UUID].UUIDString];
    OKRime *rime = [[OKRime alloc] initWithLibrary:[root stringByAppendingPathComponent:@"lib/librime.1.dylib"]
                                        sharedData:[root stringByAppendingPathComponent:@"shared"]
                                          prebuilt:[root stringByAppendingPathComponent:@"build"]
                                          userData:user];
    __block BOOL done = NO;
    [rime startWithCompletion:^(BOOL ready) { done = YES; }];
    while (!done) [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    expect(rime.ready, [NSString stringWithFormat:@"Rime starts: %@", rime.failureReason]);

    expect([typeKeys(rime, @"nihao", ' ') isEqualToString:@"你好"], @"nihao + space");
    expect([typeKeys(rime, @"jintiantianqihenhao", ' ') isEqualToString:@"今天天气很好"], @"sentence");
    expect([typeKeys(rime, @"nh", ' ') isEqualToString:@"你好"], @"abbreviation");
    [rime processKeysym:'x' mask:0]; [rime processKeysym:'i' mask:0]; [rime processKeysym:'a' mask:0]; [rime processKeysym:'n' mask:0];
    OKRimeComposition *composition = [rime composition];
    expect(composition != nil && [composition.candidates containsObject:@"西安"] && composition.candidates.count == 7, @"candidates page");
    expect([rime selectCandidateOnCurrentPage:[composition.candidates indexOfObject:@"西安"]], @"select by index");
    expect([[rime takeCommit] isEqualToString:@"西安"], @"selected candidate commits");
    expect([rime composition] == nil, @"composition ends after commit");
    expect([typeKeys(rime, @"nihao", 0xff0d) isEqualToString:@"nihao"], @"return commits Latin letters");
    [rime processKeysym:'n' mask:0];
    expect([rime processKeysym:0xff1b mask:0] && [rime composition] == nil && [rime takeCommit] == nil, @"escape cancels");
    expect([typeKeys(rime, @",", 0) isEqualToString:@"，"], @"full-width comma");
    expect(![rime processKeysym:0xff51 mask:0], @"arrows pass through when idle");
    [rime processKeysym:'w' mask:0];
    [rime clearComposition];
    expect([rime composition] == nil, @"clear composition");

    int mask = -1;
    expect(keysym(kVK_ANSI_A, 0, &mask) == 'a' && mask == 0, @"letter keysym");
    expect(keysym(kVK_ANSI_A, kCGEventFlagMaskShift, &mask, 'A') == 'A', @"shifted letter keysym");
    expect(keysym(kVK_Delete, 0, &mask) == 0xff08, @"backspace keysym");
    expect(keysym(kVK_Space, 0, &mask) == 0x20, @"space keysym");
    expect(keysym(kVK_Return, 0, &mask) == 0xff0d, @"return keysym");
    expect(keysym(kVK_ANSI_A, kCGEventFlagMaskControl, &mask, 0x01) == 0, @"control letter belongs to the app when idle");
    expect(keysym(kVK_ANSI_K, kCGEventFlagMaskControl, &mask, 0x0b, YES) == 'k' && mask == (1 << 2), @"control letter reaches Rime while composing");
    expect(keysym(kVK_ANSI_C, kCGEventFlagMaskCommand, &mask, 'c', YES) == 0, @"command shortcuts always belong to the app");
    expect(keysym(kVK_ForwardDelete, kCGEventFlagMaskShift, &mask) == 0xffff && mask == 1, @"shift+delete keeps shift");

    // Learning: a phrase built from single characters ranks first next time,
    // and Shift+Delete or Control+K forgets it again.
    typeKeys(rime, @"laoshiren", 0);
    expect(![[rime composition].candidates.firstObject isEqualToString:@"捞尸人"], @"unlearned phrase is not first");
    for (NSString *character in @[@"捞", @"尸", @"人"]) expect(pickByPaging(rime, character), @"pick character");
    expect([[rime takeCommit] isEqualToString:@"捞尸人"], @"phrase built from characters commits");
    for (NSNumber *forget in @[@0xffff, @'k']) {
        typeKeys(rime, @"laoshiren", 0);
        expect([[rime composition].candidates.firstObject isEqualToString:@"捞尸人"], @"learned phrase ranks first");
        expect([rime processKeysym:forget.intValue mask:(forget.intValue == 'k' ? (1 << 2) : 1)], @"forget key handled");
        expect(![[rime composition].candidates containsObject:@"捞尸人"], @"forgotten phrase leaves the page");
        [rime clearComposition];
        if (forget.intValue == 0xffff) {
            typeKeys(rime, @"laoshiren", 0);  // learn again for the Control+K case
            for (NSString *character in @[@"捞", @"尸", @"人"]) pickByPaging(rime, character);
            [rime takeCommit];
        }
    }
    [[NSFileManager defaultManager] removeItemAtPath:user error:nil];
    printf("Rime tests: %d assertions passed.\n", assertions);
} }
