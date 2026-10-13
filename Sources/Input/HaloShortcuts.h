#import <Foundation/Foundation.h>

// Physical key codes; modifiers are normalized except the explicit Left Shift token.
enum { HaloFn=256, HaloControl, HaloOption, HaloShift, HaloCommand, HaloLeftShift };
typedef NS_ENUM(NSInteger, HaloWheel) { HaloNoWheel=0, HaloLauncher=1, HaloQuitter=2, HaloSwitcher=3 };
NSSet<NSNumber *> *HaloKeys(NSArray<NSNumber *> *keys);
NSArray<NSNumber *> *HaloSorted(NSSet<NSNumber *> *keys);
BOOL HaloChordMatches(NSSet *chord, NSSet *held, BOOL exact);

@interface HaloShortcutConfig : NSObject <NSCopying>
@property(copy) NSSet<NSNumber *> *launcher;
@property(copy) NSSet<NSNumber *> *quitter;
@property(copy) NSSet<NSNumber *> *switcher;
@property BOOL switcherEnabled;
@property BOOL switcherToggle;
@property NSInteger settingsKey;
@property BOOL launcherToggle;
@property BOOL quitterToggle;
+ (instancetype)defaults;
+ (instancetype)fromDictionary:(id)value;
- (NSDictionary *)dictionary;
- (NSSet *)chordForWheel:(HaloWheel)wheel;
- (BOOL)toggleForWheel:(HaloWheel)wheel;
- (NSString *)validationError;
@end

// Pure state machine. No input monitoring, app launching, or destructive actions.
@interface HaloShortcutEngine : NSObject
@property(nonatomic,strong) HaloShortcutConfig *config;
@property(readonly) HaloWheel active;
@property(copy) void (^effect)(NSString *action, HaloWheel wheel);
@property(readonly,copy) NSSet<NSNumber *> *held;
@property(readonly) NSTimeInterval pendingDeadline;
@property(nonatomic) BOOL suspended;
- (void)update:(NSSet<NSNumber *> *)held at:(NSTimeInterval)time;
- (void)tick:(NSTimeInterval)time;
- (void)cancelUntilRelease;
- (void)menuOpen:(HaloWheel)wheel;
- (void)confirm;
- (void)openSettings;
@end
