#import "HRGestureMoviePlayerViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface HRGestureMoviePlayerViewController () <UIGestureRecognizerDelegate>

@property (nonatomic, strong) UIView *overlayContainer;
@property (nonatomic, strong) UIView *gestureCatcherView;

@property (nonatomic, strong) UIView *loadingContainer;
@property (nonatomic, strong) UIActivityIndicatorView *loadingSpinner;
@property (nonatomic, strong) UILabel *lblLoadingText;

// Элементы индикации перемотки
@property (nonatomic, strong) UIView *scrubbingIndicatorView;
@property (nonatomic, strong) UIImageView *scrubbingDirectionIcon;
@property (nonatomic, strong) UILabel *lblScrubbingTime;

@property (nonatomic, strong) UIView *topHUDBar;
@property (nonatomic, strong) UIButton *btnBack;
@property (nonatomic, strong) UILabel *lblCurrentTime;
@property (nonatomic, strong) UISlider *timelineSlider;
@property (nonatomic, strong) UILabel *lblRemainingTime;
@property (nonatomic, strong) UIButton *btnFullscreen;

@property (nonatomic, strong) UIView *cardPlayback;
@property (nonatomic, strong) UIButton *btnStepBack30;
@property (nonatomic, strong) UIButton *btnPreviousTrack;
@property (nonatomic, strong) UIButton *btnPlayPause;
@property (nonatomic, strong) UIButton *btnNextTrack;
@property (nonatomic, strong) UIButton *btnStepForward30;

@property (nonatomic, strong) UIView *cardAdjustments;
@property (nonatomic, strong) UIImageView *iconSunView;
@property (nonatomic, strong) UISlider *brightnessSlider;
@property (nonatomic, strong) UIImageView *iconSpeakerView;
@property (nonatomic, strong) UISlider *volumeSlider;

@property (nonatomic, strong) MPVolumeView *systemVolumeInterceptor;
@property (nonatomic, strong) NSTimer *playbackSyncTimer;
@property (nonatomic, strong) NSTimer *autoHideHUDTimer;
@property (nonatomic, assign) BOOL isHUDVisible;

// Кэш графики для снижения нагрузки на CPU
@property (nonatomic, strong) UIImage *cachedPlayImage;
@property (nonatomic, strong) UIImage *cachedPauseImage;
@property (nonatomic, assign) MPMoviePlaybackState lastRenderedPlaybackState;
@property (nonatomic, assign) BOOL wasPlayingBeforeDisappear;

// Переменные для жестов
@property (nonatomic, assign) BOOL isScrubbing;
@property (nonatomic, assign) BOOL isPanHorizontal;
@property (nonatomic, assign) BOOL isPanLeftHalf;
@property (nonatomic, assign) NSTimeInterval panInitialTime;
@property (nonatomic, assign) NSTimeInterval targetSeekTime;
@property (nonatomic, assign) CGFloat panInitialValue;

@end

@implementation HRGestureMoviePlayerViewController

- (instancetype)initWithContentURL:(NSURL *)url
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _moviePlayer = [[MPMoviePlayerController alloc] initWithContentURL:url];
        _moviePlayer.controlStyle = MPMovieControlStyleNone;
        _moviePlayer.scalingMode = MPMovieScalingModeAspectFit;
        _lastRenderedPlaybackState = MPMoviePlaybackStateStopped;
        _wasPlayingBeforeDisappear = YES;
    }
    return self;
}

- (void)dealloc
{
    [self stopTimers];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (_moviePlayer) {
        [_moviePlayer.view removeFromSuperview];
        _moviePlayer = nil;
    }
}

#pragma mark - Статус-бар и жизненный цикл

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationFade];
    
    if (self.wasPlayingBeforeDisappear) {
        [self.moviePlayer prepareToPlay];
        [self.moviePlayer play];
    }
    
    [self ensureOverlayOnTop];
    [self startSyncTimer];
    [self updatePlaybackProgress];
    [self scheduleControlsHiding];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    
    self.wasPlayingBeforeDisappear = (self.moviePlayer.playbackState == MPMoviePlaybackStatePlaying);
    [self stopTimers];
    [self.moviePlayer pause];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

