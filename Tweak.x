/**
 * Aurora — "The Lock Screen, Reimagined" for iOS 27
 * Target: SpringBoard (works on iOS 16+ clock internals, tuned for iOS 27 / vphone VM)
 *
 * Features:
 *   1. Neon-glow clock      — applies a colored outer glow to every text layer of the
 *                             iOS 16+ lock screen clock (UIClockView) + retints the
 *                             clock via UIClockFaceConfiguration when available.
 *   2. Aurora Strip         — a floating gradient-text banner injected under the
 *                             clock (CATextLayer masked by a CAGradientLayer).
 *   3. Hide Home Grabber    — hides the bottom grabber bar on the lock screen.
 *
 * All options live in Settings > Aurora (old-school PreferenceLoader page).
 * Prefs domain: com.aurora.lockscreen
 */

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CATextLayer.h>

#define AURORA_DOMAIN          @"com.aurora.lockscreen"
#define AURORA_DARWIN_NOTE     @"com.aurora.lockscreen/prefs.changed"

#pragma mark - Private class stubs (compile-time only)

@interface UIClockView : UIView
- (void)auroraUpdateStrip; // %new — implemented below
@end

@interface SBDashBoardGrabberView : UIView
@end

@interface SBFLockScreenGrabberView : UIView
@end

@interface UIClockFaceConfiguration : NSObject
@end

#pragma mark - Prefs state

static BOOL      auroraEnabled      = YES;
static BOOL      auroraHideGrabber  = NO;
static BOOL      auroraStripEnabled = YES;
static CGFloat   auroraClockHue     = 190.0;   // 0-360
static CGFloat   auroraStripHue     = 280.0;   // 0-360
static CGFloat   auroraGlow         = 0.90;    // 0-1
static NSString *auroraStripText    = @"Aurora";

static void auroraReloadPrefs(void) {
    NSUserDefaults *d = [[NSUserDefaults alloc] initWithSuiteName:AURORA_DOMAIN];
    id en = [d objectForKey:@"enabled"];
    auroraEnabled = (en == nil) ? YES : [d boolForKey:@"enabled"];
    id hg = [d objectForKey:@"hideGrabber"];
    auroraHideGrabber = (hg == nil) ? NO : [d boolForKey:@"hideGrabber"];
    id se = [d objectForKey:@"stripEnabled"];
    auroraStripEnabled = (se == nil) ? YES : [d boolForKey:@"stripEnabled"];

    id ch = [d objectForKey:@"clockHue"];
    if ([ch respondsToSelector:@selector(doubleValue)]) auroraClockHue = (CGFloat)[ch doubleValue];
    id sh = [d objectForKey:@"stripHue"];
    if ([sh respondsToSelector:@selector(doubleValue)]) auroraStripHue = (CGFloat)[sh doubleValue];
    id gl = [d objectForKey:@"glow"];
    if ([gl respondsToSelector:@selector(doubleValue)]) auroraGlow = [gl doubleValue] / 100.0;

    NSString *t = [d stringForKey:@"stripText"];
    auroraStripText = (t.length > 0) ? t : @"Aurora";
}

static void auroraPrefsChanged(CFNotificationCenterRef center,
                               void *observer,
                               CFStringRef name,
                               const void *object,
                               CFDictionaryRef userInfo) {
    auroraReloadPrefs();
}

#pragma mark - Helpers

static UIColor *AURColor(CGFloat hue, CGFloat alpha) {
    CGFloat h = hue / 360.0;
    h = h - floor(h); // wrap into [0,1)
    return [UIColor colorWithHue:h saturation:0.88 brightness:1.0 alpha:alpha];
}

static void AURApplyGlow(CALayer *layer, UIColor *color, CGFloat glow) {
    layer.shadowColor   = color.CGColor;
    layer.shadowOpacity = (float)glow;
    layer.shadowRadius  = 14.0;
    layer.shadowOffset  = CGSizeZero;
    layer.masksToBounds = NO;
}

static void AURWalkLayers(CALayer *layer, void (^block)(CALayer *)) {
    block(layer);
    for (CALayer *sub in layer.sublayers) AURWalkLayers(sub, block);
}

/* Strip layers (created lazily inside the clock's superview) */
static UIView          *auroraStripHost    = nil;
static CAGradientLayer *auroraStripGrad    = nil;
static CATextLayer     *auroraStripTextLyr = nil;

#pragma mark - Hooks

/* ---- 1+2. The iOS 16+/27 lock screen clock ---- */
%hook UIClockView

- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig;
    if (!newWindow) {
        // Lock screen is going away; drop our injected views to avoid stale pointers.
        auroraStripHost    = nil;
        auroraStripGrad    = nil;
        auroraStripTextLyr = nil;
    }
}

