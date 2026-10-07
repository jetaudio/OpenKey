// Load and render the compiled preferences without launching OpenKey or creating
// an event tap. Defaults belong to this separate QA executable, not OpenKey.app.
#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "ViewController.h"
#import "OpenKeyManager.h"
#import "AppDelegate.h"

extern AppDelegate *appDelegate;
extern int vSwitchKeyStatus;
@interface ViewController (ReviewActions)
- (IBAction)onFnSwitchKey:(NSButton *)sender;
@end
static BOOL skipEventTap(id receiver, SEL selector) { return YES; }
static void fail(NSString *message) { NSLog(@"UI QA failed: %@", message); exit(1); }
int main(int argc, const char *argv[]) { @autoreleasepool {
    if (argc != 3) return 2;
    [NSApplication sharedApplication];
    Method method=class_getClassMethod([OpenKeyManager class], @selector(initEventTap));
    method_setImplementation(method, (IMP)skipEventTap);
    NSBundle *bundle=[NSBundle bundleWithPath:[NSString stringWithUTF8String:argv[1]]];
    if (bundle==nil) fail(@"missing built app bundle");
    NSWindowController *window=[[NSStoryboard storyboardWithName:@"Main" bundle:bundle]
        instantiateControllerWithIdentifier:@"OpenKey"];
    ViewController *controller=(ViewController *)window.contentViewController;
    [controller.view layoutSubtreeIfNeeded];
    NSButton *fn=[controller valueForKey:@"CustomSwitchFn"];
    MyTextField *key=[controller valueForKey:@"CustomSwitchKey"];
    if (fn==nil || key==nil) fail(@"Fn/key outlets are not connected");
    if (!NSContainsRect(controller.view.bounds, fn.frame)) fail(@"Fn checkbox is outside the view");
    if (NSIntersectsRect(fn.frame, key.frame)) fail(@"Fn checkbox overlaps key field");
    NSButton *shift=[controller valueForKey:@"CustomSwitchShift"];
    NSButton *beep=[controller valueForKey:@"CustomBeepSound"];
    if (NSIntersectsRect(fn.frame, shift.frame) || NSIntersectsRect(fn.frame, beep.frame)) fail(@"shortcut controls overlap");
    NSBox *controlsBox=nil;
    NSTextField *inputTypeLabel=nil;
    for (NSView *view in controller.view.subviews) {
        if ([view isKindOfClass:[NSBox class]] && [((NSBox *)view).title isEqualToString:@"Điều khiển"]) controlsBox=(NSBox *)view;
        if ([view isKindOfClass:[NSTextField class]] && [((NSTextField *)view).stringValue isEqualToString:@"Kiểu gõ:"]) inputTypeLabel=(NSTextField *)view;
    }
    if (controlsBox==nil || inputTypeLabel==nil) fail(@"missing control group or input type label");
    // NSBox's custom style may report an empty titleRect even while drawing its
    // title. Reserve a full header row so text cannot collide with that title.
    NSRect titleFrame=NSMakeRect(NSMinX(controlsBox.frame), NSMaxY(controlsBox.frame)-24,
                                 NSWidth(controlsBox.frame), 24);
    if (NSIntersectsRect(titleFrame, inputTypeLabel.frame)) fail(@"control group title overlaps input type label");

    NSString *domain=[NSProcessInfo processInfo].processName;
    NSUserDefaults *defaults=[NSUserDefaults standardUserDefaults];
    vSwitchKeyStatus=0x7A008206;
    fn.state=NSControlStateValueOn;
    [controller onFnSwitchKey:fn];
    if (vSwitchKeyStatus!=0xFE0090FE || key.stringValue.length!=0) fail(@"selecting Fn does not configure Fn alone");
    if (shift.state!=NSControlStateValueOff || beep.state!=NSControlStateValueOn) fail(@"Fn state did not refresh controls");
    [defaults removePersistentDomainForName:domain];

    NSBitmapImageRep *bitmap=[controller.view bitmapImageRepForCachingDisplayInRect:controller.view.bounds];
    [controller.view cacheDisplayInRect:controller.view.bounds toBitmapImageRep:bitmap];
    NSData *png=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    if (![png writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES]) fail(@"could not save preferences rendering");
    printf("Preferences UI: compiled storyboard/outlets, geometry and Fn action verified.\n");
} }