#pragma mark - Жизненный цикл и Иерархия

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.isHUDVisible = YES;
    
    // Предварительное кэширование иконок кнопок
    self.cachedPlayImage = [self drawPlayIcon];
    self.cachedPauseImage = [self drawPauseIcon];
    
    self.moviePlayer.view.frame = self.view.bounds;
    self.moviePlayer.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.moviePlayer.view];
    
    self.overlayContainer = [[UIView alloc] initWithFrame:self.view.bounds];
    self.overlayContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.overlayContainer.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.overlayContainer];
    
    self.gestureCatcherView = [[UIView alloc] initWithFrame:self.overlayContainer.bounds];
    self.gestureCatcherView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.gestureCatcherView.backgroundColor = [UIColor clearColor];
    [self.overlayContainer addSubview:self.gestureCatcherView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleScreenTap:)];
    [self.gestureCatcherView addGestureRecognizer:tap];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    pan.delegate = self;
    [self.gestureCatcherView addGestureRecognizer:pan];
    
    self.loadingContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 180, 100)];
    self.loadingContainer.center = CGPointMake(self.overlayContainer.bounds.size.width / 2.0f, self.overlayContainer.bounds.size.height / 2.0f);
    self.loadingContainer.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.loadingContainer.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.75f];
    self.loadingContainer.layer.cornerRadius = 12.0f;
    self.loadingContainer.alpha = 0.0f;
    [self.overlayContainer addSubview:self.loadingContainer];
    
    self.loadingSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.loadingSpinner.center = CGPointMake(90, 40);
    self.loadingSpinner.hidesWhenStopped = YES;
    [self.loadingContainer addSubview:self.loadingSpinner];
    
    self.lblLoadingText = [[UILabel alloc] initWithFrame:CGRectMake(10, 65, 160, 25)];
    self.lblLoadingText.backgroundColor = [UIColor clearColor];
    self.lblLoadingText.textColor = [UIColor whiteColor];
    self.lblLoadingText.font = [UIFont boldSystemFontOfSize:14.0f];
    self.lblLoadingText.textAlignment = NSTextAlignmentCenter;
    self.lblLoadingText.text = @"Загрузка потока...";
    [self.loadingContainer addSubview:self.lblLoadingText];
    
    [self showLoadingIndicator];
    
    self.scrubbingIndicatorView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 160, 60)];
    self.scrubbingIndicatorView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.75f];
    self.scrubbingIndicatorView.layer.cornerRadius = 12.0f;
    self.scrubbingIndicatorView.alpha = 0.0f;
    [self.overlayContainer addSubview:self.scrubbingIndicatorView];
    
    self.scrubbingDirectionIcon = [[UIImageView alloc] initWithFrame:CGRectMake(15, 15, 30, 30)];
    self.scrubbingDirectionIcon.contentMode = UIViewContentModeCenter;
    self.scrubbingDirectionIcon.backgroundColor = [UIColor clearColor];
    [self.scrubbingIndicatorView addSubview:self.scrubbingDirectionIcon];
    
    self.lblScrubbingTime = [[UILabel alloc] initWithFrame:CGRectMake(50, 0, 95, 60)];
    self.lblScrubbingTime.backgroundColor = [UIColor clearColor];
    self.lblScrubbingTime.textColor = [UIColor whiteColor];
    self.lblScrubbingTime.font = [UIFont boldSystemFontOfSize:22.0f];
    self.lblScrubbingTime.textAlignment = NSTextAlignmentLeft;
    [self.scrubbingIndicatorView addSubview:self.lblScrubbingTime];
    
    [self buildTopBar];
    [self buildCards];
    
    self.systemVolumeInterceptor = [[MPVolumeView alloc] initWithFrame:CGRectMake(-1000, -1000, 10, 10)];
    self.systemVolumeInterceptor.clipsToBounds = YES;
    self.systemVolumeInterceptor.alpha = 0.01f;
    [self.view addSubview:self.systemVolumeInterceptor];
    [self syncVolumeSliderWithSystem];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onPlayerStateChanged:)
                                                 name:MPMoviePlayerPlaybackStateDidChangeNotification
                                               object:self.moviePlayer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onPlayerLoadStateChanged:)
                                                 name:MPMoviePlayerLoadStateDidChangeNotification
                                               object:self.moviePlayer];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onPlayerDidFinish:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification
                                               object:self.moviePlayer];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    [self layoutAllElements];
}

#pragma mark - Вспомогательные методы таймеров и оверлея

- (void)ensureOverlayOnTop
{
    if (self.overlayContainer && self.overlayContainer.superview == self.view) {
        [self.view bringSubviewToFront:self.overlayContainer];
    }
}

- (void)startSyncTimer
{
    [self.playbackSyncTimer invalidate];
    self.playbackSyncTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                              target:self
                                                            selector:@selector(updatePlaybackProgress)
                                                            userInfo:nil
                                                             repeats:YES];
}

- (void)stopTimers
{
    [self.playbackSyncTimer invalidate];
    self.playbackSyncTimer = nil;
    [self.autoHideHUDTimer invalidate];
    self.autoHideHUDTimer = nil;
}

#pragma mark - Публичное API

- (void)playNewVideoWithURL:(NSURL *)url title:(NSString *)title
{
    self.movieTitle = title;
    self.timelineSlider.value = 0.0f;
    self.lblCurrentTime.text = @"00:00";
    self.lblRemainingTime.text = @"-00:00";
    
    [self showLoadingIndicator];
    
    // Временно отключаем прослушивание финиша, чтобы команда stop не закрыла плеер
    [[NSNotificationCenter defaultCenter] removeObserver:self name:MPMoviePlayerPlaybackDidFinishNotification object:self.moviePlayer];
    
    [self.moviePlayer stop];
    [self.moviePlayer setContentURL:url];
    [self.moviePlayer play];
    
    // Включаем прослушивание обратно для новой серии
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onPlayerDidFinish:) name:MPMoviePlayerPlaybackDidFinishNotification object:self.moviePlayer];
    
    [self ensureOverlayOnTop];
    [self showHUDAnimated];
}

- (void)showLoadingIndicator
{
    [self ensureOverlayOnTop];
    self.loadingContainer.alpha = 1.0f;
    [self.loadingSpinner startAnimating];
}

- (void)hideLoadingIndicator
{
    self.loadingContainer.alpha = 0.0f;
    [self.loadingSpinner stopAnimating];
}

#pragma mark - Жесты

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([touch.view isKindOfClass:[UIControl class]]) return NO;
    if ([touch.view isDescendantOfView:self.cardPlayback]) return NO;
    if ([touch.view isDescendantOfView:self.cardAdjustments]) return NO;
    if ([touch.view isDescendantOfView:self.topHUDBar]) return NO;
    return YES;
}

