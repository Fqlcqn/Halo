#import "HaloShortcuts.h"

NSSet *HaloKeys(NSArray *keys) { return [NSSet setWithArray:keys]; }
NSArray *HaloSorted(NSSet *keys) { return [keys.allObjects sortedArrayUsingSelector:@selector(compare:)]; }
// Preserve existing side-independent Shift shortcuts while allowing Left Shift.
static NSSet *genericShift(NSSet *keys) {
    NSMutableSet *result=[keys mutableCopy];
    if ([result containsObject:@(HaloLeftShift)]) { [result removeObject:@(HaloLeftShift)]; [result addObject:@(HaloShift)]; }
    return result;
}
BOOL HaloChordMatches(NSSet *chord, NSSet *held, BOOL exact) {
    NSSet *keys=[chord containsObject:@(HaloLeftShift)] ? held : genericShift(held);
    return exact ? [chord isEqual:keys] : [chord isSubsetOfSet:keys];
}
static BOOL validKey(id key) {
    if (![key isKindOfClass:NSNumber.class]) return NO;
    NSInteger k=[key integerValue];
    if ([key doubleValue] != k) return NO;
    // Caps Lock is a latch, not a holdable key. Modifier physical codes are normalized.
    return (k>=0 && k<=126 && ![@[@54,@55,@56,@57,@58,@59,@60,@61,@62,@63] containsObject:key]) || (k>=HaloFn && k<=HaloLeftShift);
}
@implementation HaloShortcutConfig
+ (instancetype)defaults {
    HaloShortcutConfig *c=[self new]; c.launcher=HaloKeys(@[@(HaloFn)]);
    c.quitter=HaloKeys(@[@(HaloFn),@(HaloControl)]); c.settingsKey=43; c.switcher=HaloKeys(@[@(HaloFn),@(HaloLeftShift)]); return c;
}
- (id)copyWithZone:(NSZone *)zone {
    HaloShortcutConfig *c=[HaloShortcutConfig new]; c.launcher=self.launcher; c.quitter=self.quitter;
    c.switcher=self.switcher; c.switcherEnabled=self.switcherEnabled; c.switcherToggle=self.switcherToggle;
    c.settingsKey=self.settingsKey; c.launcherToggle=self.launcherToggle; c.quitterToggle=self.quitterToggle; return c;
}
- (NSSet *)chordForWheel:(HaloWheel)wheel {
    return wheel==HaloLauncher ? self.launcher : wheel==HaloQuitter ? self.quitter : self.switcher;
}
- (BOOL)toggleForWheel:(HaloWheel)wheel {
    return wheel==HaloLauncher ? self.launcherToggle : wheel==HaloQuitter ? self.quitterToggle : self.switcherToggle;
}
- (NSString *)validationError {
    if (self.launcher.count<1 || self.launcher.count>3) return @"Choose 1–3 launcher keys.";
    if (self.launcher.count==3) {
        if (self.quitter.count!=4 || ![self.launcher isSubsetOfSet:self.quitter]) return @"Choose one extra key for Quitter.";
    } else if (self.quitter.count<1 || self.quitter.count>3) return @"Choose 1–3 quitter keys.";
    for (id k in self.launcher) if (!validKey(k)) return @"This key cannot be used as a held shortcut.";
    for (id k in self.quitter) if (!validKey(k)) return @"This key cannot be used as a held shortcut.";
    if (self.switcher.count<1 || self.switcher.count>3) return @"Choose 1–3 Switcher keys.";
    for (id k in self.switcher) if (!validKey(k)) return @"This key cannot be used as a held shortcut.";
    for (NSSet *chord in @[self.launcher,self.quitter,self.switcher])
        if ([chord containsObject:@(HaloLeftShift)] && [chord containsObject:@(HaloShift)]) return @"Choose one Shift key per shortcut.";
    if (self.switcherEnabled && ([genericShift(self.switcher) isEqual:genericShift(self.launcher)] || [genericShift(self.switcher) isEqual:genericShift(self.quitter)])) return @"Switcher needs a different shortcut from Launcher and Quitter.";
    if (self.switcherEnabled && [self.switcher containsObject:@(self.settingsKey)]) return @"Change the settings key before using it in a wheel shortcut.";
    if (!validKey(@(self.settingsKey))) return @"Choose a different settings key.";
    if ([genericShift(self.launcher) isEqual:genericShift(self.quitter)]) return @"Launcher and Quitter need different shortcuts.";
    if ([self.launcher containsObject:@(self.settingsKey)] || [self.quitter containsObject:@(self.settingsKey)]) return @"Change the settings key before using it in a wheel shortcut.";
    return nil;
}
- (NSDictionary *)dictionary {
    return @{@"switcher":HaloSorted(self.switcher),@"switcherEnabled":@(self.switcherEnabled),@"switcherToggle":@(self.switcherToggle),@"version":@1,@"launcher":HaloSorted(self.launcher),@"quitter":HaloSorted(self.quitter),@"settings":@(self.settingsKey),@"launcherToggle":@(self.launcherToggle),@"quitterToggle":@(self.quitterToggle)};
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
    HaloShortcutConfig *c=[self defaults]; c.launcher=HaloKeys(v[@"launcher"]); c.quitter=HaloKeys(v[@"quitter"]);
    c.settingsKey=[v[@"settings"] integerValue]; c.launcherToggle=[v[@"launcherToggle"] boolValue]; c.quitterToggle=[v[@"quitterToggle"] boolValue];
    // Older dictionaries migrate without changing either existing shortcut.
    if (v[@"switcher"] || v[@"switcherEnabled"] || v[@"switcherToggle"]) {
        if (![v[@"switcher"] isKindOfClass:NSArray.class] || [v[@"switcher"] count]>3) return [self defaults];
        for (id key in v[@"switcher"]) if (!validKey(key)) return [self defaults];
        if (HaloKeys(v[@"switcher"]).count != [v[@"switcher"] count]) return [self defaults];
        for (NSString *key in @[@"switcherEnabled",@"switcherToggle"])
            if (![v[key] isEqual:@0] && ![v[key] isEqual:@1]) return [self defaults];
        c.switcher=HaloKeys(v[@"switcher"]); c.switcherEnabled=[v[@"switcherEnabled"] boolValue]; c.switcherToggle=[v[@"switcherToggle"] boolValue];
    }
    return c.validationError ? [self defaults] : c;
}
@end

