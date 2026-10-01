#import "HaloShortcuts.h"

NSSet *HaloKeys(NSArray *keys) { return [NSSet setWithArray:keys]; }
NSArray *HaloSorted(NSSet *keys) { return [keys.allObjects sortedArrayUsingSelector:@selector(compare:)]; }
static BOOL validKey(id key) {
    if (![key isKindOfClass:NSNumber.class]) return NO;
    NSInteger k=[key integerValue];
    if ([key doubleValue] != k) return NO;
    // Caps Lock is a latch, not a holdable key. Modifier physical codes are normalized.
    return (k>=0 && k<=126 && ![@[@54,@55,@56,@57,@58,@59,@60,@61,@62,@63] containsObject:key]) || (k>=HaloFn && k<=HaloCommand);
}
@implementation HaloShortcutConfig
+ (instancetype)defaults {
    HaloShortcutConfig *c=[self new]; c.launcher=HaloKeys(@[@(HaloFn)]);
    c.quitter=HaloKeys(@[@(HaloFn),@(HaloControl)]); c.settingsKey=43; return c;
}
- (id)copyWithZone:(NSZone *)zone {
    HaloShortcutConfig *c=[HaloShortcutConfig new]; c.launcher=self.launcher; c.quitter=self.quitter;
    c.settingsKey=self.settingsKey; c.launcherToggle=self.launcherToggle; c.quitterToggle=self.quitterToggle; return c;
}
- (NSString *)validationError {
    if (self.launcher.count<1 || self.launcher.count>3) return @"Choose 1–3 launcher keys.";
    if (self.launcher.count==3) {
        if (self.quitter.count!=4 || ![self.launcher isSubsetOfSet:self.quitter]) return @"Choose one extra key for Quitter.";
    } else if (self.quitter.count<1 || self.quitter.count>3) return @"Choose 1–3 quitter keys.";
    for (id k in self.launcher) if (!validKey(k)) return @"This key cannot be used as a held shortcut.";
    for (id k in self.quitter) if (!validKey(k)) return @"This key cannot be used as a held shortcut.";
    if (!validKey(@(self.settingsKey))) return @"Choose a different settings key.";
    if ([self.launcher isEqual:self.quitter]) return @"Launcher and Quitter need different shortcuts.";
    if ([self.launcher containsObject:@(self.settingsKey)] || [self.quitter containsObject:@(self.settingsKey)]) return @"Change the settings key before using it in a wheel shortcut.";
    return nil;
}
- (NSDictionary *)dictionary {
    return @{@"version":@1,@"launcher":HaloSorted(self.launcher),@"quitter":HaloSorted(self.quitter),@"settings":@(self.settingsKey),@"launcherToggle":@(self.launcherToggle),@"quitterToggle":@(self.quitterToggle)};
}
+ (instancetype)fromDictionary:(id)v {
    if (![v isKindOfClass:NSDictionary.class] || ![v[@"version"] isEqual:@1]) return [self defaults];
    for (NSString *k in @[@"launcher",@"quitter"]) {
        if (![v[k] isKindOfClass:NSArray.class] || [v[k] count]>4) return [self defaults];
        for (id n in v[k]) if (!validKey(n)) return [self defaults];
        if (HaloKeys(v[k]).count != [v[k] count]) return [self defaults];
    }
    for (NSString *k in @[@"settings",@"launcherToggle",@"quitterToggle"]) if (![v[k] isKindOfClass:NSNumber.class]) return [self defaults];
    if (!validKey(v[@"settings"])) return [self defaults];
    for (NSString *k in @[@"launcherToggle",@"quitterToggle"]) if (![v[k] isEqual:@0] && ![v[k] isEqual:@1]) return [self defaults];
    HaloShortcutConfig *c=[self new]; c.launcher=HaloKeys(v[@"launcher"]); c.quitter=HaloKeys(v[@"quitter"]);
    c.settingsKey=[v[@"settings"] integerValue]; c.launcherToggle=[v[@"launcherToggle"] boolValue]; c.quitterToggle=[v[@"quitterToggle"] boolValue];
    return c.validationError ? [self defaults] : c;
}
@end