- (void)handleScreenTap:(UITapGestureRecognizer *)tap
{
    [self toggleHUDVisibility];
}

- (void)handlePanGesture:(UIPanGestureRecognizer *)pan
{
    CGPoint location = [pan locationInView:self.view];
    CGPoint velocity = [pan velocityInView:self.view];
    CGPoint translation = [pan translationInView:self.view];
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        [self.autoHideHUDTimer invalidate];
        
        if (fabs(velocity.x) > fabs(velocity.y)) {
            self.isPanHorizontal = YES;
            self.isScrubbing = YES;
            self.panInitialTime = self.moviePlayer.currentPlaybackTime;
            self.targetSeekTime = self.panInitialTime;
            
            [UIView animateWithDuration:0.2 animations:^{
                self.scrubbingIndicatorView.alpha = 1.0f;
            }];
            
        } else {
            self.isPanHorizontal = NO;
            self.isPanLeftHalf = (location.x < self.view.bounds.size.width / 2.0);
            
            if (self.isPanLeftHalf) {
                self.panInitialValue = [[UIScreen mainScreen] respondsToSelector:@selector(brightness)] ? [UIScreen mainScreen].brightness : 1.0f;
            } else {
                self.panInitialValue = [MPMusicPlayerController applicationMusicPlayer].volume;
            }
        }
    }
    else if (pan.state == UIGestureRecognizerStateChanged) {
        if (self.isPanHorizontal) {
            NSTimeInterval deltaT = translation.x * 1.5;
            self.targetSeekTime = self.panInitialTime + deltaT;
            
            NSTimeInterval dur = self.moviePlayer.duration;
            if (self.targetSeekTime < 0) self.targetSeekTime = 0;
            if (!isnan(dur) && dur > 0.1 && self.targetSeekTime > dur) {
                self.targetSeekTime = dur;
            }
            
            [self updateUIWithTime:self.targetSeekTime duration:dur];
            
            if (translation.x > 0) {
                self.scrubbingDirectionIcon.image = [self drawScrubbingArrowsIsForward:YES];
            } else if (translation.x < 0) {
                self.scrubbingDirectionIcon.image = [self drawScrubbingArrowsIsForward:NO];
            }
            
            self.lblScrubbingTime.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)(self.targetSeekTime / 60), (long)((NSInteger)self.targetSeekTime % 60)];
            
        } else {
            CGFloat deltaV = -translation.y / 200.0f;
            CGFloat newValue = self.panInitialValue + deltaV;
            if (newValue < 0.0f) newValue = 0.0f;
            if (newValue > 1.0f) newValue = 1.0f;
            
            if (self.isPanLeftHalf) {
                if ([[UIScreen mainScreen] respondsToSelector:@selector(setBrightness:)]) {
                    [UIScreen mainScreen].brightness = newValue;
                }
                self.brightnessSlider.value = newValue;
            } else {
                [MPMusicPlayerController applicationMusicPlayer].volume = newValue;
                self.volumeSlider.value = newValue;
            }
        }
    }
    else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        if (self.isPanHorizontal) {
            self.moviePlayer.currentPlaybackTime = self.targetSeekTime;
            self.isScrubbing = NO;
            
            [UIView animateWithDuration:0.25 animations:^{
                self.scrubbingIndicatorView.alpha = 0.0f;
            }];
        }
        
        if (self.isHUDVisible) {
            [self scheduleControlsHiding];
        }
    }
}

#pragma mark - Вёрстка (с учетом iPhone 4S 320x480)

- (void)layoutAllElements
{
    CGFloat screenW = self.view.bounds.size.width;
    CGFloat screenH = self.view.bounds.size.height;
    BOOL isLandscape = (screenW > screenH);
    BOOL isSmallScreen = (!isLandscape && screenH <= 480.0f); // Экран iPhone 4S
    
    self.scrubbingIndicatorView.center = CGPointMake(screenW / 2.0f, screenH / 2.0f - 40.0f);
    
    self.topHUDBar.frame = CGRectMake(0, 0, screenW, 50.0f);
    self.btnBack.frame = CGRectMake(6, 5, 80, 40);
    self.btnFullscreen.frame = CGRectMake(screenW - 42, 9, 32, 32);
    
    CGFloat leftEdge = 90.0f;
    CGFloat rightEdge = screenW - 46.0f;
    CGFloat timeLblW = 44.0f;
    
    self.lblCurrentTime.frame = CGRectMake(leftEdge, 14, timeLblW, 22);
    self.lblRemainingTime.frame = CGRectMake(rightEdge - 56.0f, 14, 56.0f, 22);
    
    CGFloat sliderX = leftEdge + timeLblW + 6.0f;
    CGFloat sliderW = (rightEdge - 56.0f - 6.0f) - sliderX;
    self.timelineSlider.frame = CGRectMake(sliderX, 13, sliderW, 24);
    
    CGFloat maxCardW = 440.0f;
    CGFloat basePadX = isLandscape ? 30.0f : 12.0f;
    CGFloat cardW = screenW - (basePadX * 2.0f);
    
    if (cardW > maxCardW) {
        cardW = maxCardW;
    }
    CGFloat padX = (screenW - cardW) / 2.0f;
    
    // Компактные высоты для горизонтальной ориентации и для экрана 3.5" (4S)
    CGFloat card1H = (isLandscape || isSmallScreen) ? 68.0f : 88.0f;
    CGFloat card2H = (isLandscape || isSmallScreen) ? 68.0f : 88.0f;
    CGFloat cardGap = (isLandscape || isSmallScreen) ? 6.0f : 10.0f;
    CGFloat bottomMargin = (isLandscape || isSmallScreen) ? 8.0f : 16.0f;
    
    CGFloat totalConsoleH = card1H + card2H + cardGap + bottomMargin;
    CGFloat startY = screenH - totalConsoleH;
    
    self.cardPlayback.frame = CGRectMake(padX, startY, cardW, card1H);
    
    CGFloat midX = cardW / 2.0f;
    CGFloat midY = card1H / 2.0f;
    CGFloat playW = (isLandscape || isSmallScreen) ? 62.0f : 72.0f;
    CGFloat playH = (isLandscape || isSmallScreen) ? 46.0f : 52.0f;
    self.btnPlayPause.frame = CGRectMake(midX - (playW / 2.0f), midY - (playH / 2.0f), playW, playH);
    
    CGFloat colW = cardW / 5.0f;
    self.btnStepBack30.center = CGPointMake(colW * 0.55f, midY);
    self.btnPreviousTrack.center = CGPointMake(colW * 1.55f, midY);
    self.btnNextTrack.center = CGPointMake(colW * 3.45f, midY);
    self.btnStepForward30.center = CGPointMake(colW * 4.45f, midY);
    
    self.cardAdjustments.frame = CGRectMake(padX, startY + card1H + cardGap, cardW, card2H);
    
    CGFloat row1Y = (isLandscape || isSmallScreen) ? 8.0f : 14.0f;
    CGFloat row2Y = (isLandscape || isSmallScreen) ? 38.0f : 50.0f;
    
    self.iconSunView.frame = CGRectMake(16, row1Y, 24, 24);
    self.brightnessSlider.frame = CGRectMake(54, row1Y, cardW - 72, 24);
    
    self.iconSpeakerView.frame = CGRectMake(16, row2Y, 24, 24);
    self.volumeSlider.frame = CGRectMake(54, row2Y, cardW - 72, 24);
}