@implementation HaloShortcutEngine {
    BOOL _blocked, _wasDown[4], _menuSession;
    NSTimeInterval _returnAt;
}
static const NSTimeInterval HaloHandoffDelay = .04;
- (instancetype)init { if ((self=[super init])) { _config=[HaloShortcutConfig defaults]; _held=[NSSet set]; } return self; }
- (void)emit:(NSString *)action wheel:(HaloWheel)wheel { if (self.effect) self.effect(action,wheel); }
- (NSTimeInterval)pendingDeadline { return _returnAt; }
- (BOOL)enabled:(HaloWheel)wheel { return wheel!=HaloSwitcher || self.config.switcherEnabled; }
- (void)setConfig:(HaloShortcutConfig *)config {
    [self cancelUntilRelease]; _config=[config copy];
    for (HaloWheel w=HaloLauncher;w<=HaloSwitcher;w++) _wasDown[w]=[self enabled:w] && HaloChordMatches([self.config chordForWheel:w],_held,NO);
}
- (void)setSuspended:(BOOL)suspended { [self cancelUntilRelease]; _suspended=suspended; }
- (void)close:(BOOL)commit {
    if (_active) [self emit:commit?@"commit":@"cancel" wheel:_active];
    _active=HaloNoWheel; _menuSession=NO;
}
- (void)open:(HaloWheel)wheel {
    if (_active==wheel || ![self enabled:wheel]) return;
    [self close:NO]; _active=wheel; _returnAt=0; [self emit:@"show" wheel:wheel];
}
- (void)cancelUntilRelease { [self close:NO]; _returnAt=0; _blocked=_held.count>0; }
- (void)confirm { [self close:YES]; _returnAt=0; _blocked=YES; }
- (void)openSettings { [self cancelUntilRelease]; [self emit:@"settings" wheel:HaloNoWheel]; }
- (void)switchTo:(HaloWheel)wheel { [self close:YES]; [self open:wheel]; }
- (void)menuOpen:(HaloWheel)wheel {
    if (_suspended || ![self enabled:wheel]) return;
    [self cancelUntilRelease]; _blocked=NO; [self open:wheel]; _menuSession=YES;
}
- (HaloWheel)exactWheel {
    for (HaloWheel w=HaloSwitcher;w>=HaloLauncher;w--)
        if ([self enabled:w] && HaloChordMatches([self.config chordForWheel:w],_held,YES)) return w;
    return HaloNoWheel;
}
- (void)update:(NSSet *)keys at:(NSTimeInterval)time {
    NSSet *previous=_held; _held=[keys copy];
    BOOL down[4]={NO}, rise[4]={NO};
    for (HaloWheel w=HaloLauncher;w<=HaloSwitcher;w++) {
        down[w]=[self enabled:w] && HaloChordMatches([self.config chordForWheel:w],keys,NO);
        rise[w]=down[w]&&!_wasDown[w]; _wasDown[w]=down[w];
    }
    if (_suspended) { _blocked=keys.count>0; return; }
    if (_blocked) { if (!keys.count) _blocked=NO; return; }
    NSNumber *settings=@(self.config.settingsKey);
    if (_active && [keys containsObject:settings] && ![previous containsObject:settings]) { [self openSettings]; return; }
    BOOL escapeAssigned=NO;
    for (HaloWheel w=HaloLauncher;w<=HaloSwitcher;w++) if ([self enabled:w] && [[self.config chordForWheel:w] containsObject:@53]) escapeAssigned=YES;
    if (_active && [keys containsObject:@53] && ![previous containsObject:@53] && !escapeAssigned) { [self cancelUntilRelease]; return; }
    HaloWheel exact=[self exactWheel];
    if (_active && ([self.config toggleForWheel:_active] || _menuSession)) {
        if (exact && exact!=_active && rise[exact]) {
            if (HaloChordMatches([self.config chordForWheel:exact],[self.config chordForWheel:_active],NO)) _returnAt=time+HaloHandoffDelay;
            else [self switchTo:exact];
            return;
        }
        if (rise[_active]) { [self close:YES]; _returnAt=0; _blocked=YES; return; }
        if (_returnAt && (!exact || exact==_active)) _returnAt=0;
        return;
    }
    if (_active) {
        if (exact && exact!=_active && rise[exact]) { [self switchTo:exact]; return; }
        if (down[_active]) return;
        [self close:YES];
        // Guard subset releases so releasing all keys never flashes a wheel.
        if (exact) _returnAt=time+HaloHandoffDelay;
        return;
    }
    if (_returnAt) { if (!exact) _returnAt=0; else [self tick:time]; return; }
    if (exact && rise[exact]) [self open:exact];
}
- (void)tick:(NSTimeInterval)time {
    if (!_returnAt || time<_returnAt || _blocked) return;
    _returnAt=0;
    HaloWheel exact=[self exactWheel];
    if (exact) [self switchTo:exact];
}
@end
