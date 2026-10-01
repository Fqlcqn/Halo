#import <Foundation/Foundation.h>
#import "HaloShortcuts.h"

static NSMutableArray<NSString *> *events;
static NSSet *K(NSArray *v) { return HaloKeys(v); }
static void clear(void) { [events removeAllObjects]; }
static void equal(NSArray *expected, NSString *name) {
    if (![events isEqual:expected]) {
        NSLog(@"FAIL %@ expected %@, got %@",name,expected,events); abort();
    }
}
static HaloShortcutEngine *engine(void) {
    HaloShortcutEngine *e=[HaloShortcutEngine new];
    e.effect=^(NSString *action,HaloWheel wheel) { [events addObject:[NSString stringWithFormat:@"%@:%ld",action,(long)wheel]]; };
    return e;
}

int main(void) {
    @autoreleasepool {
        events=[NSMutableArray new];
        HaloShortcutConfig *defaults=[HaloShortcutConfig defaults];
        NSCAssert(!defaults.validationError,@"Defaults must validate");
        NSCAssert([[HaloShortcutConfig fromDictionary:defaults.dictionary].dictionary isEqual:defaults.dictionary],@"Round trip failed");
        NSDictionary *bad=@{@"version":@1,@"launcher":@[],@"quitter":@[@1],@"settings":@43,@"launcherToggle":@NO,@"quitterToggle":@NO};
        NSCAssert([[HaloShortcutConfig fromDictionary:bad].dictionary isEqual:defaults.dictionary],@"Malformed preferences did not reset safely");

        HaloShortcutEngine *e=engine();
        [e update:K(@[@(HaloFn)]) at:1]; [e update:K(@[]) at:1.1];
        equal(@[@"show:1",@"commit:1"],@"hold launcher");

        clear(); e=engine();
        [e update:K(@[@(HaloFn)]) at:2];
        [e update:K(@[@(HaloFn),@(HaloControl)]) at:2.1];
        equal(@[@"show:1",@"commit:1",@"show:2"],@"launcher to quitter commits");
        [e update:K(@[@(HaloFn)]) at:2.2];
        NSCAssert(e.pendingDeadline>2.2 && e.active==HaloNoWheel,@"Underlying launcher must be delayed");
        [e update:K(@[]) at:2.21]; [e tick:3];
        equal(@[@"show:1",@"commit:1",@"show:2",@"commit:2"],@"quick full release has no flash");

        clear(); e=engine();
        [e update:K(@[@(HaloFn)]) at:3]; [e update:K(@[@(HaloFn),@(HaloControl)]) at:3.1];
        [e update:K(@[@(HaloFn)]) at:3.2]; [e tick:3.239];
        equal(@[@"show:1",@"commit:1",@"show:2",@"commit:2"],@"release guard not elapsed");
        [e tick:3.241];
        equal(@[@"show:1",@"commit:1",@"show:2",@"commit:2",@"show:1"],@"intentional return in forty milliseconds");
        [e update:K(@[]) at:3.4];

        clear(); e=engine();
        [e update:K(@[@(HaloFn)]) at:4]; [e update:K(@[@(HaloFn),@43]) at:4.1];
        equal(@[@"show:1",@"cancel:1",@"settings:0"],@"settings from launcher");
        [e update:K(@[@(HaloFn)]) at:4.2]; [e update:K(@[]) at:4.3];
        [e update:K(@[@(HaloFn)]) at:4.4];
        equal(@[@"show:1",@"cancel:1",@"settings:0",@"show:1"],@"blocked until full release");

        clear(); e=engine();
        [e update:defaults.quitter at:4.5];
        [e update:K(@[@(HaloFn),@(HaloControl),@43]) at:4.6];
        equal(@[@"show:2",@"cancel:2",@"settings:0"],@"settings from quitter never commits selection");
        for (NSInteger order=0;order<2;order++) for (NSInteger gap=0;gap<40;gap++) {
            clear(); e=engine(); [e update:defaults.quitter at:10];
            [e update:K(order?@[@(HaloControl)]:@[@(HaloFn)]) at:11];
            [e tick:11+gap/1000.0]; [e update:K(@[]) at:11+gap/1000.0]; [e tick:12];
            equal(@[@"show:2",@"commit:2"],@"either modifier-release order never flashes launcher within guard");
        }

        clear(); e=engine(); e.config.launcherToggle=YES;
        [e update:K(@[@(HaloFn)]) at:5]; [e update:K(@[]) at:5.1];
        NSCAssert(e.active==HaloLauncher,@"Toggle closed on release");
        [e update:K(@[@(HaloFn)]) at:5.2];
        equal(@[@"show:1",@"commit:1"],@"toggle confirm");

        clear(); e=engine();
        e.config.launcher=K(@[@12,@13]); e.config.quitter=K(@[@14]); e.config.settingsKey=43;
        [e update:K(@[@12]) at:6]; [e update:K(@[]) at:6.1];
        equal(@[],@"partial chord");
        [e update:K(@[@12,@13]) at:6.2]; [e update:K(@[]) at:6.3];
        equal(@[@"show:1",@"commit:1"],@"all keys required");

        HaloShortcutConfig *three=[HaloShortcutConfig defaults];
        three.launcher=K(@[@(HaloFn),@(HaloShift),@12]);
        three.quitter=K(@[@(HaloFn),@(HaloShift),@12,@(HaloControl)]);
        NSCAssert(!three.validationError,@"Three-key launcher plus extra quitter key must validate");
        three.quitter=K(@[@(HaloFn),@(HaloControl)]);
        NSCAssert(three.validationError,@"Three-key launcher cannot use an independent quitter shortcut");

        clear(); e=engine(); [e cancelUntilRelease];
        [e update:K(@[@(HaloFn)]) at:7];
        equal(@[@"show:1"],@"menu settings cancel does not eat next shortcut");
        clear(); e=engine(); e.suspended=YES;
        [e update:defaults.launcher at:8]; [e update:defaults.quitter at:8.1];
        [e menuOpen:HaloLauncher]; [e menuOpen:HaloQuitter]; [e update:K(@[]) at:8.2];
        equal(@[],@"recording suppresses keyboard and menu commands");
        e.suspended=NO;
        HaloShortcutConfig *changed=[defaults copy]; changed.launcher=K(@[@12,@13]); changed.quitter=K(@[@14]);
        e.config=changed;
        [e update:K(@[@12]) at:8.3]; [e update:K(@[@12,@13]) at:8.4];
        [e update:K(@[]) at:8.5];
        equal(@[@"show:1",@"commit:1"],@"changed shortcut takes effect without restart");
        clear(); [e menuOpen:HaloQuitter];
        equal(@[@"show:2"],@"menu works immediately after live config change");
        [e cancelUntilRelease]; clear();
        e.config=defaults;
        [e update:defaults.launcher at:9]; [e update:K(@[]) at:9.1];
        equal(@[@"show:1",@"commit:1"],@"restoring shortcuts works without restart");
        puts("PASS: validation, persistence, exact chords, hold/toggle modes, settings, switching, no-flash release, recording suppression, and immediate config replacement.");
    }
    return 0;
}