#pragma mark - Векторная Графика

- (UIImage *)drawScrubbingArrowsIsForward:(BOOL)isForward
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    if (isForward) {
        [path moveToPoint:CGPointMake(2, 6)];
        [path addLineToPoint:CGPointMake(12, 15)];
        [path addLineToPoint:CGPointMake(2, 24)];
        [path closePath];
        
        [path moveToPoint:CGPointMake(16, 6)];
        [path addLineToPoint:CGPointMake(26, 15)];
        [path addLineToPoint:CGPointMake(16, 24)];
        [path closePath];
    } else {
        [path moveToPoint:CGPointMake(14, 6)];
        [path addLineToPoint:CGPointMake(4, 15)];
        [path addLineToPoint:CGPointMake(14, 24)];
        [path closePath];
        
        [path moveToPoint:CGPointMake(28, 6)];
        [path addLineToPoint:CGPointMake(18, 15)];
        [path addLineToPoint:CGPointMake(28, 24)];
        [path closePath];
    }
    [path fill];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)drawPlayIcon
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(40, 40), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(12, 6)];
    [path addLineToPoint:CGPointMake(34, 20)];
    [path addLineToPoint:CGPointMake(12, 34)];
    [path closePath];
    [path fill];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)drawPauseIcon
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(40, 40), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    
    UIBezierPath *bar1 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(10, 8, 7, 24) cornerRadius:1.5];
    [bar1 fill];
    
    UIBezierPath *bar2 = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(23, 8, 7, 24) cornerRadius:1.5];
    [bar2 fill];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)drawBackArrowIcon
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(12, 20), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(ctx, 2.5);
    CGContextSetLineCap(ctx, kCGLineCapRound);
    CGContextSetLineJoin(ctx, kCGLineJoinRound);
    
    CGContextMoveToPoint(ctx, 10, 2);
    CGContextAddLineToPoint(ctx, 2, 10);
    CGContextAddLineToPoint(ctx, 10, 18);
    CGContextStrokePath(ctx);
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)drawFullscreenIcon
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 20), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    CGContextSetLineCap(ctx, kCGLineCapSquare);
    
    CGContextMoveToPoint(ctx, 11, 2);
    CGContextAddLineToPoint(ctx, 18, 2);
    CGContextAddLineToPoint(ctx, 18, 9);
    CGContextMoveToPoint(ctx, 18, 2);
    CGContextAddLineToPoint(ctx, 11, 9);
    
    CGContextMoveToPoint(ctx, 9, 18);
    CGContextAddLineToPoint(ctx, 2, 18);
    CGContextAddLineToPoint(ctx, 2, 11);
    CGContextMoveToPoint(ctx, 2, 18);
    CGContextAddLineToPoint(ctx, 9, 11);
    
    CGContextStrokePath(ctx);
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)drawTrackSkipIconIsForward:(BOOL)isForward
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(28, 28), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    
    if (isForward) {
        CGContextMoveToPoint(ctx, 4, 6);
        CGContextAddLineToPoint(ctx, 18, 14);
        CGContextAddLineToPoint(ctx, 4, 22);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
        CGContextFillRect(ctx, CGRectMake(20, 6, 4, 16));
    } else {
        CGContextFillRect(ctx, CGRectMake(4, 6, 4, 16));
        CGContextMoveToPoint(ctx, 24, 6);
        CGContextAddLineToPoint(ctx, 10, 14);
        CGContextAddLineToPoint(ctx, 24, 22);
        CGContextClosePath(ctx);
        CGContextFillPath(ctx);
    }
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)drawCircularStep30IconIsForward:(BOOL)isForward
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(44, 44), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    
    CGFloat startAngle = isForward ? -M_PI_2 + 0.5 : -M_PI_2 - 0.5;
    CGFloat endAngle = isForward ? (3 * M_PI_2 - 0.5) : (-5 * M_PI_2 + 0.5);
    int clockwise = isForward ? 0 : 1;
    CGContextAddArc(ctx, 22, 22, 14, startAngle, endAngle, clockwise);
    CGContextStrokePath(ctx);
    
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    UIBezierPath *arrow = [UIBezierPath bezierPath];
    if (isForward) {
        [arrow moveToPoint:CGPointMake(24, 5)];
        [arrow addLineToPoint:CGPointMake(29, 9)];
        [arrow addLineToPoint:CGPointMake(24, 13)];
    } else {
        [arrow moveToPoint:CGPointMake(20, 5)];
        [arrow addLineToPoint:CGPointMake(15, 9)];
        [arrow addLineToPoint:CGPointMake(20, 13)];
    }
    [arrow closePath];
    [arrow fill];
    
    NSString *numStr = @"30";
    UIFont *font = [UIFont boldSystemFontOfSize:11.0];
    CGSize strSize = [numStr sizeWithFont:font];
    CGRect strRect = CGRectMake((44 - strSize.width) / 2.0, (44 - strSize.height) / 2.0 + 0.5, strSize.width, strSize.height);
    [[UIColor whiteColor] set];
    [numStr drawInRect:strRect withFont:font];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)drawSunIcon
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(24, 24), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(ctx, 1.8);
    
    CGContextStrokeEllipseInRect(ctx, CGRectMake(7, 7, 10, 10));
    
    for (int i = 0; i < 8; i++) {
        CGFloat angle = i * M_PI / 4.0;
        CGFloat x1 = 12 + 6.5 * cos(angle);
        CGFloat y1 = 12 + 6.5 * sin(angle);
        CGFloat x2 = 12 + 9.5 * cos(angle);
        CGFloat y2 = 12 + 9.5 * sin(angle);
        CGContextMoveToPoint(ctx, x1, y1);
        CGContextAddLineToPoint(ctx, x2, y2);
    }
    CGContextStrokePath(ctx);
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)drawSpeakerIcon
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(24, 24), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(ctx, 1.8);
    
    UIBezierPath *speaker = [UIBezierPath bezierPath];
    [speaker moveToPoint:CGPointMake(4, 9)];
    [speaker addLineToPoint:CGPointMake(8, 9)];
    [speaker addLineToPoint:CGPointMake(13, 5)];
    [speaker addLineToPoint:CGPointMake(13, 19)];
    [speaker addLineToPoint:CGPointMake(8, 15)];
    [speaker addLineToPoint:CGPointMake(4, 15)];
    [speaker closePath];
    [speaker fill];
    
    CGContextAddArc(ctx, 13, 12, 5, -M_PI / 3.0, M_PI / 3.0, 0);
    CGContextStrokePath(ctx);
    CGContextAddArc(ctx, 13, 12, 8, -M_PI / 3.0, M_PI / 3.0, 0);
    CGContextStrokePath(ctx);
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)customTrackImageWithColor:(UIColor *)color
{
    CGRect rect = CGRectMake(0, 0, 10, 4);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, color.CGColor);
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:2.0];
    [path fill];
    UIImage *img = [UIGraphicsGetImageFromCurrentImageContext() resizableImageWithCapInsets:UIEdgeInsetsMake(0, 3, 0, 3)];
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)customThumbImage
{
    CGRect rect = CGRectMake(0, 0, 16, 16);
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 2.0, [UIColor colorWithWhite:0 alpha:0.5].CGColor);
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextFillEllipseInRect(ctx, CGRectInset(rect, 1, 1));
    
    CGContextSetStrokeColorWithColor(ctx, [UIColor colorWithWhite:0.65 alpha:1.0].CGColor);
    CGContextSetLineWidth(ctx, 0.5); // <-- Добавлен ctx
    CGContextStrokeEllipseInRect(ctx, CGRectInset(rect, 1, 1));
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}
#pragma mark - Сборка HUD

