#import <AppKit/AppKit.h>
#import "HaloShortcuts.h"

NSString *HaloKeyName(NSInteger key);
NSString *HaloChordName(NSSet<NSNumber *> *keys);
NSSet<NSNumber *> *HaloModifierKeys(CGEventFlags flags);
BOOL HaloIsModifierCode(NSInteger code);
// The rebuilt app talks to real source-owned controllers, never executable offsets.
@protocol HaloWheelDriver <NSObject>
- (void)showWheel:(HaloWheel)wheel NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(showWheel(_:));
- (void)hideWheel:(HaloWheel)wheel NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(hideWheel(_:));
- (void)commitWheel:(HaloWheel)wheel NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(commitWheel(_:));
- (NSRect)frameForWheel:(HaloWheel)wheel NS_SWIFT_UI_ACTOR;
@end

@interface HaloRuntime : NSObject
@property(strong) HaloShortcutEngine *engine;
@property(readonly) BOOL inputReady;
@property(readonly) BOOL bridgeReady;
@property BOOL settingsVisible;
@property(nonatomic,copy) void (^recordInput)(NSSet<NSNumber *> *held);
@property(copy) void (^statusChanged)(void);
- (instancetype)initWithDriver:(id<HaloWheelDriver>)driver defaults:(NSUserDefaults *)defaults;
- (void)connectWithStatusItem:(NSStatusItem *)status monitorInput:(BOOL)monitorInput;
- (void)stop;
- (void)showSettings:(id)sender;
- (void)saveConfig:(HaloShortcutConfig *)config;
- (void)retryInput;
- (void)cancel;
- (BOOL)handleWheelKeyEvent:(NSEvent *)event;
@end

@interface HaloSettingsController : NSWindowController <NSWindowDelegate>
- (instancetype)initWithRuntime:(HaloRuntime *)runtime;
- (void)present;
- (void)refreshStatus;
@end
