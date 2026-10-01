#import "HaloSettings.h"

// Exercise the real settings/runtime handoff with no event tap, native wheel
// bridge, posted input, application launches, or destructive actions.
void HaloAddSettingsGlass(void *parent) {}
void HaloAddCustomizationPage(void *parent, NSInteger tab) {}
void HaloAddActivationSwitch(void *parent, BOOL quitter, BOOL enabled, void (^changed)(BOOL)) {}
@interface HaloRuntime (Testing)
- (void)apply:(NSString *)action wheel:(HaloWheel)wheel;
- (void)menuLauncher:(id)sender;
- (void)menuQuitter:(id)sender;
- (CGEventRef)event:(CGEventRef)event type:(CGEventType)type;
@end
@interface FixtureDriver : NSObject <HaloWheelDriver>
@property NSMutableArray *events;
@end
@implementation FixtureDriver
- (instancetype)init { if ((self=[super init])) _events=[NSMutableArray new]; return self; }
- (void)showWheel:(HaloWheel)wheel { [self.events addObject:[NSString stringWithFormat:@"show:%ld",(long)wheel]]; }
- (void)hideWheel:(HaloWheel)wheel {}
- (void)commitWheel:(HaloWheel)wheel { [self.events addObject:[NSString stringWithFormat:@"commit:%ld",(long)wheel]]; }
- (NSRect)frameForWheel:(HaloWheel)wheel { return NSMakeRect(0,0,300,300); }
@end
@interface EventRuntime : HaloRuntime
@property NSInteger settingsPresentations;
@end
@implementation EventRuntime
- (void)retryInput {}
- (void)showSettings:(id)sender { [self cancel]; if (!self.settingsVisible) { self.settingsVisible=YES; self.settingsPresentations++; } }
@end
static BOOL keyEvent(HaloRuntime *runtime, CGEventType type, CGKeyCode code, CGEventFlags flags) {
    CGEventRef event=CGEventCreateKeyboardEvent(NULL,code,type==kCGEventKeyDown);
    CGEventSetType(event,type); CGEventSetFlags(event,flags);
    BOOL consumed=[runtime event:event type:type]==NULL; CFRelease(event); return consumed;
}
@interface TestRuntime : HaloRuntime
@property NSMutableArray *events;
@end
@implementation TestRuntime
- (void)retryInput {}
- (void)apply:(NSString *)action wheel:(HaloWheel)wheel {
    [self.events addObject:[NSString stringWithFormat:@"%@:%ld",action,(long)wheel]];
}
@end
static void drain(void) {
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.02]];
}
int main(void) {
    @autoreleasepool {
        NSString *domain=[@"Halo.Rebuild.RuntimeTests." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults=[[NSUserDefaults alloc] initWithSuiteName:domain];
        TestRuntime *runtime=[[TestRuntime alloc] initWithDriver:nil defaults:defaults]; runtime.events=[NSMutableArray new];
        NSMenuItem *settings=[NSMenuItem new]; [runtime setValue:settings forKey:@"settingsItem"];
        HaloShortcutConfig *c=[HaloShortcutConfig defaults];
        c.launcher=HaloKeys(@[@97]); c.quitter=HaloKeys(@[@98]); c.settingsKey=100;
        c.launcherToggle=YES; c.quitterToggle=YES;
        runtime.settingsVisible=YES; [runtime saveConfig:c];
        NSCAssert([settings.title isEqual:@"Settings…   F6  +  F8"],@"Menu hint must follow launcher and settings key");
        NSCAssert(settings.keyEquivalent.length==0,@"No stale Command-comma hint");
        NSCAssert([[defaults objectForKey:@"HaloShortcuts.v1"] isEqual:c.dictionary],@"Save must persist immediately");
        [runtime.engine update:c.launcher at:1]; drain();
        NSCAssert([runtime.events containsObject:@"show:1"],@"Shortcut must work with Settings open");
        [runtime cancel]; [runtime.engine update:HaloKeys(@[]) at:1.1]; drain(); [runtime.events removeAllObjects];
        [runtime menuQuitter:nil]; drain();
        NSCAssert([runtime.events containsObject:@"show:2"],@"Menu must work after saving, without restart");
        [runtime cancel]; drain(); [runtime.events removeAllObjects];
        // A queued selection must remain cancelled even if recording begins and
        // ends before the main queue gets a chance to execute that selection.
        [runtime menuQuitter:nil]; [runtime.engine confirm];
        runtime.recordInput=^(NSSet *held) {};
        [runtime menuLauncher:nil]; [runtime.engine update:c.launcher at:2];
        [runtime.engine update:HaloKeys(@[]) at:2.1];
        runtime.recordInput=nil; drain();
        NSCAssert(![runtime.events containsObject:@"commit:2"] && ![runtime.events containsObject:@"show:1"],@"Recording must invalidate pending actions and suppress wheels");
        [runtime.events removeAllObjects];
        [runtime.engine update:c.launcher at:3]; drain();
        NSCAssert([runtime.events containsObject:@"show:1"],@"Recording must resume cleanly");
        [runtime stop];
        for (NSInteger wheel=HaloLauncher;wheel<=HaloQuitter;wheel++) {
            for (NSInteger withFlags=0;withFlags<2;withFlags++) {
                FixtureDriver *driver=[FixtureDriver new];
                EventRuntime *input=[[EventRuntime alloc] initWithDriver:driver defaults:defaults];
                input.engine.config=[HaloShortcutConfig defaults];
                CGEventFlags flags=kCGEventFlagMaskSecondaryFn | (wheel==HaloQuitter?kCGEventFlagMaskControl:0);
                keyEvent(input,kCGEventFlagsChanged,63,flags); drain();
                NSCAssert(input.engine.active==wheel,@"Real event routing opens expected wheel");
                NSCAssert(keyEvent(input,kCGEventKeyDown,43,withFlags?flags:0),@"Comma is consumed");
                keyEvent(input,kCGEventKeyDown,43,withFlags?flags:0); drain();
                NSCAssert(input.settingsPresentations==1,@"Comma opens/brings Settings forward once, including Fn-less key snapshots");
                NSCAssert(![driver.events containsObject:@"commit:1"] && ![driver.events containsObject:@"commit:2"],@"Settings cancels instead of launching or quitting");
                NSCAssert(keyEvent(input,kCGEventKeyUp,43,flags),@"Comma key-up is consumed");
                keyEvent(input,kCGEventFlagsChanged,63,0); [input stop]; drain();
            }
        }
        FixtureDriver *driver=[FixtureDriver new];
        EventRuntime *input=[[EventRuntime alloc] initWithDriver:driver defaults:defaults];
        input.engine.config=[HaloShortcutConfig defaults];
        [input.engine update:HaloKeys(@[@(HaloFn)]) at:20]; drain();
        [input.engine update:HaloKeys(@[@(HaloFn),@(HaloControl)]) at:20.1]; drain();
        NSCAssert(([driver.events isEqual:@[@"show:1",@"commit:1",@"show:2"]]),@"Presented launcher commits before Quitter shows");
        [input.engine update:HaloKeys(@[]) at:20.2]; drain(); [driver.events removeAllObjects];
        for (NSInteger i=0;i<100;i++) {
            [input.engine update:HaloKeys(@[@(HaloFn)]) at:21+i];
            [input.engine update:HaloKeys(@[]) at:21.1+i];
        }
        [input.engine update:HaloKeys(@[@(HaloFn)]) at:200]; drain();
        NSCAssert([driver.events isEqual:@[@"show:1"]],@"Queued rapid sessions never flash or commit invisible stale wheels");
        [input stop]; drain();
        [defaults removePersistentDomainForName:domain];
        puts("PASS: runtime autosave, adaptive menu hint, Settings-open shortcuts/menu, and queued-action suppression during recording.");
    }
}