- (void)buildTopBar
{
    self.topHUDBar = [[UIView alloc] initWithFrame:CGRectZero];
    self.topHUDBar.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.05 alpha:0.92];
    [self.overlayContainer addSubview:self.topHUDBar];
    
    self.btnBack = [UIButton buttonWithType:UIButtonTypeCustom];
    [self.btnBack setImage:[self drawBackArrowIcon] forState:UIControlStateNormal];
    [self.btnBack setTitle:@" Назад" forState:UIControlStateNormal];
    [self.btnBack setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.btnBack.titleLabel.font = [UIFont systemFontOfSize:16.0];
    [self.btnBack addTarget:self action:@selector(onCloseButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.topHUDBar addSubview:self.btnBack];
    
    self.btnFullscreen = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnFullscreen.backgroundColor = [UIColor colorWithWhite:0.12 alpha:0.8];
    self.btnFullscreen.layer.cornerRadius = 6.0;
    self.btnFullscreen.layer.borderWidth = 1.0;
    self.btnFullscreen.layer.borderColor = [UIColor colorWithWhite:0.25 alpha:0.7].CGColor;
    [self.btnFullscreen setImage:[self drawFullscreenIcon] forState:UIControlStateNormal];
    [self.btnFullscreen addTarget:self action:@selector(onToggleFullscreenTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.topHUDBar addSubview:self.btnFullscreen];
    
    self.lblCurrentTime = [[UILabel alloc] init];
    self.lblCurrentTime.backgroundColor = [UIColor clearColor];
    self.lblCurrentTime.textColor = [UIColor colorWithWhite:0.88 alpha:1.0];
    self.lblCurrentTime.font = [UIFont systemFontOfSize:13.0];
    self.lblCurrentTime.textAlignment = NSTextAlignmentRight;
    self.lblCurrentTime.text = @"00:00";
    [self.topHUDBar addSubview:self.lblCurrentTime];
    
    self.lblRemainingTime = [[UILabel alloc] init];
    self.lblRemainingTime.backgroundColor = [UIColor clearColor];
    self.lblRemainingTime.textColor = [UIColor colorWithWhite:0.88 alpha:1.0];
    self.lblRemainingTime.font = [UIFont systemFontOfSize:13.0];
    self.lblRemainingTime.textAlignment = NSTextAlignmentLeft;
    self.lblRemainingTime.text = @"-00:00";
    [self.topHUDBar addSubview:self.lblRemainingTime];
    
    self.timelineSlider = [[UISlider alloc] init];
    [self.timelineSlider setMinimumTrackImage:[self customTrackImageWithColor:[UIColor colorWithRed:0.90 green:0.10 blue:0.14 alpha:1.0]] forState:UIControlStateNormal];
    [self.timelineSlider setMaximumTrackImage:[self customTrackImageWithColor:[UIColor colorWithRed:0.16 green:0.18 blue:0.22 alpha:1.0]] forState:UIControlStateNormal];
    [self.timelineSlider setThumbImage:[self customThumbImage] forState:UIControlStateNormal];
    [self.timelineSlider addTarget:self action:@selector(onSliderTouchDown:) forControlEvents:UIControlEventTouchDown];
    [self.timelineSlider addTarget:self action:@selector(onSliderValueChanged:) forControlEvents:UIControlEventValueChanged];
    [self.timelineSlider addTarget:self action:@selector(onSliderTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.topHUDBar addSubview:self.timelineSlider];
}

- (void)buildCards
{
    UIColor *cardBg = [UIColor colorWithRed:0.06 green:0.07 blue:0.09 alpha:0.95];
    CGColorRef cardBorder = [UIColor colorWithRed:0.14 green:0.16 blue:0.20 alpha:0.8].CGColor;
    
    self.cardPlayback = [[UIView alloc] init];
    self.cardPlayback.backgroundColor = cardBg;
    self.cardPlayback.layer.cornerRadius = 10.0f;
    self.cardPlayback.layer.borderWidth = 1.0f;
    self.cardPlayback.layer.borderColor = cardBorder;
    [self.overlayContainer addSubview:self.cardPlayback];
    
    self.btnPlayPause = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnPlayPause.backgroundColor = [UIColor colorWithRed:0.86 green:0.08 blue:0.12 alpha:1.0];
    self.btnPlayPause.layer.cornerRadius = 12.0f;
    [self.btnPlayPause setImage:self.cachedPlayImage forState:UIControlStateNormal];
    [self.btnPlayPause addTarget:self action:@selector(onPlayPauseTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.cardPlayback addSubview:self.btnPlayPause];
    
    self.btnPreviousTrack = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnPreviousTrack.frame = CGRectMake(0, 0, 44, 44);
    [self.btnPreviousTrack setImage:[self drawTrackSkipIconIsForward:NO] forState:UIControlStateNormal];
    [self.btnPreviousTrack addTarget:self action:@selector(onPrevTrackTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.cardPlayback addSubview:self.btnPreviousTrack];
    
    self.btnNextTrack = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnNextTrack.frame = CGRectMake(0, 0, 44, 44);
    [self.btnNextTrack setImage:[self drawTrackSkipIconIsForward:YES] forState:UIControlStateNormal];
    [self.btnNextTrack addTarget:self action:@selector(onNextTrackTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.cardPlayback addSubview:self.btnNextTrack];
    
    self.btnStepBack30 = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnStepBack30.frame = CGRectMake(0, 0, 46, 46);
    [self.btnStepBack30 setImage:[self drawCircularStep30IconIsForward:NO] forState:UIControlStateNormal];
    [self.btnStepBack30 addTarget:self action:@selector(onStepBack30Tapped) forControlEvents:UIControlEventTouchUpInside];
    [self.cardPlayback addSubview:self.btnStepBack30];
    
    self.btnStepForward30 = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnStepForward30.frame = CGRectMake(0, 0, 46, 46);
    [self.btnStepForward30 setImage:[self drawCircularStep30IconIsForward:YES] forState:UIControlStateNormal];
    [self.btnStepForward30 addTarget:self action:@selector(onStepForward30Tapped) forControlEvents:UIControlEventTouchUpInside];
    [self.cardPlayback addSubview:self.btnStepForward30];
    
    self.cardAdjustments = [[UIView alloc] init];
    self.cardAdjustments.backgroundColor = cardBg;
    self.cardAdjustments.layer.cornerRadius = 10.0f;
    self.cardAdjustments.layer.borderWidth = 1.0f;
    self.cardAdjustments.layer.borderColor = cardBorder;
    [self.overlayContainer addSubview:self.cardAdjustments];
    
    self.iconSunView = [[UIImageView alloc] initWithImage:[self drawSunIcon]];
    [self.cardAdjustments addSubview:self.iconSunView];
    
    self.brightnessSlider = [[UISlider alloc] init];
    [self.brightnessSlider setMinimumTrackImage:[self customTrackImageWithColor:[UIColor colorWithRed:0.90 green:0.10 blue:0.14 alpha:1.0]] forState:UIControlStateNormal];
    [self.brightnessSlider setMaximumTrackImage:[self customTrackImageWithColor:[UIColor colorWithRed:0.16 green:0.18 blue:0.22 alpha:1.0]] forState:UIControlStateNormal];
    [self.brightnessSlider setThumbImage:[self customThumbImage] forState:UIControlStateNormal];
    self.brightnessSlider.value = [[UIScreen mainScreen] respondsToSelector:@selector(brightness)] ? [UIScreen mainScreen].brightness : 1.0f;
    [self.brightnessSlider addTarget:self action:@selector(onBrightnessChanged:) forControlEvents:UIControlEventValueChanged];
    [self.cardAdjustments addSubview:self.brightnessSlider];
    
    self.iconSpeakerView = [[UIImageView alloc] initWithImage:[self drawSpeakerIcon]];
    [self.cardAdjustments addSubview:self.iconSpeakerView];
    
    self.volumeSlider = [[UISlider alloc] init];
    [self.volumeSlider setMinimumTrackImage:[self customTrackImageWithColor:[UIColor colorWithRed:0.90 green:0.10 blue:0.14 alpha:1.0]] forState:UIControlStateNormal];
    [self.volumeSlider setMaximumTrackImage:[self customTrackImageWithColor:[UIColor colorWithRed:0.16 green:0.18 blue:0.22 alpha:1.0]] forState:UIControlStateNormal];
    [self.volumeSlider setThumbImage:[self customThumbImage] forState:UIControlStateNormal];
    [self.volumeSlider addTarget:self action:@selector(onVolumeChanged:) forControlEvents:UIControlEventValueChanged];
    [self.cardAdjustments addSubview:self.volumeSlider];
}

#pragma mark - Закрытие

- (void)onCloseButtonTapped
{
    [self stopTimers];
    [self.moviePlayer stop];
    [[UIApplication sharedApplication] setStatusBarHidden:NO withAnimation:UIStatusBarAnimationFade];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Управление воспроизведением

- (void)onPlayPauseTapped
{
    if (self.moviePlayer.playbackState == MPMoviePlaybackStatePlaying) {
        [self.moviePlayer pause];
        [self.btnPlayPause setImage:self.cachedPlayImage forState:UIControlStateNormal];
        self.lastRenderedPlaybackState = MPMoviePlaybackStatePaused;
        [self.autoHideHUDTimer invalidate];
    } else {
        [self.moviePlayer play];
        [self.btnPlayPause setImage:self.cachedPauseImage forState:UIControlStateNormal];
        self.lastRenderedPlaybackState = MPMoviePlaybackStatePlaying;
        [self scheduleControlsHiding];
    }
}

- (void)onStepBack30Tapped
{
    NSTimeInterval t = self.moviePlayer.currentPlaybackTime - 30.0;
    if (t < 0) t = 0;
    self.moviePlayer.currentPlaybackTime = t;
    [self updatePlaybackProgress];
    [self scheduleControlsHiding];
}

- (void)onStepForward30Tapped
{
    NSTimeInterval dur = self.moviePlayer.duration;
    NSTimeInterval t = self.moviePlayer.currentPlaybackTime + 30.0;
    if (!isnan(dur) && dur > 0.1 && t > dur) {
        t = dur - 1.0;
    }
    self.moviePlayer.currentPlaybackTime = t;
    [self updatePlaybackProgress];
    [self scheduleControlsHiding];
}

- (void)onPrevTrackTapped
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(moviePlayerDidRequestPreviousTrack:)]) {
        [self.delegate moviePlayerDidRequestPreviousTrack:self];
    } else {
        self.moviePlayer.currentPlaybackTime = 0.0;
        [self updatePlaybackProgress];
        [self scheduleControlsHiding];
    }
}

- (void)onNextTrackTapped
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(moviePlayerDidRequestNextTrack:)]) {
        [self.delegate moviePlayerDidRequestNextTrack:self];
    } else {
        NSTimeInterval dur = self.moviePlayer.duration;
        if (!isnan(dur) && dur > 10.0) {
            self.moviePlayer.currentPlaybackTime = dur - 5.0;
        }
        [self updatePlaybackProgress];
        [self scheduleControlsHiding];
    }
}

- (void)onToggleFullscreenTapped
{
    if (self.moviePlayer.scalingMode == MPMovieScalingModeAspectFit) {
        self.moviePlayer.scalingMode = MPMovieScalingModeAspectFill;
    } else {
        self.moviePlayer.scalingMode = MPMovieScalingModeAspectFit;
    }
    [self scheduleControlsHiding];
}

#pragma mark - Таймлайн

- (void)onSliderTouchDown:(UISlider *)slider
{
    self.isScrubbing = YES;
    [self.autoHideHUDTimer invalidate];
}

- (void)onSliderValueChanged:(UISlider *)slider
{
    NSTimeInterval dur = self.moviePlayer.duration;
    if (!isnan(dur) && dur > 0.1) {
        NSTimeInterval cur = slider.value * dur;
        [self updateUIWithTime:cur duration:dur];
    }
}

- (void)onSliderTouchUp:(UISlider *)slider
{
    NSTimeInterval dur = self.moviePlayer.duration;
    if (!isnan(dur) && dur > 0.1) {
        self.moviePlayer.currentPlaybackTime = slider.value * dur;
    }
    self.isScrubbing = NO;
    [self scheduleControlsHiding];
}

- (void)updateUIWithTime:(NSTimeInterval)time duration:(NSTimeInterval)dur
{
    if (!isnan(dur) && dur > 0.1) {
        self.timelineSlider.value = (float)(time / dur);
        NSTimeInterval rem = dur - time;
        if (rem < 0) rem = 0;
        
        self.lblCurrentTime.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)(time / 60), (long)((NSInteger)time % 60)];
        self.lblRemainingTime.text = [NSString stringWithFormat:@"-%02ld:%02ld", (long)(rem / 60), (long)((NSInteger)rem % 60)];
    }
}