@implementation HaloShortcutEngine {
    BOOL _blocked, _launcherWasDown, _quitterWasDown, _menuSession;
    NSTimeInterval _returnAt;
}
// Two to three display frames absorb the separate modifier-up events of a
// full release without the old 120 ms pause on an intentional wheel handoff.
static const NSTimeInterval HaloHandoffDelay = .04;
- (instancetype)init { if ((self=[super init])) { _config=[HaloShortcutConfig defaults]; _held=[NSSet set]; } return self; }
- (void)emit:(NSString *)action wheel:(HaloWheel)wheel { if (self.effect) self.effect(action,wheel); }
- (NSTimeInterval)pendingDeadline { return _returnAt; }
- (void)setConfig:(HaloShortcutConfig *)config {
    [self cancelUntilRelease]; _config=[config copy];
    _launcherWasDown=[_config.launcher isSubsetOfSet:_held];
    _quitterWasDown=[_config.quitter isSubsetOfSet:_held];
}
- (void)setSuspended:(BOOL)suspended {
    [self cancelUntilRelease]; _suspended=suspended;
}
- (BOOL)isToggle:(HaloWheel)w { return w==HaloLauncher ? self.config.launcherToggle : self.config.quitterToggle; }
- (NSSet *)chord:(HaloWheel)w { return w==HaloLauncher ? self.config.launcher : self.config.quitter; }
- (void)close:(BOOL)commit {
    if (_active) [self emit:commit?@"commit":@"cancel" wheel:_active];
    _active=HaloNoWheel; _menuSession=NO;
}
- (void)open:(HaloWheel)wheel {
    if (_active==wheel) return;
    [self close:NO]; _active=wheel; _returnAt=0; [self emit:@"show" wheel:wheel];
}
- (void)cancelUntilRelease { [self close:NO]; _returnAt=0; _blocked=_held.count>0; }
- (void)confirm { [self close:YES]; _returnAt=0; _blocked=YES; }
- (void)openSettings { [self cancelUntilRelease]; [self emit:@"settings" wheel:HaloNoWheel]; }
- (void)switchTo:(HaloWheel)wheel { [self close:YES]; [self open:wheel]; }
- (void)menuOpen:(HaloWheel)wheel {
    if (_suspended) return;
    [self cancelUntilRelease]; _blocked=NO; [self open:wheel]; _menuSession=YES;
}
- (void)update:(NSSet *)keys at:(NSTimeInterval)time {
    NSSet *previous=_held; _held=[keys copy];
    BOOL l=[self.config.launcher isSubsetOfSet:keys], q=[self.config.quitter isSubsetOfSet:keys];
    BOOL lRise=l&&!_launcherWasDown, qRise=q&&!_quitterWasDown;
    _launcherWasDown=l; _quitterWasDown=q;
    if (_suspended) { _blocked=keys.count>0; return; }
    if (_blocked) { if (!keys.count) _blocked=NO; return; }
    NSNumber *settings=@(self.config.settingsKey);
    if (_active && [keys containsObject:settings] && ![previous containsObject:settings]) {
        [self openSettings]; return;
    }
    // Escape cancels only when it isn't an assigned shortcut component.
    if (_active && [keys containsObject:@53] && ![previous containsObject:@53] &&
        ![self.config.launcher containsObject:@53] && ![self.config.quitter containsObject:@53]) {
        [self cancelUntilRelease]; return;
    }
    if (_active && ([self isToggle:_active] || _menuSession)) {
        BOOL ownRise=_active==HaloLauncher?lRise:qRise;
        BOOL otherRise=_active==HaloLauncher?qRise:lRise;
        HaloWheel other=_active==HaloLauncher?HaloQuitter:HaloLauncher;
        // Don't mistake a still-held subset for a fresh second invocation.
        if (otherRise && [[self chord:other] isEqual:keys]) {
            if ([[self chord:other] isSubsetOfSet:[self chord:_active]]) _returnAt=time+HaloHandoffDelay;
            else [self switchTo:other];
            return;
        }
        if (ownRise) { [self close:YES]; _returnAt=0; _blocked=YES; return; }
        if (_returnAt && ![[self chord:other] isEqual:keys]) _returnAt=0;
        return;
    }
    if (_active) {
        HaloWheel current=_active;
        BOOL still=current==HaloLauncher?l:q;
        HaloWheel other=current==HaloLauncher?HaloQuitter:HaloLauncher;
        BOOL otherRise=other==HaloLauncher?lRise:qRise;
        if (otherRise && [[self chord:other] isEqual:keys]) { [self switchTo:other]; return; }
        if (still) return;
        [self close:YES];
        // A release can finish an action and expose the held underlying shortcut.
        // Wait briefly: quick full release never flashes the other wheel.
        if ((l||q) && [[self chord:l?HaloLauncher:HaloQuitter] isEqual:keys]) _returnAt=time+HaloHandoffDelay;
        return;
    }
    if (_returnAt) { if (!l&&!q) _returnAt=0; else [self tick:time]; return; }
    // Exact matches on entry avoid invoking a wheel inside unrelated system shortcuts.
    if (qRise && [self.config.quitter isEqual:keys]) [self open:HaloQuitter];
    else if (lRise && [self.config.launcher isEqual:keys]) [self open:HaloLauncher];
}
- (void)tick:(NSTimeInterval)time {
    if (!_returnAt || time<_returnAt || _blocked) return;
    _returnAt=0;
    if ([self.config.quitter isEqual:_held]) [self switchTo:HaloQuitter];
    else if ([self.config.launcher isEqual:_held]) [self switchTo:HaloLauncher];
}
@end
