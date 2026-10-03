#import "HaloSettings.h"
#import <ApplicationServices/ApplicationServices.h>
extern void HaloAddSettingsGlass(void *parent);
extern void HaloAddCustomizationPage(void *parent, NSInteger tab);
extern void HaloAddActivationSwitch(void *parent, BOOL quitter, BOOL enabled, void (^changed)(BOOL));

@interface HaloFlippedView : NSView @end
@implementation HaloFlippedView
- (BOOL)isFlipped { return YES; }
// Borderless panels do not get a title-bar drag region automatically. Keep
// controls clickable while allowing blank glass/header space to move the
// window like a normal macOS utility window.
- (BOOL)mouseDownCanMoveWindow { return YES; }
- (void)mouseDown:(NSEvent *)event { [self.window performWindowDragWithEvent:event]; }
@end

// Glass is composited separately; a real painted backing also gives WindowServer
// a continuous mouse surface in the empty areas between controls.
@interface HaloSettingsSurface : HaloFlippedView @end
@implementation HaloSettingsSurface
- (void)drawRect:(NSRect)dirtyRect {
    [[NSColor.blackColor colorWithAlphaComponent:.02] setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:24 yRadius:24] fill];
}
@end

@interface HaloSettingsPanel : NSPanel @end
@implementation HaloSettingsPanel
- (BOOL)canBecomeKeyWindow { return YES; }
- (BOOL)canBecomeMainWindow { return YES; }
@end

@interface HaloSidebarButton : NSButton @end
@implementation HaloSidebarButton
- (void)drawRect:(NSRect)rect {
    if (self.state==NSControlStateValueOn) {
        [[NSColor.whiteColor colorWithAlphaComponent:.10] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,0,1) xRadius:10 yRadius:10] fill];
    }
    [super drawRect:rect];
}
@end

static NSTextField *label(NSString *text, CGFloat size, NSFontWeight weight, NSRect frame) {
    NSTextField *v=[NSTextField labelWithString:text]; v.font=[NSFont systemFontOfSize:size weight:weight];
    v.frame=frame; v.lineBreakMode=NSLineBreakByWordWrapping; v.maximumNumberOfLines=0; return v;
}
static NSButton *button(NSString *title, id target, SEL action, NSRect frame) {
    NSButton *v=[NSButton buttonWithTitle:title target:target action:action];
    v.frame=frame; v.bezelStyle=NSBezelStyleRounded; v.controlSize=NSControlSizeRegular; return v;
}
static NSView *glass(NSRect frame, __unused CGFloat radius, NSView *parent) {
    HaloAddSettingsGlass((__bridge void *)parent);
    HaloFlippedView *content=[[HaloFlippedView alloc] initWithFrame:frame];
    content.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    [parent addSubview:content]; return content;
}