- (void)updatePlaybackProgress
{
    if (self.isScrubbing) return;
    
    NSTimeInterval dur = self.moviePlayer.duration;
    NSTimeInterval cur = self.moviePlayer.currentPlaybackTime;
    
    if (!isnan(dur) && !isnan(cur) && dur > 0.1) {
        [self updateUIWithTime:cur duration:dur];
    }
    
    MPMoviePlaybackState currentState = self.moviePlayer.playbackState;
    if (currentState != self.lastRenderedPlaybackState) {
        self.lastRenderedPlaybackState = currentState;
        if (currentState == MPMoviePlaybackStatePlaying) {
            [self.btnPlayPause setImage:self.cachedPauseImage forState:UIControlStateNormal];
            // Убрана ошибочная остановка анимации загрузки здесь!
            // Скрытием индикатора теперь безопасно управляет onPlayerLoadStateChanged.
        } else {
            [self.btnPlayPause setImage:self.cachedPlayImage forState:UIControlStateNormal];
        }
    }
}

- (void)onPlayerStateChanged:(NSNotification *)note
{
    [self ensureOverlayOnTop];
    [self updatePlaybackProgress];
}

- (void)onPlayerLoadStateChanged:(NSNotification *)note
{
    [self ensureOverlayOnTop];
    MPMovieLoadState state = self.moviePlayer.loadState;
    if (state & (MPMovieLoadStatePlayable | MPMovieLoadStatePlaythroughOK)) {
        [self hideLoadingIndicator];
    } else if (state & MPMovieLoadStateStalled) {
        [self showLoadingIndicator];
    }
}