- (void)layoutSubviews {
    %orig;

    // Un-clip so the glow can breathe outside the clock bounds.
    self.layer.masksToBounds = NO;

    if (auroraEnabled) {
        UIColor *glowColor = AURColor(auroraClockHue, 1.0);
        AURWalkLayers(self.layer, ^(CALayer *l) {
            // Text layers carry rendered glyph content; glow only those.
            if (l.contents != nil && l.bounds.size.height > 4.0) {
                AURApplyGlow(l, glowColor, auroraGlow);
            }
            l.masksToBounds = NO;
        });
        if (self.layer.superlayer) self.layer.superlayer.masksToBounds = NO;
    }

    [self auroraUpdateStrip];
}

%new
- (void)auroraUpdateStrip {
    UIView *parent = self.superview;
    if (!parent) return;

    BOOL showStrip = auroraEnabled && auroraStripEnabled && auroraStripText.length > 0;

    if (!auroraStripHost) {
        auroraStripHost = [[UIView alloc] initWithFrame:CGRectZero];
        auroraStripHost.userInteractionEnabled = NO;
        auroraStripHost.backgroundColor = [UIColor clearColor];

        auroraStripGrad = [CAGradientLayer layer];

        auroraStripTextLyr = [CATextLayer layer];
        auroraStripTextLyr.alignmentMode   = kCAAlignmentCenter;
        auroraStripTextLyr.contentsScale   = [UIScreen mainScreen].scale;
        auroraStripTextLyr.foregroundColor = [UIColor whiteColor].CGColor;

        [parent addSubview:auroraStripHost];
        [auroraStripHost.layer addSublayer:auroraStripGrad];
        // Gradient-text trick: the text layer masks the gradient beneath it.
        auroraStripGrad.mask = auroraStripTextLyr;
    }

    auroraStripHost.hidden = !showStrip;
    if (!showStrip) return;

    CGFloat stripH     = 24.0;
    CGFloat stripWidth = parent.bounds.size.width * 0.86;
    CGFloat stripX     = (parent.bounds.size.width - stripWidth) / 2.0;
    CGFloat stripY     = self.frame.origin.y + self.frame.size.height + 10.0;

    // If there's no room below the clock, float it above instead.
    if (stripY + stripH > parent.bounds.size.height - 30.0) {
        stripY = self.frame.origin.y - stripH - 10.0;
    }
    if (stripY < 0) stripY = 10.0;

    auroraStripHost.frame = CGRectMake(stripX, stripY, stripWidth, stripH);
    auroraStripGrad.frame = auroraStripHost.bounds;

    auroraStripTextLyr.frame  = CGRectMake(0, 0, auroraStripHost.bounds.size.width, stripH);
    auroraStripTextLyr.string = auroraStripText;
    auroraStripTextLyr.fontSize = 17.0;
    auroraStripTextLyr.font = (__bridge CFTypeRef)[UIFont systemFontOfSize:17.0
                                                                  weight:UIFontWeightSemibold];

    UIColor *c1 = AURColor(auroraClockHue, 1.0);
    UIColor *c2 = AURColor(auroraStripHue, 1.0);
    UIColor *c3 = AURColor(auroraClockHue + 50.0, 1.0);
    auroraStripGrad.colors = @[(__bridge id)c1.CGColor,
                               (__bridge id)c2.CGColor,
                               (__bridge id)c3.CGColor];
    auroraStripGrad.startPoint = CGPointMake(0.0, 0.5);
    auroraStripGrad.endPoint   = CGPointMake(1.0, 0.5);
}

%end

/* ---- 3. Hide the bottom home grabber (multi-class, version-proof) ---- */
%hook SBDashBoardGrabberView
- (void)layoutSubviews {
    %orig;
    if (auroraEnabled && auroraHideGrabber) {
        self.alpha  = 0.0;
        self.hidden = YES;
    } else if (self.hidden) {
        self.hidden = NO;
        self.alpha  = 1.0;
    }
}
%end

%hook SBFLockScreenGrabberView
- (void)layoutSubviews {
    %orig;
    if (auroraEnabled && auroraHideGrabber) {
        self.alpha  = 0.0;
        self.hidden = YES;
    } else if (self.hidden) {
        self.hidden = NO;
        self.alpha  = 1.0;
    }
}
%end

/* ---- Bonus: retint the clock configuration when the API exists ---- */
%hook UIClockFaceConfiguration
- (UIColor *)color {
    UIColor *orig = %orig;
    if (!auroraEnabled) return orig;
    CGFloat alpha = 1.0;
    if (orig) {
        CGFloat r, g, b, a;
        if ([orig getRed:&r green:&g blue:&b alpha:&a]) alpha = a;
    }
    return AURColor(auroraClockHue, alpha);
}
%end

#pragma mark - Constructor

%ctor {
    auroraReloadPrefs();

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        auroraPrefsChanged,
        (CFStringRef)AURORA_DARWIN_NOTE,
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately);

    %init;
}

%dtor {
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL);
}