@implementation HaloSettingsController {
    __weak HaloRuntime *_runtime;
    HaloShortcutConfig *_draft;
    NSView *_page;
    NSView *_sidebar;
    NSBox *_divider;
    NSTextField *_version;
    NSButton *_closeButton;
    NSMutableArray<NSButton *> *_nav;
    NSArray<NSButton *> *_recorders;
    NSTextField *_status;
    NSButton *_cancelRecord, *_permission;
    NSInteger _tab, _recording;
    NSSet *_peak;
    BOOL _overflow;
}
- (instancetype)initWithRuntime:(HaloRuntime *)runtime {
    NSWindow *window=[[HaloSettingsPanel alloc] initWithContentRect:NSMakeRect(0,0,860,760)
        styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|NSWindowStyleMaskFullSizeContentView
        backing:NSBackingStoreBuffered defer:NO];
    if ((self=[super initWithWindow:window])) {
        _runtime=runtime; _recording=-1; _draft=[runtime.engine.config copy];
        window.title=@"Halo Settings";
        window.titlebarAppearsTransparent=YES; window.titleVisibility=NSWindowTitleHidden;
        for (NSNumber *kind in @[@(NSWindowCloseButton),@(NSWindowMiniaturizeButton),@(NSWindowZoomButton)])
            [window standardWindowButton:kind.unsignedIntegerValue].hidden=YES;
        window.opaque=NO; window.backgroundColor=NSColor.clearColor; window.hasShadow=NO;
        ((NSPanel *)window).hidesOnDeactivate=NO;
        window.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
        window.releasedWhenClosed=NO; window.delegate=self; window.movableByWindowBackground=YES;
        window.collectionBehavior=NSWindowCollectionBehaviorMoveToActiveSpace|NSWindowCollectionBehaviorFullScreenAuxiliary;
        [window center];
        HaloSettingsSurface *root=[[HaloSettingsSurface alloc] initWithFrame:NSMakeRect(0,0,860,760)];
        root.wantsLayer=YES; root.layer.cornerRadius=24; root.layer.cornerCurve=kCACornerCurveContinuous;
        root.layer.masksToBounds=YES; root.layer.backgroundColor=NSColor.clearColor.CGColor;
        window.contentView=root;
        NSView *surface=glass(root.bounds,24,root);
        NSView *side=[[HaloFlippedView alloc] initWithFrame:NSMakeRect(14,16,132,728)]; [surface addSubview:side]; _sidebar=side;
        NSTextField *sideTitle=label(@"Settings",12,NSFontWeightSemibold,NSMakeRect(10,9,110,20));
        sideTitle.textColor=NSColor.secondaryLabelColor; [side addSubview:sideTitle];
        _nav=[NSMutableArray new];
        NSArray *titles=@[@"General",@"Appearance",@"Apps",@"Advanced"];
        for (NSUInteger i=0;i<titles.count;i++) {
            HaloSidebarButton *b=[HaloSidebarButton buttonWithTitle:titles[i] target:self action:@selector(selectTab:)];
            b.frame=NSMakeRect(0,46+i*38,132,32); b.tag=i; b.bezelStyle=NSBezelStyleRegularSquare; b.buttonType=NSButtonTypePushOnPushOff;
            b.bordered=NO; b.alignment=NSTextAlignmentLeft; b.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
            b.contentTintColor=NSColor.labelColor;
            b.title=[@"   " stringByAppendingString:titles[i]];
            b.accessibilityLabel=titles[i]; [side addSubview:b]; [_nav addObject:b];
        }
        NSTextField *version=label(NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"]?:@"",10,NSFontWeightRegular,NSMakeRect(10,696,110,16));
        version.textColor=NSColor.tertiaryLabelColor; [side addSubview:version];
        _version=version;
        NSBox *divider=[[NSBox alloc] initWithFrame:NSMakeRect(158,22,1,716)]; divider.boxType=NSBoxSeparator; divider.alphaValue=.22; [surface addSubview:divider];
        _divider=divider;
        _page=[[HaloFlippedView alloc] initWithFrame:NSMakeRect(180,22,656,716)]; [surface addSubview:_page];
        NSButton *close=button(@"",self,@selector(closeSettings:),NSMakeRect(812,15,28,28));
        close.bordered=NO; close.image=[NSImage imageWithSystemSymbolName:@"xmark" accessibilityDescription:@"Close settings"];
        close.accessibilityLabel=@"Close settings"; close.keyEquivalent=@"w"; close.keyEquivalentModifierMask=NSEventModifierFlagCommand; [surface addSubview:close];
        _closeButton=close;
        __weak HaloSettingsController *weak=self;
        runtime.statusChanged=^{ [weak refreshStatus]; };
        [self drawPage];
    } return self;
}
- (void)present {
    _runtime.settingsVisible=YES; [self refreshStatus];
    [NSApp activateIgnoringOtherApps:YES]; [self.window makeKeyAndOrderFront:nil];
}
- (void)windowWillClose:(__unused NSNotification *)note {
    [self stopRecording]; _runtime.settingsVisible=NO;
    _draft=[_runtime.engine.config copy]; [self drawPage];
}
- (void)closeSettings:(id)sender { [self.window close]; }
- (void)windowDidResignKey:(__unused NSNotification *)note { if (_recording>=0) [self stopRecording]; }
- (void)selectTab:(NSButton *)sender { [self stopRecording]; _tab=sender.tag; [self drawPage]; }
- (void)drawPage {
    [self layoutPageWithSize:_tab==1?NSMakeSize(960,740):_tab==2?NSMakeSize(960,740):_tab==3?NSMakeSize(700,570):NSMakeSize(700,500)];
    [self populatePage];
}
- (void)layoutPageWithSize:(NSSize)size {
    // Fit the task instead of leaving a tall empty canvas on simpler pages.
    // Keep the top-left corner anchored when switching panes.
    NSRect frame=self.window.frame;
    NSRect next=[self.window frameRectForContentRect:NSMakeRect(0,0,size.width,size.height)];
    next.origin=NSMakePoint(frame.origin.x,NSMaxY(frame)-next.size.height);
    NSRect visible=self.window.screen.visibleFrame;
    if (!NSIsEmptyRect(visible)) {
        next.origin.x=MAX(NSMinX(visible),MIN(next.origin.x,NSMaxX(visible)-next.size.width));
        next.origin.y=MAX(NSMinY(visible),MIN(next.origin.y,NSMaxY(visible)-next.size.height));
    }
    [self.window setFrame:next display:YES];
    _sidebar.frame=NSMakeRect(14,16,132,size.height-32);
    _version.frame=NSMakeRect(10,size.height-64,110,16);
    _divider.frame=NSMakeRect(158,22,1,size.height-44);
    _page.frame=NSMakeRect(180,22,size.width-204,size.height-44);
    _closeButton.frame=NSMakeRect(size.width-48,15,28,28);
}
- (void)populatePage {
    for (NSView *view in [_page.subviews copy]) [view removeFromSuperview];
    for (NSButton *nav in _nav) nav.state=nav.tag==_tab?NSControlStateValueOn:NSControlStateValueOff;
    NSArray *titles=@[@"General",@"Appearance",@"Apps",@"Advanced"];
    [_page addSubview:label(titles[_tab],18,NSFontWeightSemibold,NSMakeRect(0,0,345,28))];
    if (_tab!=0) {
        HaloAddCustomizationPage((__bridge void *)_page,_tab); return;
    }
    NSMutableArray *recorders=[NSMutableArray new];
    CGFloat width=_page.bounds.size.width-8;
    CGFloat controlX=width-226;
    for (NSInteger i=0;i<3;i++) {
        CGFloat y=48+(i*94);
        NSView *card=[[HaloFlippedView alloc] initWithFrame:NSMakeRect(0,y,width,84)]; [_page addSubview:card];
        card.wantsLayer=YES; card.layer.cornerRadius=12;
        card.layer.backgroundColor=[NSColor.whiteColor colorWithAlphaComponent:.035].CGColor;
        [card addSubview:label(@[@"Launcher",@"Quitter",@"Settings"] [i],13,NSFontWeightMedium,NSMakeRect(14,14,142,21))];
        NSString *detail=i==0?@"1–3 keys":i==1?(_draft.launcher.count==3?@"Launcher + one key":@"1–3 keys"):@"While a wheel is open";
        NSTextField *small=label(detail,11,NSFontWeightRegular,NSMakeRect(14,38,200,22)); small.textColor=NSColor.secondaryLabelColor; [card addSubview:small];
        NSButton *recorder=button(@"",self,@selector(record:),NSMakeRect(controlX,9,212,28));
        recorder.tag=i; recorder.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        recorder.accessibilityLabel=[@[@"Launcher shortcut",@"Quitter shortcut",@"Settings key"] objectAtIndex:i];
        recorder.toolTip=@"Click to record a shortcut"; [card addSubview:recorder]; [recorders addObject:recorder];
        if (i<2) {
            NSView *mode=[[NSView alloc] initWithFrame:NSMakeRect(controlX,42,212,32)];
            mode.toolTip=@"Hold: release to select. Toggle: click or press the shortcut again to select.";
            [card addSubview:mode];
            __weak HaloSettingsController *weak=self;
            HaloAddActivationSwitch((__bridge void *)mode,i==1,i==0?_draft.launcherToggle:_draft.quitterToggle,^(BOOL enabled) {
                HaloSettingsController *strong=weak;
                if (!strong) return;
                [strong stopRecording];
                if (i==0) strong->_draft.launcherToggle=enabled; else strong->_draft.quitterToggle=enabled;
                [strong->_runtime saveConfig:strong->_draft];
                [strong updateControls];
            });
        }
    }
    _recorders=recorders;
    _status=label(@"",11,NSFontWeightRegular,NSMakeRect(0,336,width-110,44));
    _status.textColor=NSColor.secondaryLabelColor; [_page addSubview:_status];
    _permission=button(@"Enable…",self,@selector(permission:),NSMakeRect(width-96,336,96,28)); [_page addSubview:_permission];
    NSButton *reset=button(@"Reset shortcuts",self,@selector(reset:),NSMakeRect(0,394,116,28));
    reset.bordered=NO; reset.font=[NSFont systemFontOfSize:11]; reset.contentTintColor=NSColor.secondaryLabelColor; [_page addSubview:reset];
    _cancelRecord=button(@"Cancel",self,@selector(cancelRecord:),NSMakeRect(width-90,394,90,28));
    _cancelRecord.hidden=YES; [_page addSubview:_cancelRecord];
    [self updateControls]; [self refreshStatus];
}
- (void)updateControls {
    if (_tab!=0) return;
    _recorders[0].title=HaloChordName(_draft.launcher);
    _recorders[1].title=HaloChordName(_draft.quitter);
    _recorders[2].title=HaloKeyName(_draft.settingsKey);
}
- (void)refreshStatus {
    if (_tab!=0 || _recording>=0) return;
    _permission.hidden=_runtime.inputReady;
    _status.stringValue=_runtime.inputReady?(@""):@"Allow Accessibility to use global shortcuts.";
}
- (void)permission:(__unused id)sender {
    NSDictionary *options=@{(__bridge NSString *)kAXTrustedCheckOptionPrompt:@YES};
    AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)options);
    [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];
    [_runtime retryInput];
}
- (void)record:(NSButton *)sender {
    [self stopRecording]; [_runtime cancel];
    _recording=sender.tag; _peak=[NSSet set]; _overflow=NO;
    sender.title=@"Press keys…"; _cancelRecord.hidden=NO;
    _status.stringValue=_recording==2?@"Press and release one key.":(_recording==1&&_draft.launcher.count==3?@"Press and release one extra key.":@"Hold 1–3 keys together, then release.");
    __weak HaloSettingsController *weak=self;
    _runtime.recordInput=^(NSSet *keys) { [weak recordKeys:keys]; };
}
- (void)recordKeys:(NSSet *)keys {
    if (_recording<0) return;
    NSUInteger max=(_recording==2 || (_recording==1 && _draft.launcher.count==3))?1:3;
    if (keys.count>max) _overflow=YES;
    if (keys.count>_peak.count) _peak=[keys copy];
    if (keys.count) { _recorders[_recording].title=HaloChordName(keys); return; }
    if (!_peak.count) return;
    if (_overflow) {
        _status.stringValue=[NSString stringWithFormat:@"Use %@ key%@.",max==1?@"one":@"up to three",max==1?@"":@"s"];
        _peak=[NSSet set]; _overflow=NO; _recorders[_recording].title=@"Try again…"; return;
    }
    HaloShortcutConfig *next=[_draft copy];
    if (_recording==0) {
        next.launcher=_peak;
        if (next.launcher.count==3) {
            NSMutableSet *extra=[next.quitter mutableCopy]; [extra minusSet:next.launcher]; [extra removeObject:@(next.settingsKey)];
            NSNumber *key=extra.count==1?extra.anyObject:nil;
            if (!key) for (NSNumber *candidate in @[@(HaloControl),@(HaloOption),@(HaloShift),@(HaloCommand),@(HaloFn)]) if (![next.launcher containsObject:candidate] && candidate.integerValue!=next.settingsKey) { key=candidate; break; }
            NSMutableSet *quitter=[next.launcher mutableCopy]; if (key) [quitter addObject:key]; next.quitter=quitter;
        } else if (next.quitter.count==4) {
            NSMutableSet *extra=[next.quitter mutableCopy]; [extra minusSet:_draft.launcher]; [extra unionSet:next.launcher]; next.quitter=extra;
        }
    } else if (_recording==1) {
        if (next.launcher.count==3) { NSMutableSet *q=[next.launcher mutableCopy]; [q unionSet:_peak]; next.quitter=q; }
        else next.quitter=_peak;
    } else next.settingsKey=[_peak.anyObject integerValue];
    NSString *error=next.validationError;
    if (error) { _status.stringValue=error; _peak=[NSSet set]; _recorders[_recording].title=@"Try again…"; return; }
    _draft=next; [_runtime saveConfig:_draft]; [self stopRecording]; [self drawPage];
}
- (void)stopRecording {
    BOOL wasRecording=_recording>=0;
    _recording=-1; if (wasRecording) _runtime.recordInput=nil; _peak=nil; _cancelRecord.hidden=YES;
    [self updateControls]; [self refreshStatus];
}
- (void)cancelRecord:(__unused id)sender { [self stopRecording]; }
- (void)reset:(__unused id)sender {
    [self stopRecording];
    NSAlert *alert=[NSAlert new];
    alert.messageText=@"Reset shortcuts?";
    alert.informativeText=@"This replaces your custom shortcuts with the defaults.";
    [alert addButtonWithTitle:@"Cancel"]; [alert addButtonWithTitle:@"Reset"];
    if ([alert runModal]!=NSAlertSecondButtonReturn) return;
    _draft=[HaloShortcutConfig defaults]; [_runtime saveConfig:_draft]; [self drawPage];
}
@end
