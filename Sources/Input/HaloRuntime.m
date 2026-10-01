#import "HaloSettings.h"
#import <ApplicationServices/ApplicationServices.h>
#import <Carbon/Carbon.h>
static const int64_t HaloReplayTag=0x48414c4f5245504c;

BOOL HaloIsModifierCode(NSInteger code) { return code>=54 && code<=63 && code!=57; }
NSSet *HaloModifierKeys(CGEventFlags flags) {
    NSMutableSet *keys=[NSMutableSet new];
    if (flags&kCGEventFlagMaskSecondaryFn) [keys addObject:@(HaloFn)];
    if (flags&kCGEventFlagMaskControl) [keys addObject:@(HaloControl)];
    if (flags&kCGEventFlagMaskAlternate) [keys addObject:@(HaloOption)];
    if (flags&kCGEventFlagMaskShift) [keys addObject:@(HaloShift)];
    if (flags&kCGEventFlagMaskCommand) [keys addObject:@(HaloCommand)];
    return keys;
}
NSString *HaloKeyName(NSInteger key) {
    NSDictionary *names=@{@(HaloFn):@"fn",@(HaloControl):@"⌃",@(HaloOption):@"⌥",@(HaloShift):@"⇧",@(HaloCommand):@"⌘",@36:@"↩",@48:@"⇥",@49:@"Space",@51:@"⌫",@53:@"Esc",@117:@"⌦",@123:@"←",@124:@"→",@125:@"↓",@126:@"↑",@115:@"Home",@119:@"End",@116:@"Pg Up",@121:@"Pg Dn",@71:@"Clear",@76:@"Enter",@122:@"F1",@120:@"F2",@99:@"F3",@118:@"F4",@96:@"F5",@97:@"F6",@98:@"F7",@100:@"F8",@101:@"F9",@109:@"F10",@103:@"F11",@111:@"F12",@105:@"F13",@107:@"F14",@113:@"F15",@106:@"F16",@64:@"F17",@79:@"F18",@80:@"F19",@90:@"F20"};
    if (names[@(key)]) return names[@(key)];
    TISInputSourceRef source=TISCopyCurrentKeyboardLayoutInputSource();
    CFDataRef data=source?TISGetInputSourceProperty(source,kTISPropertyUnicodeKeyLayoutData):NULL;
    NSString *result=nil;
    if (data) {
        UInt32 dead=0; UniChar chars[8]; UniCharCount count=0;
        OSStatus s=UCKeyTranslate((const UCKeyboardLayout *)CFDataGetBytePtr(data),(UInt16)key,kUCKeyActionDisplay,0,LMGetKbdType(),kUCKeyTranslateNoDeadKeysBit,&dead,8,&count,chars);
        if (s==noErr && count) result=[[NSString stringWithCharacters:chars length:count] uppercaseString];
    }
    if (source) CFRelease(source);
    return result.length?result:[NSString stringWithFormat:@"Key %ld",(long)key];
}
NSString *HaloChordName(NSSet *keys) {
    NSMutableArray *parts=[NSMutableArray new];
    for (NSNumber *k in @[@(HaloFn),@(HaloControl),@(HaloOption),@(HaloShift),@(HaloCommand)]) if ([keys containsObject:k]) [parts addObject:HaloKeyName(k.integerValue)];
    for (NSNumber *k in HaloSorted(keys)) if (k.integerValue<HaloFn) [parts addObject:HaloKeyName(k.integerValue)];
    return [parts componentsJoinedByString:@"  +  "];
}

@interface HaloRuntime ()
- (CGEventRef)event:(CGEventRef)event type:(CGEventType)type;
@end
static CGEventRef inputCallback(__unused CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *context) {
    @autoreleasepool { return [(__bridge HaloRuntime *)context event:event type:type]; }
}