- (void)onPlayerDidFinish:(NSNotification *)note
{
    [self hideLoadingIndicator];
    
    NSDictionary *userInfo = [note userInfo];
    NSNumber *reason = [userInfo objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    NSInteger finishReason = reason ? [reason integerValue] : -1;
    
    if (finishReason == MPMovieFinishReasonPlaybackError) {
        NSError *error = [userInfo objectForKey:@"error"];
        NSLog(@"[HRGesturePlayer] Ошибка воспроизведения: %@", error);
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка воспроизведения"
                                                        message:@"Не удалось воспроизвести видеофайл. Возможно, файл повреждён или не поддерживается."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
        return;
    }
    
    // Естественное окончание видео (досмотрели до конца)
    if (finishReason == MPMovieFinishReasonPlaybackEnded) {
        BOOL autoPlayEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"HR_AUTOPLAY_NEXT_EPISODE"];
        
        if (autoPlayEnabled && self.delegate && [self.delegate respondsToSelector:@selector(moviePlayerDidRequestNextTrack:)]) {
            // Запрашиваем следующую серию через делегат
            [self.delegate moviePlayerDidRequestNextTrack:self];
        } else {
            // Если автовоспроизведение выключено или следующей серии нет — закрываем плеер
            [self onCloseButtonTapped];
        }
    }
}

