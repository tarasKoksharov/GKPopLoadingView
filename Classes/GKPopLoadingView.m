//
//  GKPopLoadingView.m
//
//  Created by Georg Kitz on 17/5/14.
//  Copyright 2011 Aurora Apps. All rights reserved.
//

#import "GKPopLoadingView.h"
#import "POPBasicAnimation.h"
#import "POPSpringAnimation.h"

@interface GKPopLoadingView ()
@property (nonatomic, strong) UIWindow* overlayWindow;
@property (nonatomic, strong) UIImageView* indicatorView;
@property (nonatomic) BOOL visible;
@end

@implementation GKPopLoadingView

#pragma mark -
#pragma mark Properties

- (UIWindow*)overlayWindow
{
    if (_overlayWindow) {
        return _overlayWindow;
    }

    _overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    _overlayWindow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _overlayWindow.backgroundColor = [UIColor clearColor];

    return _overlayWindow;
}

- (UIImageView*)indicatorView
{
    if (_indicatorView) {
        return _indicatorView;
    }

    _indicatorView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bar-loading"]];
    return _indicatorView;
}

#pragma mark -
#pragma mark Private Methods

- (void)_showAnimation
{

    POPSpringAnimation* scale = [POPSpringAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scale.fromValue = [NSValue valueWithCGSize:CGSizeMake(0.f, 0.f)];
    scale.toValue = [NSValue valueWithCGSize:CGSizeMake(1.f, 1.f)];

    POPBasicAnimation* opacity = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    opacity.toValue = @(1.0);

    [self.layer pop_addAnimation:scale forKey:@"scale"];
    [self.layer pop_addAnimation:opacity forKey:@"opacity"];
}

- (void)_hideAnimation
{

    __weak typeof(self) weakSelf = self;
    void (^completionBlock)(POPAnimation*, BOOL) = ^(POPAnimation* animation, BOOL finished) {
        [weakSelf _completionBlock];
    };

    POPBasicAnimation* scale = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerScaleXY];
    scale.toValue = [NSValue valueWithCGSize:CGSizeMake(1.3, 1.3)];

    POPBasicAnimation* opacity = [POPBasicAnimation animationWithPropertyNamed:kPOPLayerOpacity];
    opacity.toValue = @(0.0);
    opacity.completionBlock = completionBlock;

    [self.layer pop_addAnimation:scale forKey:@"scale"];
    [self.layer pop_addAnimation:opacity forKey:@"opacity"];
}

- (void)_completionBlock
{
    [self.layer removeAllAnimations];

    [self removeFromSuperview];
    self.overlayWindow = nil;

    [self _activateAppWindow];
}

- (void)rotateSpinningView
{
    [UIView animateWithDuration:1.0
        delay:0
        options:UIViewAnimationOptionCurveLinear
        animations:^{
            [self.indicatorView setTransform:CGAffineTransformRotate(self.indicatorView.transform, M_PI_2)];
        }
        completion:^(BOOL finished) {
            if (finished) {
                [self rotateSpinningView];
            }
        }];
}

#pragma mark -
#pragma mark Initialization

- (instancetype)init
{
    if ((self = [super init])) {

        // Initialization code
        self.layer.opacity = 0.0f;

        self.frame = [UIScreen mainScreen].bounds;

        self.backgroundColor = [UIColor colorWithRed:0.f green:0.f blue:0.f alpha:0.75];

        CGFloat w = CGRectGetWidth(self.frame);
        CGFloat h = CGRectGetHeight(self.frame);

        self.indicatorView.layer.position = CGPointMake(w / 2, h / 2);

        [self addSubview:self.indicatorView];

        self.visible = NO;
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];

    CGFloat w = CGRectGetWidth(self.frame);
    CGFloat h = CGRectGetHeight(self.frame);

    self.indicatorView.layer.position = CGPointMake(w / 2, h / 2);
}

#pragma mark -
#pragma mark Public Methods

- (void)show:(BOOL)show withTitle:(NSString*)title;
{

    if (self.visible == show && self.visible) {
        return;
    }

    [self _positionAlert:nil];

    if (show) {

        self.layer.opacity = 0.0f;

        [self.overlayWindow addSubview:self];
        [self.overlayWindow makeKeyAndVisible];

        [self rotateSpinningView];

        [self _registerNotifications];
        [self _showAnimation];
    }
    else {

        [self _hideAnimation];
        [self _unregisterNotifications];
    }

    self.visible = show;
}

#pragma mark -
#pragma mark Rotation Methods

- (void)_positionAlert:(NSNotification*)notification
{
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGRect orientationFrame = [UIScreen mainScreen].bounds;
    CGRect statusBarFrame = [UIApplication sharedApplication].statusBarFrame;
    CGFloat posY = 0;
    CGFloat posX = 0;
    CGPoint newCenter = CGPointZero;
    CGFloat rotateAngle = 0;

    if (UIInterfaceOrientationIsLandscape(orientation)) {
        float temp = orientationFrame.size.width;
        orientationFrame.size.width = orientationFrame.size.height;
        orientationFrame.size.height = temp;

        temp = statusBarFrame.size.width;
        statusBarFrame.size.width = statusBarFrame.size.height;
        statusBarFrame.size.height = temp;
    }

    posX = floor(orientationFrame.size.width / 2);
    posY = floor(orientationFrame.size.height / 2);

    switch (orientation) {
    case UIInterfaceOrientationPortraitUpsideDown:
        rotateAngle = M_PI;
        newCenter = CGPointMake(posX, orientationFrame.size.height - posY);
        break;
    case UIInterfaceOrientationLandscapeLeft:
        rotateAngle = -M_PI / 2.0f;
        newCenter = CGPointMake(posY, posX);
        break;
    case UIInterfaceOrientationLandscapeRight:
        rotateAngle = M_PI / 2.0f;
        newCenter = CGPointMake(orientationFrame.size.height - posY, posX);
        break;
    default: // as UIInterfaceOrientationPortrait
        rotateAngle = 0.0;
        newCenter = CGPointMake(posX, posY);
        break;
    }

    self.transform = CGAffineTransformMakeRotation(rotateAngle);
    self.center = newCenter;
}

- (void)_registerNotifications
{
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(_positionAlert:) name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)_unregisterNotifications
{
    NSNotificationCenter* notificationCenter = [NSNotificationCenter defaultCenter];

    [notificationCenter removeObserver:self name:UIApplicationDidChangeStatusBarOrientationNotification object:nil];
}

- (void)_activateAppWindow
{
    [[UIApplication sharedApplication]
            .windows enumerateObjectsWithOptions:NSEnumerationReverse
                                      usingBlock:^(UIWindow* window, NSUInteger idx, BOOL* stop) {
                                          if ([window isKindOfClass:[UIWindow class]] && window.windowLevel == UIWindowLevelNormal) {
                                              [window makeKeyWindow];
                                              *stop = YES;
                                          }
                                      }];
}

@end