@implementation HaloRuntime {
    id<HaloWheelDriver> _driver;
    NSUserDefaults *_defaults;
    NSMutableArray *_workspaceObservers, *_appObservers;
    BOOL _monitorInput;
    CFMachPortRef _tap;
    CFRunLoopSourceRef _tapSource;
    NSMutableSet *_regularHeld, *_swallowed;
    NSMutableArray *_buffer;
    pid_t _bufferPID;
    BOOL _passthrough, _mouseCaptured, _presented[2], _settingsKeyDown;
    NSUInteger _pendingTicket, _actionGeneration;
    NSUInteger _showTickets[2], _presentedTickets[2];
    HaloSettingsController *_settings;
    NSMenuItem *_launcherItem, *_quitterItem, *_settingsItem;
    id _localFallback, _globalFallback;
}
- (instancetype)initWithDriver:(id<HaloWheelDriver>)driver defaults:(NSUserDefaults *)defaults {
    if ((self=[super init])) {
        _driver=driver; _defaults=defaults; _bridgeReady=driver!=nil;
        _workspaceObservers=[NSMutableArray new]; _appObservers=[NSMutableArray new];
        _engine=[HaloShortcutEngine new];
        _engine.config=[HaloShortcutConfig fromDictionary:[defaults objectForKey:@"HaloShortcuts.v1"]];
        _regularHeld=[NSMutableSet new]; _swallowed=[NSMutableSet new]; _buffer=[NSMutableArray new];
        __weak HaloRuntime *weak=self;
        _engine.effect=^(NSString *action,HaloWheel wheel) {
            // Keep event-tap work bounded; native window work happens after the callback.
            HaloRuntime *owner=weak;
            NSUInteger generation=owner ? owner->_actionGeneration : 0;
            BOOL isWheel=wheel>=HaloLauncher && wheel<=HaloQuitter;
            NSUInteger session=0;
            if (owner && isWheel) {
                if ([action isEqual:@"show"]) ++owner->_showTickets[wheel-1];
                session=owner->_showTickets[wheel-1];
            }
            dispatch_async(dispatch_get_main_queue(),^{
                HaloRuntime *current=weak;
                if (current && (generation==current->_actionGeneration || [action isEqual:@"cancel"])) {
                    if (isWheel && [action isEqual:@"show"]) {
                        if (session!=current->_showTickets[wheel-1]) return;
                        current->_presentedTickets[wheel-1]=session;
                    }
                    if (isWheel && [action isEqual:@"commit"] && session!=current->_presentedTickets[wheel-1]) return;
                    [current apply:action wheel:wheel];
                }
            });
        };
    } return self;
}
- (void)connectWithStatusItem:(NSStatusItem *)status monitorInput:(BOOL)monitorInput {
    _monitorInput=monitorInput;
    NSMenu *menu=[NSMenu new];
    _launcherItem=[menu addItemWithTitle:@"Open Launcher" action:@selector(menuLauncher:) keyEquivalent:@""]; _launcherItem.target=self;
    _quitterItem=[menu addItemWithTitle:@"Open Quitter" action:@selector(menuQuitter:) keyEquivalent:@""]; _quitterItem.target=self;
    [menu addItem:NSMenuItem.separatorItem];
    _settingsItem=[menu addItemWithTitle:@"Settings…" action:@selector(showSettings:) keyEquivalent:@""]; _settingsItem.target=self;
    [menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit=[menu addItemWithTitle:@"Quit Halo" action:@selector(quit:) keyEquivalent:@"q"]; quit.target=self;
    status.menu=menu; status.button.toolTip=@"Halo"; status.button.accessibilityLabel=@"Halo";
    [self updateMenu];
    // One engine owns input, including during recording and permission recovery.
    [self retryInput];
    __weak HaloRuntime *weak=self;
    for (NSNotificationName name in @[NSWorkspaceWillSleepNotification,NSWorkspaceSessionDidResignActiveNotification]) {
        [_workspaceObservers addObject:[NSWorkspace.sharedWorkspace.notificationCenter addObserverForName:name object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { [weak resetInput]; }]];
    }
    [_appObservers addObject:[NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(__unused NSNotification *note) { if (!weak.inputReady) [weak retryInput]; }]];
}
- (void)updateMenu {
    _launcherItem.title=[@"Open Launcher   " stringByAppendingString:HaloChordName(self.engine.config.launcher)];
    _quitterItem.title=[@"Open Quitter   " stringByAppendingString:HaloChordName(self.engine.config.quitter)];
    _settingsItem.title=[NSString stringWithFormat:@"Settings…   %@  +  %@",HaloChordName(self.engine.config.launcher),HaloKeyName(self.engine.config.settingsKey)];
}
- (void)retryInput {
    if (!_monitorInput) return;
    if (_tap) { CGEventTapEnable(_tap,true); _inputReady=CGEventTapIsEnabled(_tap); }
    else {
        CGEventMask mask=CGEventMaskBit(kCGEventKeyDown)|CGEventMaskBit(kCGEventKeyUp)|CGEventMaskBit(kCGEventFlagsChanged)|CGEventMaskBit(kCGEventLeftMouseDown)|CGEventMaskBit(kCGEventLeftMouseUp);
        _tap=CGEventTapCreate(kCGSessionEventTap,kCGHeadInsertEventTap,kCGEventTapOptionDefault,mask,inputCallback,(__bridge void *)self);
        if (_tap) { _tapSource=CFMachPortCreateRunLoopSource(NULL,_tap,0); CFRunLoopAddSource(CFRunLoopGetMain(),_tapSource,kCFRunLoopCommonModes); CGEventTapEnable(_tap,true); }
        _inputReady=_tap && CGEventTapIsEnabled(_tap);
    }
    if (_inputReady) {
        if (_localFallback) { [NSEvent removeMonitor:_localFallback]; _localFallback=nil; }
        if (_globalFallback) { [NSEvent removeMonitor:_globalFallback]; _globalFallback=nil; }
    } else if (!_localFallback) {
        __weak HaloRuntime *weak=self;
        NSEventMask mask=NSEventMaskFlagsChanged|NSEventMaskKeyDown|NSEventMaskKeyUp|NSEventMaskLeftMouseDown|NSEventMaskLeftMouseUp;
        _localFallback=[NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent *(NSEvent *e) {
            CGEventRef cg=e.CGEvent; if (!cg) return e;
            return [weak event:cg type:CGEventGetType(cg)] ? e : nil;
        }];
        _globalFallback=[NSEvent addGlobalMonitorForEventsMatchingMask:mask handler:^(NSEvent *e) {
            CGEventRef cg=e.CGEvent; if (cg) [weak event:cg type:CGEventGetType(cg)];
        }];
    }
    if (self.statusChanged) self.statusChanged();
}
- (void)apply:(NSString *)action wheel:(HaloWheel)wheel {
    if ([action isEqual:@"settings"]) { [self showSettings:nil]; return; }
    if (!self.bridgeReady || wheel<HaloLauncher || wheel>HaloQuitter) return;
    if ([action isEqual:@"show"]) {
        // A fast press/release may have completed before the main queue gets here.
        // Skipping that stale reveal is what keeps shortcut spamming flicker-free.
        if (self.engine.active!=wheel || self.engine.suspended) return;
        [_driver showWheel:wheel];
        _presented[wheel-1]=YES;
    } else {
        if ([action isEqual:@"commit"] && !self.engine.suspended && _presented[wheel-1]) {
            [_driver commitWheel:wheel];
        }
        _presented[wheel-1]=NO;
        [_driver hideWheel:wheel];
    }
}
- (void)cancel { [self.engine cancelUntilRelease]; }
- (BOOL)handleWheelKeyEvent:(NSEvent *)event {
    // A nonactivating key panel receives ordinary keys even when macOS only
    // permits the global modifier monitor. Unlike a global NSEvent monitor,
    // this route can consume comma before it reaches the previous application.
    if (!event.CGEvent) return NO;
    return [self event:event.CGEvent type:CGEventGetType(event.CGEvent)]==NULL;
}
- (void)setRecordInput:(void (^)(NSSet<NSNumber *> *))recordInput {
    if (recordInput) ++_actionGeneration;
    _recordInput=[recordInput copy];
    self.engine.suspended=recordInput!=nil;
    ++_pendingTicket;
    if (recordInput && self.bridgeReady) {
        // Cancel queued/native selections before the first recorded key arrives.
        for (HaloWheel w=HaloLauncher;w<=HaloQuitter;w++) {
            _presented[w-1]=NO;
            [_driver hideWheel:w];
        }
    }
}
- (void)showSettings:(id)sender {
    [self cancel]; self.settingsVisible=YES;
    if (!_settings) _settings=[[HaloSettingsController alloc] initWithRuntime:self];
    [_settings present];
}
- (void)menuLauncher:(id)sender { [self.engine menuOpen:HaloLauncher]; }
- (void)menuQuitter:(id)sender { [self.engine menuOpen:HaloQuitter]; }
- (void)quit:(id)sender { [self cancel]; [NSApp terminate:nil]; }
- (void)saveConfig:(HaloShortcutConfig *)config {
    NSAssert(!config.validationError,@"Invalid shortcut configuration");
    ++_actionGeneration;
    [self cancel]; self.engine.config=[config copy];
    [_defaults setObject:config.dictionary forKey:@"HaloShortcuts.v1"];
    [_defaults synchronize];
    [self updateMenu];
    if (!self.inputReady) [self retryInput];
}
- (void)flushBuffer {
    for (id stored in _buffer) {
        CGEventRef event=(__bridge CGEventRef)stored;
        CGEventSetIntegerValueField(event,kCGEventSourceUserData,HaloReplayTag);
        CGEventPostToPid(_bufferPID,event);
    }
    [_buffer removeAllObjects];
}
- (void)resetInput {
    _settingsKeyDown=NO;
    [self cancel]; [self flushBuffer]; [_regularHeld removeAllObjects];
    [_swallowed removeAllObjects]; _passthrough=NO; _mouseCaptured=NO;
    [self.engine update:[NSSet set] at:NSProcessInfo.processInfo.systemUptime];
}
- (void)scheduleTransition {
    NSUInteger ticket=++_pendingTicket;
    NSTimeInterval deadline=self.engine.pendingDeadline;
    if (!deadline) return;
    __weak HaloRuntime *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(MAX(0,deadline-NSProcessInfo.processInfo.systemUptime)*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        HaloRuntime *s=weak;
        if (s && ticket==s->_pendingTicket) [s.engine tick:NSProcessInfo.processInfo.systemUptime];
    });
}
- (CGEventRef)event:(CGEventRef)event type:(CGEventType)type {
    if (type==kCGEventTapDisabledByTimeout || type==kCGEventTapDisabledByUserInput) {
        [self resetInput]; CGEventTapEnable(_tap,true); return event;
    }
    if (CGEventGetIntegerValueField(event,kCGEventSourceUserData)==HaloReplayTag) return event;
    if (type==kCGEventLeftMouseDown || type==kCGEventLeftMouseUp) {
        if (type==kCGEventLeftMouseUp && _mouseCaptured) {
            _mouseCaptured=NO; [self.engine confirm]; return NULL;
        }
        HaloWheel active=self.engine.active;
        if (type==kCGEventLeftMouseDown && active && !self.engine.suspended) {
            // Clicking selects in toggle/menu sessions; hold mode remains release-to-select.
            BOOL toggle=active==HaloLauncher?self.engine.config.launcherToggle:self.engine.config.quitterToggle;
            if (toggle || !self.engine.held.count) {
                NSRect frame=[_driver frameForWheel:active];
                if (!NSIsEmptyRect(frame) && NSPointInRect(NSEvent.mouseLocation,frame)) _mouseCaptured=YES;
                else { [self cancel]; _mouseCaptured=YES; }
                return NULL;
            }
        }
        return event;
    }
    NSInteger code=CGEventGetIntegerValueField(event,kCGKeyboardEventKeycode);
    BOOL down=type==kCGEventKeyDown, up=type==kCGEventKeyUp;
    NSNumber *key=@(code);
    if (up && code==self.engine.config.settingsKey) _settingsKeyDown=NO;
    // Handle the Settings key against the visible session before interpreting
    // this key event's modifier snapshot (Fn flags can vary on ordinary keys).
    // Swallow the whole key pair so comma never reaches the previous app.
    if (!self.engine.suspended && down && code==self.engine.config.settingsKey &&
        (self.engine.active || _presented[0] || _presented[1])) {
        if (!_settingsKeyDown) {
            _settingsKeyDown=YES;
            [self.engine openSettings];
            // Event taps can deliver this ordinary key outside AppKit's main
            // turn. Keep the engine route and schedule a direct, idempotent
            // main-queue presentation so comma cannot be dropped.
            __weak HaloRuntime *weak=self;
            dispatch_async(dispatch_get_main_queue(), ^{
                HaloRuntime *runtime=weak;
                if (runtime) [runtime showSettings:nil];
            });
        }
        [_swallowed addObject:key]; [_buffer removeAllObjects];
        [self scheduleTransition];
        return NULL;
    }
    if (down && !HaloIsModifierCode(code)) [_regularHeld addObject:key];
    if (up) [_regularHeld removeObject:key];
    NSMutableSet *held=[_regularHeld mutableCopy]; [held unionSet:HaloModifierKeys(CGEventGetFlags(event))];
    if (self.recordInput) {
        [self.engine update:held at:NSProcessInfo.processInfo.systemUptime];
        self.recordInput(held);
        if (down) [_swallowed addObject:key];
        if (up) [_swallowed removeObject:key];
        return NULL;
    }
    BOOL swallowedUp=up && [_swallowed containsObject:key];
    if (swallowedUp) [_swallowed removeObject:key];
    HaloWheel before=self.engine.active;
    [self.engine update:held at:NSProcessInfo.processInfo.systemUptime];
    [self scheduleTransition];
    HaloWheel after=self.engine.active;
    BOOL trigger=before && down && (code==self.engine.config.settingsKey || code==53);
    if (after || before || trigger) {
        for (NSNumber *k in _regularHeld) [_swallowed addObject:k];
        // Buffered prefix keys belong to the recognized chord and must never be replayed.
        [_buffer removeAllObjects];
        if (!held.count) _passthrough=NO;
        return (down||swallowedUp)?NULL:event;
    }
    if (swallowedUp) { if (!held.count) _passthrough=NO; return NULL; }
    if (!held.count) _passthrough=NO;
    BOOL prefix=held.count && ([held isSubsetOfSet:self.engine.config.launcher] || [held isSubsetOfSet:self.engine.config.quitter]);
    if (self.inputReady && !_passthrough && down && prefix) {
        pid_t pid=NSWorkspace.sharedWorkspace.frontmostApplication.processIdentifier;
        if (_buffer.count && (pid!=_bufferPID || _buffer.count>=128)) { [self flushBuffer]; _passthrough=YES; return event; }
        _bufferPID=pid; [_buffer addObject:CFBridgingRelease(CGEventCreateCopy(event))]; return NULL;
    }
    if (_buffer.count) {
        // A chord that never completed is ordinary typing. Replay in original order.
        [_buffer addObject:CFBridgingRelease(CGEventCreateCopy(event))];
        [self flushBuffer]; _passthrough=held.count>0;
        if (_passthrough) [self.engine cancelUntilRelease];
        return NULL;
    }
    return event;
}
- (void)stop {
    ++_actionGeneration; ++_pendingTicket;
    [self resetInput];
    for (HaloWheel wheel=HaloLauncher;wheel<=HaloQuitter;wheel++) [_driver hideWheel:wheel];
    _monitorInput=NO;
    if (_tap) { CGEventTapEnable(_tap,false); CFMachPortInvalidate(_tap); CFRelease(_tap); _tap=NULL; }
    if (_tapSource) { CFRunLoopRemoveSource(CFRunLoopGetMain(),_tapSource,kCFRunLoopCommonModes); CFRelease(_tapSource); _tapSource=NULL; }
    if (_localFallback) { [NSEvent removeMonitor:_localFallback]; _localFallback=nil; }
    if (_globalFallback) { [NSEvent removeMonitor:_globalFallback]; _globalFallback=nil; }
    for (id observer in _workspaceObservers) [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:observer];
    for (id observer in _appObservers) [NSNotificationCenter.defaultCenter removeObserver:observer];
    [_workspaceObservers removeAllObjects]; [_appObservers removeAllObjects];
    _inputReady=NO;
}
@end