- (void)syncVolumeSliderWithSystem
{
    self.volumeSlider.value = [MPMusicPlayerController applicationMusicPlayer].volume;
}

- (void)onVolumeChanged:(UISlider *)slider
{
    [MPMusicPlayerController applicationMusicPlayer].volume = slider.value;
    [self scheduleControlsHiding];
}

#pragma mark - Видимость HUD

- (void)toggleHUDVisibility
{
    if (self.isHUDVisible) {
        [self hideHUDAnimated];
    } else {
        [self showHUDAnimated];
    }
}

- (void)showHUDAnimated
{
    self.isHUDVisible = YES;
    [self.autoHideHUDTimer invalidate];
    
    [self ensureOverlayOnTop];
    
    [UIView animateWithDuration:0.25 animations:^{
        self.topHUDBar.alpha = 1.0f;
        self.cardPlayback.alpha = 1.0f;
        self.cardAdjustments.alpha = 1.0f;
    }];
    
    if (self.moviePlayer.playbackState == MPMoviePlaybackStatePlaying) {
        [self scheduleControlsHiding];
    }
}

- (void)hideHUDAnimated
{
    if (self.isScrubbing) return;
    self.isHUDVisible = NO;
    [self.autoHideHUDTimer invalidate];
    
    [UIView animateWithDuration:0.25 animations:^{
        self.topHUDBar.alpha = 0.0f;
        self.cardPlayback.alpha = 0.0f;
        self.cardAdjustments.alpha = 0.0f;
    }];
}

- (void)scheduleControlsHiding
{
    [self.autoHideHUDTimer invalidate];
    self.autoHideHUDTimer = [NSTimer scheduledTimerWithTimeInterval:4.0
                                                             target:self
                                                           selector:@selector(hideHUDAnimated)
                                                           userInfo:nil
                                                            repeats:NO];
}

@end