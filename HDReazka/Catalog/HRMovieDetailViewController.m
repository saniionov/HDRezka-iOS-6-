#import "HRMovieDetailViewController.h"
#import "HRStreamResolver.h"
#import "HRMovie.h"
#import "HRImageCache.h"
#import "HRDatabase.h"
#import "HRDownloadManager.h"
#import "HRTheme.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Кастомное чёрно-красное всплывающее меню

@protocol HRDarkActionSheetDelegate <NSObject>
- (void)darkActionSheet:(id)sheet didSelectIndex:(NSInteger)index withTag:(NSInteger)tag;
@end

@interface HRDarkActionSheet : UIView <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UIView *dimmerView;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, assign) NSInteger actionTag;
@property (nonatomic, weak) id<HRDarkActionSheetDelegate> delegate;
@end

@implementation HRDarkActionSheet

- (instancetype)initWithTitle:(NSString *)title items:(NSArray *)items delegate:(id<HRDarkActionSheetDelegate>)delegate tag:(NSInteger)tag {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.items = items;
        self.delegate = delegate;
        self.actionTag = tag;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        self.dimmerView = [[UIView alloc] init];
        self.dimmerView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
        self.dimmerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.dimmerView.alpha = 0.0;
        [self addSubview:self.dimmerView];
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
        [self.dimmerView addGestureRecognizer:tap];
        
        self.containerView = [[UIView alloc] init];
        self.containerView.backgroundColor = [UIColor colorWithRed:0.11 green:0.11 blue:0.11 alpha:1.0];
        self.containerView.layer.cornerRadius = 8.0;
        self.containerView.layer.borderColor = [UIColor colorWithRed:0.70 green:0.12 blue:0.12 alpha:1.0].CGColor;
        self.containerView.layer.borderWidth = 1.5;
        self.containerView.clipsToBounds = YES;
        self.containerView.alpha = 0.0;
        self.containerView.transform = CGAffineTransformMakeScale(1.1, 1.1);
        [self addSubview:self.containerView];
        
        CGFloat w = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 320.0f : 280.0f;
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, w, 44)];
        titleLabel.backgroundColor = [UIColor colorWithRed:0.06 green:0.06 blue:0.06 alpha:1.0];
        titleLabel.textColor = [UIColor colorWithWhite:0.95 alpha:1.0];
        titleLabel.font = [UIFont boldSystemFontOfSize:16.0];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.text = title;
        [self.containerView addSubview:titleLabel];
        
        UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(0, 43, w, 1)];
        separator.backgroundColor = [UIColor colorWithRed:0.70 green:0.12 blue:0.12 alpha:1.0];
        [self.containerView addSubview:separator];
        
        self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
        self.tableView.backgroundColor = [UIColor clearColor];
        self.tableView.separatorColor = [UIColor colorWithWhite:0.20 alpha:1.0];
        self.tableView.dataSource = self;
        self.tableView.delegate = self;
        [self.containerView addSubview:self.tableView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.dimmerView.frame = self.bounds;
    
    CGFloat w = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 320.0f : 280.0f;
    CGFloat maxH = self.bounds.size.height - 80;
    CGFloat tableH = self.items.count * 44.0;
    if (tableH > maxH - 44) tableH = maxH - 44;
    
    CGFloat totalH = tableH + 44;
    
    self.containerView.frame = CGRectMake((self.bounds.size.width - w)/2.0f,
                                          (self.bounds.size.height - totalH)/2.0f,
                                          w, totalH);
    self.tableView.frame = CGRectMake(0, 44, w, tableH);
}

- (void)showInView:(UIView *)view {
    self.frame = view.bounds;
    [view addSubview:self];
    [self setNeedsLayout];
    
    [UIView animateWithDuration:0.2 animations:^{
        self.dimmerView.alpha = 1.0;
        self.containerView.alpha = 1.0;
        self.containerView.transform = CGAffineTransformIdentity;
    }];
}

- (void)dismiss {
    [UIView animateWithDuration:0.2 animations:^{
        self.dimmerView.alpha = 0.0;
        self.containerView.alpha = 0.0;
        self.containerView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [self removeFromSuperview];
    }];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"DarkMenuCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.textColor = [UIColor whiteColor];
        cell.textLabel.font = [UIFont systemFontOfSize:15.0];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        
        UIView *selBg = [[UIView alloc] init];
        selBg.backgroundColor = [UIColor colorWithRed:0.70 green:0.12 blue:0.12 alpha:1.0];
        cell.selectedBackgroundView = selBg;
    }
    cell.textLabel.text = self.items[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (self.delegate && [self.delegate respondsToSelector:@selector(darkActionSheet:didSelectIndex:withTag:)]) {
        [self.delegate darkActionSheet:self didSelectIndex:indexPath.row withTag:self.actionTag];
    }
    [self dismiss];
}
@end


#pragma mark - Кастомный видеоплеер (Графическая яркость слева / Перемотка 20с)

@interface HRGestureMoviePlayerViewController ()
@property (nonatomic, strong) UIView *brightnessDimmerView;

@property (nonatomic, strong) UIView *brightnessHintContainer;
@property (nonatomic, strong) UIView *brightnessTrackView;
@property (nonatomic, strong) UIView *brightnessFillView;

@property (nonatomic, strong) UILabel *osdLabel;
@property (nonatomic, assign) CGFloat startBrightness;
@property (nonatomic, assign) NSTimeInterval startPlaybackTime;
@property (nonatomic, assign) NSInteger lastAppliedStepCount;
@property (nonatomic, assign) NSInteger panDirection;
@end

@implementation HRGestureMoviePlayerViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.brightnessDimmerView = [[UIView alloc] initWithFrame:self.view.bounds];
    self.brightnessDimmerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.brightnessDimmerView.backgroundColor = [UIColor blackColor];
    self.brightnessDimmerView.alpha = 0.0f;
    self.brightnessDimmerView.userInteractionEnabled = NO;
    [self.view addSubview:self.brightnessDimmerView];
    
    self.osdLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 220, 54)];
    self.osdLabel.center = CGPointMake(self.view.bounds.size.width / 2.0f, self.view.bounds.size.height / 2.0f);
    self.osdLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.osdLabel.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.78f];
    self.osdLabel.textColor = [UIColor whiteColor];
    self.osdLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    self.osdLabel.textAlignment = NSTextAlignmentCenter;
    self.osdLabel.layer.cornerRadius = 10.0f;
    self.osdLabel.layer.masksToBounds = YES;
    self.osdLabel.alpha = 0.0f;
    self.osdLabel.userInteractionEnabled = NO;
    [self.view addSubview:self.osdLabel];
    
    self.brightnessHintContainer = [[UIView alloc] initWithFrame:CGRectMake(20, 0, 60, 200)];
    self.brightnessHintContainer.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin;
    self.brightnessHintContainer.backgroundColor = [UIColor clearColor];
    self.brightnessHintContainer.layer.cornerRadius = 10.0;
    self.brightnessHintContainer.alpha = 0.0f;
    self.brightnessHintContainer.userInteractionEnabled = NO;
    
    UILabel *sunLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 15, 60, 40)];
    sunLabel.backgroundColor = [UIColor clearColor];
    sunLabel.textColor = [UIColor whiteColor];
    sunLabel.font = [UIFont systemFontOfSize:38.0];
    sunLabel.textAlignment = NSTextAlignmentCenter;
    sunLabel.text = @"☀";
    [self.brightnessHintContainer addSubview:sunLabel];
    
    self.brightnessTrackView = [[UIView alloc] initWithFrame:CGRectMake(25, 70, 10, 110)];
    self.brightnessTrackView.backgroundColor = [UIColor clearColor];
    self.brightnessTrackView.layer.cornerRadius = 5.0;
    self.brightnessTrackView.clipsToBounds = YES;
    [self.brightnessHintContainer addSubview:self.brightnessTrackView];
    
    self.brightnessFillView = [[UIView alloc] initWithFrame:CGRectMake(0, 110, 10, 0)];
    self.brightnessFillView.backgroundColor = [UIColor whiteColor];
    [self.brightnessTrackView addSubview:self.brightnessFillView];
    
    [self.view addSubview:self.brightnessHintContainer];
    self.brightnessHintContainer.center = CGPointMake(50, self.view.bounds.size.height / 2.0f);
    
    if ([[UIScreen mainScreen] respondsToSelector:@selector(brightness)]) {
        [self updateBrightnessUI:[UIScreen mainScreen].brightness];
    }
    
    UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleScreenPan:)];
    panGesture.delegate = self;
    panGesture.maximumNumberOfTouches = 1;
    [self.view addGestureRecognizer:panGesture];
    
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleScreenTap:)];
    singleTap.delegate = self;
    singleTap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:singleTap];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playbackStateChanged:)
                                                 name:MPMoviePlayerPlaybackStateDidChangeNotification
                                               object:self.moviePlayer];
}

- (void)handleScreenTap:(UITapGestureRecognizer *)tap
{
    [self showBrightnessHint];
}

- (void)playbackStateChanged:(NSNotification *)note
{
    [self showBrightnessHint];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        return YES;
    }
    
    CGPoint pt = [touch locationInView:self.view];
    CGFloat h = self.view.bounds.size.height;
    if (pt.y < h * 0.25f || pt.y > h * 0.75f) {
        return NO;
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (void)updateBrightnessUI:(CGFloat)brightness
{
    CGFloat trackH = self.brightnessTrackView.bounds.size.height;
    CGFloat fillH = trackH * brightness;
    self.brightnessFillView.frame = CGRectMake(0, trackH - fillH, self.brightnessTrackView.bounds.size.width, fillH);
}

- (void)showBrightnessHint
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideBrightnessHint) object:nil];
    [UIView animateWithDuration:0.2 animations:^{
        self.brightnessHintContainer.alpha = 1.0f;
    }];
    
    if (self.moviePlayer.playbackState == MPMoviePlaybackStatePlaying) {
        [self performSelector:@selector(hideBrightnessHint) withObject:nil afterDelay:3.5];
    }
}

- (void)hideBrightnessHint
{
    [UIView animateWithDuration:0.4 animations:^{
        self.brightnessHintContainer.alpha = 0.0f;
    }];
}

- (void)showOSDText:(NSString *)text
{
    self.osdLabel.text = text;
    self.osdLabel.center = CGPointMake(self.view.bounds.size.width / 2.0f, self.view.bounds.size.height / 2.0f);
    [UIView animateWithDuration:0.12 animations:^{
        self.osdLabel.alpha = 1.0f;
    }];
}

- (void)hideOSDAnimated
{
    [UIView animateWithDuration:0.35 delay:0.45 options:0 animations:^{
        self.osdLabel.alpha = 0.0f;
    } completion:nil];
}

- (void)handleScreenPan:(UIPanGestureRecognizer *)pan
{
    CGSize screenSize = self.view.bounds.size;
    CGFloat screenW = MAX(screenSize.width, 1.0f);
    CGFloat screenH = MAX(screenSize.height, 1.0f);
    
    if (pan.state == UIGestureRecognizerStateBegan) {
        self.panDirection = 0;
        self.lastAppliedStepCount = 0;
        
        if ([[UIScreen mainScreen] respondsToSelector:@selector(brightness)]) {
            self.startBrightness = [UIScreen mainScreen].brightness;
        } else {
            self.startBrightness = 1.0f - (self.brightnessDimmerView.alpha / 0.75f);
        }
        
        self.startPlaybackTime = self.moviePlayer.currentPlaybackTime;
        if (isnan(self.startPlaybackTime) || self.startPlaybackTime < 0) {
            self.startPlaybackTime = 0;
        }
    }
    else if (pan.state == UIGestureRecognizerStateChanged) {
        CGPoint translation = [pan translationInView:self.view];
        
        if (self.panDirection == 0) {
            if (fabsf(translation.x) > 10.0f || fabsf(translation.y) > 10.0f) {
                self.panDirection = (fabsf(translation.x) > fabsf(translation.y)) ? 1 : 2;
            } else {
                return;
            }
        }
        
        if (self.panDirection == 1) {
            CGFloat stepWidth = screenW / 5.5f;
            if (stepWidth < 40.0f) stepWidth = 40.0f;
            
            NSInteger steps = (NSInteger)(translation.x / stepWidth);
            if (steps == 0 && fabsf(translation.x) > 20.0f) {
                steps = (translation.x > 0) ? 1 : -1;
            }
            
            NSTimeInterval deltaSeconds = steps * 20.0;
            NSTimeInterval duration = self.moviePlayer.duration;
            NSTimeInterval targetTime = self.startPlaybackTime + deltaSeconds;
            if (targetTime < 0) targetTime = 0;
            if (duration > 0 && targetTime > duration) targetTime = duration - 1.0;
            
            NSString *sign = (deltaSeconds >= 0) ? @"+" : @"";
            NSInteger mins = ((NSInteger)targetTime) / 60;
            NSInteger secs = ((NSInteger)targetTime) % 60;
            [self showOSDText:[NSString stringWithFormat:@"⏩ %@%ld сек (%02ld:%02ld)", sign, (long)deltaSeconds, (long)mins, (long)secs]];
            
            if (steps != self.lastAppliedStepCount) {
                self.lastAppliedStepCount = steps;
                self.moviePlayer.currentPlaybackTime = targetTime;
            }
        }
        else if (self.panDirection == 2) {
            CGPoint touchLocation = [pan locationInView:self.view];
            
            if (touchLocation.x < (screenW / 2.0f)) {
                CGFloat effectiveHeight = screenH * 0.35f;
                CGFloat deltaRatio = -translation.y / effectiveHeight;
                CGFloat newBrightness = self.startBrightness + deltaRatio;
                
                if (newBrightness > 1.0f) newBrightness = 1.0f;
                if (newBrightness < 0.05f) newBrightness = 0.05f;
                
                if ([[UIScreen mainScreen] respondsToSelector:@selector(setBrightness:)]) {
                    [UIScreen mainScreen].brightness = newBrightness;
                }
                
                self.brightnessDimmerView.alpha = (1.0f - newBrightness) * 0.70f;
                
                [self updateBrightnessUI:newBrightness];
                [self showBrightnessHint];
            }
        }
    }
    else if (pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled) {
        if (self.panDirection == 1) {
            [self hideOSDAnimated];
        } else if (self.panDirection == 2) {
            if (self.moviePlayer.playbackState == MPMoviePlaybackStatePlaying) {
                [self performSelector:@selector(hideBrightnessHint) withObject:nil afterDelay:3.5];
            }
        }
        self.panDirection = 0;
    }
}

@end


#pragma mark - Карточка фильма (HRMovieDetailViewController)

typedef NS_ENUM(NSInteger, HRActionSheetTag) {
    HRActionSheetTagTranslator = 100,
    HRActionSheetTagSeason = 101,
    HRActionSheetTagEpisode = 102,
    HRActionSheetTagQuality = 103,
    HRActionSheetTagExport = 104
};

@interface HRMovieDetailViewController () <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate, HRDarkActionSheetDelegate, UIDocumentInteractionControllerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIImageView *posterImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *metaLabel;
@property (nonatomic, strong) UITextView *descriptionTextView;

@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UIDocumentInteractionController *m3uDocumentInteractionController;
@property (nonatomic, strong) NSMutableArray *translators;
@property (nonatomic, strong) NSMutableArray *seasonsData;

@property (nonatomic, assign) NSInteger selectedTranslatorId;
@property (nonatomic, assign) NSInteger selectedSeason;
@property (nonatomic, assign) NSInteger selectedEpisode;
@property (nonatomic, copy) NSString *selectedQuality;

@property (nonatomic, strong) NSDictionary *currentStreams;
@property (nonatomic, copy) NSString *currentSubtitles;
@property (nonatomic, assign) BOOL isSeriesMovie;
@property (nonatomic, assign) NSUInteger streamRequestGeneration;
@property (nonatomic, assign) NSUInteger detailRequestGeneration;

// Объявления методов, чтобы компилятор не выдавал ошибки видимости
- (void)playCurrentVideoInPlayer;
- (void)downloadCurrentVideo;
- (void)downloadEntireSeason;
- (void)copyCurrentVideoM3U;
- (void)copyEntireSeasonM3U;
- (void)shareCurrentVideoM3U;
- (void)shareEntireSeasonM3U;
- (void)shareM3UContent:(NSString *)content suggestedName:(NSString *)name;
- (void)showExportMenu;
- (void)normalizeSeasonAndEpisodeSelection;
- (void)requestVideoStreams;

@end

@implementation HRMovieDetailViewController

- (id)initWithMovie:(HRMovie *)movie
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _movie = movie;
        _isSeriesMovie = movie.isSeries;
        _translators = [[NSMutableArray alloc] init];
        _seasonsData = [[NSMutableArray alloc] init];
        _selectedQuality = [[NSUserDefaults standardUserDefaults] stringForKey:@"HR_DEFAULT_QUALITY"] ?: @"720p";
        
        if (movie.rating && [movie.rating rangeOfString:@"|"].location != NSNotFound) {
            NSArray *parts = [movie.rating componentsSeparatedByString:@"|"];
            if (parts.count >= 2) {
                _selectedSeason = [[parts objectAtIndex:0] integerValue];
                _selectedEpisode = [[parts objectAtIndex:1] integerValue];
            }
            if (parts.count >= 3) {
                _selectedTranslatorId = [[parts objectAtIndex:2] integerValue];
            }
        } else {
            _selectedSeason = 1;
            _selectedEpisode = 1;
            _selectedTranslatorId = 0;
        }
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = self.movie.title ?: @"Детали";
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    
    self.navigationItem.leftBarButtonItem = [HRTheme createGlossyBackButtonWithTitle:@"Назад"
                                                                              target:self
                                                                              action:@selector(backButtonTapped:)];
    
    UIButton *refreshButton = [UIButton buttonWithType:UIButtonTypeCustom];
    refreshButton.frame = CGRectMake(0.0f, 0.0f, 34.0f, 30.0f);
    refreshButton.backgroundColor = [UIColor colorWithRed:0.10f green:0.10f blue:0.10f alpha:1.0f];
    refreshButton.layer.cornerRadius = 5.0f;
    refreshButton.layer.borderWidth = 1.0f;
    refreshButton.layer.borderColor = [UIColor colorWithRed:0.72f green:0.08f blue:0.12f alpha:1.0f].CGColor;
    refreshButton.titleLabel.font = [UIFont boldSystemFontOfSize:23.0f];
    [refreshButton setTitle:@"↻" forState:UIControlStateNormal];
    [refreshButton setTitleColor:[UIColor colorWithRed:0.95f green:0.18f blue:0.22f alpha:1.0f] forState:UIControlStateNormal];
    [refreshButton addTarget:self action:@selector(refreshCardTapped:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:refreshButton];
    
    [self setupHeaderAndTableView];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.spinner.center = self.view.center;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    
    [self loadMoviePageDetails];
    [self saveCurrentHistory];
}

- (void)backButtonTapped:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)refreshCardTapped:(id)sender
{
    /* Инвалидируем ожидающий запрос потоков и повторно загружаем данные карточки. */
    self.streamRequestGeneration++;
    self.currentStreams = nil;
    self.currentSubtitles = nil;
    [self.tableView reloadData];
    [self loadMoviePageDetails];
}

- (NSString *)movieInfoForDisplay
{
    NSString *info = self.movie.info;
    if (![info isKindOfClass:[NSString class]] || [info length] == 0) {
        return @"HDRezka";
    }
    
    /* В старой схеме истории к info мог добавляться служебный маркер [S:x E:y].
     Он нужен для восстановления позиции, но не должен отображаться в карточке. */
    NSRange markerRange = [info rangeOfString:@"[S:"];
    if (markerRange.location != NSNotFound) {
        NSRange endRange = [info rangeOfString:@"]" options:0
                                         range:NSMakeRange(markerRange.location, [info length] - markerRange.location)];
        if (endRange.location != NSNotFound) {
            info = [info stringByReplacingCharactersInRange:NSMakeRange(markerRange.location, endRange.location - markerRange.location + 1)
                                                 withString:@""];
        }
    }
    
    info = [info stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return ([info length] > 0) ? info : @"HDRezka";
}

- (void)saveCurrentHistory
{
    NSString *sStr = [NSString stringWithFormat:@"%ld", (long)self.selectedSeason];
    NSString *eStr = [NSString stringWithFormat:@"%ld", (long)self.selectedEpisode];
    NSString *tStr = [NSString stringWithFormat:@"%ld", (long)self.selectedTranslatorId];
    [[HRDatabase sharedDatabase] savePlaybackHistoryForMovie:self.movie season:sStr episode:eStr translatorId:tStr];
}

- (void)setupHeaderAndTableView
{
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.rowHeight = isPad ? 52.0f : 44.0f;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.20f alpha:1.0f];
    
    UIView *bgView = [[UIView alloc] initWithFrame:self.tableView.bounds];
    bgView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    self.tableView.backgroundView = bgView;
    
    CGFloat headerH = isPad ? 330.0f : 220.0f;
    CGFloat posterW = isPad ? 180.0f : 110.0f;
    CGFloat posterH = isPad ? 260.0f : 160.0f;
    CGFloat pad = isPad ? 24.0f : 12.0f;
    
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, headerH)];
    headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    headerView.backgroundColor = [UIColor clearColor];
    
    self.posterImageView = [[UIImageView alloc] initWithFrame:CGRectMake(pad, pad, posterW, posterH)];
    self.posterImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.posterImageView.clipsToBounds = YES;
    self.posterImageView.backgroundColor = [UIColor colorWithWhite:0.15f alpha:1.0f];
    self.posterImageView.layer.cornerRadius = isPad ? 6.0f : 3.0f;
    [headerView addSubview:self.posterImageView];
    
    if (self.movie.posterURLString && [self.movie.posterURLString length] > 0) {
        [[HRImageCache sharedCache] loadImageForURLString:self.movie.posterURLString completion:^(UIImage *image) {
            if (image) {
                self.posterImageView.image = image;
            }
        }];
    }
    
    CGFloat textLeft = pad + posterW + (isPad ? 20.0f : 10.0f);
    CGFloat textWidth = self.view.bounds.size.width - textLeft - pad;
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(textLeft, pad, textWidth, isPad ? 56.0f : 44.0f)];
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:(isPad ? 22.0f : 16.0f)];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.text = self.movie.title;
    [headerView addSubview:self.titleLabel];
    
    self.metaLabel = [[UILabel alloc] initWithFrame:CGRectMake(textLeft, pad + (isPad ? 60.0f : 46.0f), textWidth, isPad ? 42.0f : 34.0f)];
    self.metaLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.metaLabel.font = [UIFont systemFontOfSize:(isPad ? 15.0f : 12.0f)];
    self.metaLabel.textColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:1.0];
    self.metaLabel.backgroundColor = [UIColor clearColor];
    self.metaLabel.numberOfLines = 2;
    self.metaLabel.text = [self movieInfoForDisplay];
    [headerView addSubview:self.metaLabel];
    
    CGFloat descTop = pad + (isPad ? 106.0f : 82.0f);
    CGFloat descH = isPad ? 190.0f : 80.0f;
    self.descriptionTextView = [[UITextView alloc] initWithFrame:CGRectMake(textLeft, descTop, textWidth, descH)];
    self.descriptionTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.descriptionTextView.backgroundColor = [UIColor clearColor];
    self.descriptionTextView.textColor = [UIColor colorWithWhite:0.82f alpha:1.0f];
    self.descriptionTextView.font = [UIFont systemFontOfSize:(isPad ? 15.0f : 12.0f)];
    self.descriptionTextView.editable = NO;
    self.descriptionTextView.text = @"Загрузка описания...";
    [headerView addSubview:self.descriptionTextView];
    
    UIButton *favBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    favBtn.frame = CGRectMake(pad, pad + posterH + 8.0f, posterW, isPad ? 36.0f : 30.0f);
    favBtn.backgroundColor = [UIColor colorWithRed:0.20 green:0.20 blue:0.20 alpha:1.0];
    favBtn.layer.cornerRadius = 5.0f;
    favBtn.titleLabel.font = [UIFont boldSystemFontOfSize:(isPad ? 14.0f : 12.0f)];
    [favBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    BOOL isFav = [[HRDatabase sharedDatabase] isFavorite:self.movie.movieId];
    [favBtn setTitle:(isFav ? @"★ В избранном" : @"☆ В избранное") forState:UIControlStateNormal];
    [favBtn addTarget:self action:@selector(toggleFavorite:) forControlEvents:UIControlEventTouchUpInside];
    [headerView addSubview:favBtn];
    
    self.tableView.tableHeaderView = headerView;
    [self.view addSubview:self.tableView];
}

- (void)toggleFavorite:(UIButton *)sender
{
    BOOL isFav = [[HRDatabase sharedDatabase] isFavorite:self.movie.movieId];
    if (isFav) {
        [[HRDatabase sharedDatabase] removeFavoriteWithMovieId:self.movie.movieId];
        [sender setTitle:@"☆ В избранное" forState:UIControlStateNormal];
    } else {
        NSString *sStr = [NSString stringWithFormat:@"%ld", (long)self.selectedSeason];
        NSString *eStr = [NSString stringWithFormat:@"%ld", (long)self.selectedEpisode];
        NSString *tStr = [NSString stringWithFormat:@"%ld", (long)self.selectedTranslatorId];
        [[HRDatabase sharedDatabase] addFavorite:self.movie season:sStr episode:eStr translatorId:tStr];
        [sender setTitle:@"★ В избранном" forState:UIControlStateNormal];
    }
}

#pragma mark - API: Загрузка страницы и видеопотоков

- (void)loadMoviePageDetails
{
    [self.spinner startAnimating];
    self.detailRequestGeneration++;
    NSUInteger detailGeneration = self.detailRequestGeneration;
    
    [HRStreamResolver fetchMoviePageDetails:self.movie
                                 completion:^(NSString *descriptionText,
                                              BOOL isSeries,
                                              NSArray *translators,
                                              NSArray *seasonsData,
                                              NSInteger defaultTranslatorId,
                                              NSDictionary *initialStreams,
                                              NSError *error) {
                                     if (detailGeneration != self.detailRequestGeneration) return;
                                     [self.spinner stopAnimating];
                                     
                                     if (error) {
                                         [self showSimpleAlertTitle:@"Ошибка" message:error.localizedDescription];
                                         return;
                                     }
                                     
                                     self.isSeriesMovie = isSeries;
                                     self.descriptionTextView.text = descriptionText;
                                     
                                     [self.translators removeAllObjects];
                                     if (translators) {
                                         [self.translators addObjectsFromArray:translators];
                                     }
                                     
                                     [self.seasonsData removeAllObjects];
                                     if (seasonsData) {
                                         [self.seasonsData addObjectsFromArray:seasonsData];
                                     }
                                     
                                     /*
                                      История и избранное могут содержать ID озвучки,
                                      которой больше нет среди доступных для этой карточки.
                                      В таком случае выбираем озвучку сайта, а если её нет
                                      в списке — первую реально доступную озвучку.
                                      */
                                     BOOL selectedTranslatorExists = NO;
                                     BOOL defaultTranslatorExists = NO;
                                     NSInteger firstTranslatorId = 0;
                                     for (NSDictionary *translator in self.translators) {
                                         NSInteger translatorId = [[translator objectForKey:@"id"] integerValue];
                                         if (firstTranslatorId == 0) firstTranslatorId = translatorId;
                                         if (translatorId == self.selectedTranslatorId) selectedTranslatorExists = YES;
                                         if (translatorId == defaultTranslatorId) defaultTranslatorExists = YES;
                                     }
                                     
                                     if ([self.translators count] > 0 && !selectedTranslatorExists) {
                                         if (defaultTranslatorId > 0 && defaultTranslatorExists) {
                                             self.selectedTranslatorId = defaultTranslatorId;
                                         } else {
                                             self.selectedTranslatorId = firstTranslatorId;
                                         }
                                     } else if (self.selectedTranslatorId == 0) {
                                         if (defaultTranslatorId > 0 && defaultTranslatorExists) {
                                             self.selectedTranslatorId = defaultTranslatorId;
                                         } else if (firstTranslatorId > 0) {
                                             self.selectedTranslatorId = firstTranslatorId;
                                         }
                                     }
                                     
                                     /*
                                      Список сезонов из HTML относится к озвучке по умолчанию.
                                      Если восстанавливаемая озвучка другая, сбрасываем этот список:
                                      requestVideoStreams запросит get_episodes для выбранной озвучки.
                                      */
                                     if (self.selectedTranslatorId != defaultTranslatorId) {
                                         [self.seasonsData removeAllObjects];
                                         self.selectedSeason = 0;
                                         self.selectedEpisode = 0;
                                     }
                                     
                                     /* Проверяем восстановленные сезон и серию по актуальным данным. */
                                     [self normalizeSeasonAndEpisodeSelection];
                                     
                                     /*
                                      Не используем initialStreams как окончательный поток: HTML может
                                      содержать поток для озвучки или серии по умолчанию на сайте.
                                      Запрашиваем поток для состояния, восстановленного из истории.
                                      */
                                     self.currentStreams = nil;
                                     self.currentSubtitles = nil;
                                     
                                     [self.tableView reloadData];
                                     [self saveCurrentHistory];
                                     [self requestVideoStreams];
                                 }];
}

- (void)normalizeSeasonAndEpisodeSelection
{
    if (!self.isSeriesMovie || [self.seasonsData count] == 0) {
        self.selectedSeason = 0;
        self.selectedEpisode = 0;
        return;
    }
    
    NSDictionary *selectedSeasonData = nil;
    for (NSDictionary *seasonData in self.seasonsData) {
        if ([[seasonData objectForKey:@"id"] integerValue] == self.selectedSeason) {
            selectedSeasonData = seasonData;
            break;
        }
    }
    
    if (!selectedSeasonData) {
        selectedSeasonData = [self.seasonsData objectAtIndex:0];
        self.selectedSeason = [[selectedSeasonData objectForKey:@"id"] integerValue];
    }
    
    NSArray *episodes = [selectedSeasonData objectForKey:@"episodes"];
    if (![episodes isKindOfClass:[NSArray class]] || [episodes count] == 0) {
        self.selectedEpisode = 0;
        return;
    }
    
    BOOL episodeExists = NO;
    for (NSDictionary *episodeData in episodes) {
        if ([[episodeData objectForKey:@"id"] integerValue] == self.selectedEpisode) {
            episodeExists = YES;
            break;
        }
    }
    
    if (!episodeExists) {
        self.selectedEpisode = [[[episodes objectAtIndex:0] objectForKey:@"id"] integerValue];
    }
}

- (void)requestVideoStreams
{
    [self.spinner startAnimating];
    
    NSString *action = @"get_movie";
    if (self.isSeriesMovie) {
        action = ([self.seasonsData count] == 0) ? @"get_episodes" : @"get_stream";
    }
    
    /* Игнорируем ответы старых запросов после смены озвучки/сезона/серии. */
    self.streamRequestGeneration++;
    NSUInteger requestGeneration = self.streamRequestGeneration;
    
    [HRStreamResolver fetchStreamsForMovieId:self.movie.movieId
                                translatorId:self.selectedTranslatorId
                                      season:self.selectedSeason
                                     episode:self.selectedEpisode
                                    isSeries:self.isSeriesMovie
                                      action:action
                                  completion:^(NSDictionary *streams, NSString *subtitles, NSArray *updatedSeasonsData, NSError *error) {
                                      if (requestGeneration != self.streamRequestGeneration) return;
                                      [self.spinner stopAnimating];
                                      
                                      if (error) {
                                          self.currentStreams = nil;
                                          self.currentSubtitles = nil;
                                          [self.tableView reloadData];
                                          return;
                                      }
                                      
                                      if (updatedSeasonsData) {
                                          [self.seasonsData removeAllObjects];
                                          [self.seasonsData addObjectsFromArray:updatedSeasonsData];
                                          [self normalizeSeasonAndEpisodeSelection];
                                      }
                                      
                                      if ([action isEqualToString:@"get_episodes"] && [self.seasonsData count] > 0) {
                                          /* Первый ответ обновляет фактические сезоны озвучки;
                                           затем запрашиваем поток уже для допустимой серии. */
                                          self.currentStreams = nil;
                                          self.currentSubtitles = nil;
                                          [self.tableView reloadData];
                                          if (self.selectedSeason > 0 && self.selectedEpisode > 0) {
                                              [self requestVideoStreams];
                                          }
                                          return;
                                      }
                                      
                                      if (streams && [streams count] > 0) {
                                          self.currentStreams = streams;
                                          self.currentSubtitles = subtitles;
                                          [self syncSelectedQualityWithAvailableStreams];
                                      } else {
                                          self.currentStreams = nil;
                                          self.currentSubtitles = nil;
                                      }
                                      
                                      [self.tableView reloadData];
                                  }];
}

- (void)syncSelectedQualityWithAvailableStreams
{
    if (!self.currentStreams || [self.currentStreams count] == 0) return;
    if ([self.currentStreams objectForKey:self.selectedQuality]) return;
    
    self.selectedQuality = [HRStreamResolver bestQualityKeyFromStreams:self.currentStreams preferredQuality:self.selectedQuality];
}

- (NSString *)bestStreamURLForCurrentSelection
{
    if (!self.currentStreams || [self.currentStreams count] == 0) return nil;
    if (self.selectedQuality && [self.currentStreams objectForKey:self.selectedQuality]) {
        return [self.currentStreams objectForKey:self.selectedQuality];
    }
    [self syncSelectedQualityWithAvailableStreams];
    return [self.currentStreams objectForKey:self.selectedQuality];
}

- (NSString *)currentTranslatorName
{
    for (NSDictionary *t in self.translators) {
        if ([[t objectForKey:@"id"] integerValue] == self.selectedTranslatorId) {
            return [t objectForKey:@"name"];
        }
    }
    return ([self.translators count] > 0) ? [[self.translators objectAtIndex:0] objectForKey:@"name"] : @"По умолчанию";
}

- (NSArray *)episodesForSelectedSeason
{
    for (NSDictionary *s in self.seasonsData) {
        if ([[s objectForKey:@"id"] integerValue] == self.selectedSeason) {
            return [s objectForKey:@"episodes"];
        }
    }
    return @[];
}

#pragma mark - Таблица меню

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return self.isSeriesMovie ? 4 : 2;
    }
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellID = @"CompactMenuCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellID];
    }
    
    cell.backgroundColor = [UIColor colorWithRed:0.14 green:0.14 blue:0.14 alpha:1.0];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.detailTextLabel.textColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:1.0];
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    cell.detailTextLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = UITableViewCellSelectionStyleGray;
    
    if (indexPath.section == 0) {
        if (self.isSeriesMovie) {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Озвучка";
                cell.detailTextLabel.text = [self currentTranslatorName];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Сезон";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"Сезон %ld", (long)self.selectedSeason];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"Серия";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"Серия %ld", (long)self.selectedEpisode];
            } else if (indexPath.row == 3) {
                cell.textLabel.text = @"Качество";
                cell.detailTextLabel.text = self.selectedQuality ?: @"720p";
            }
        } else {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Озвучка";
                cell.detailTextLabel.text = [self currentTranslatorName];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Качество";
                cell.detailTextLabel.text = self.selectedQuality ?: @"720p";
            }
        }
    } else if (indexPath.section == 1) {
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        if (indexPath.row == 0) {
            cell.textLabel.text = ([self.currentStreams count] > 0) ? @"▶ Смотреть онлайн" : @"⏳ Загрузка потока...";
            cell.textLabel.textColor = [UIColor colorWithRed:0.20 green:0.80 blue:0.20 alpha:1.0];
        } else {
            cell.textLabel.text = @"⬇ Скачать / Плейлист M3U";
            cell.textLabel.textColor = [UIColor colorWithRed:0.90 green:0.60 blue:0.20 alpha:1.0];
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        if (self.isSeriesMovie) {
            if (indexPath.row == 0) [self showTranslatorSelector];
            else if (indexPath.row == 1) [self showSeasonSelector];
            else if (indexPath.row == 2) [self showEpisodeSelector];
            else if (indexPath.row == 3) [self showQualitySelector];
        } else {
            if (indexPath.row == 0) [self showTranslatorSelector];
            else if (indexPath.row == 1) [self showQualitySelector];
        }
    } else if (indexPath.section == 1) {
        if (indexPath.row == 0) {
            [self playCurrentVideoInPlayer];
        } else {
            [self showExportMenu];
        }
    }
}

#pragma mark - Вызов чёрных кастомных меню

- (void)showDarkSelectionSheetWithTitle:(NSString *)title items:(NSArray *)items tag:(NSInteger)tag
{
    HRDarkActionSheet *sheet = [[HRDarkActionSheet alloc] initWithTitle:title items:items delegate:self tag:tag];
    UIView *targetView = self.tabBarController.view ?: (self.navigationController.view ?: self.view);
    [sheet showInView:targetView];
}

- (void)showTranslatorSelector
{
    if ([self.translators count] == 0) return;
    NSMutableArray *names = [NSMutableArray array];
    for (NSDictionary *t in self.translators) {
        [names addObject:[t objectForKey:@"name"]];
    }
    [self showDarkSelectionSheetWithTitle:@"Озвучка" items:names tag:HRActionSheetTagTranslator];
}

- (void)showSeasonSelector
{
    if ([self.seasonsData count] == 0) return;
    NSMutableArray *names = [NSMutableArray array];
    for (NSDictionary *s in self.seasonsData) {
        [names addObject:[s objectForKey:@"title"]];
    }
    [self showDarkSelectionSheetWithTitle:@"Сезон" items:names tag:HRActionSheetTagSeason];
}

- (void)showEpisodeSelector
{
    NSArray *eps = [self episodesForSelectedSeason];
    if ([eps count] == 0) return;
    NSMutableArray *names = [NSMutableArray array];
    for (NSDictionary *ep in eps) {
        [names addObject:[ep objectForKey:@"name"]];
    }
    [self showDarkSelectionSheetWithTitle:@"Серия" items:names tag:HRActionSheetTagEpisode];
}

- (NSArray *)availableQualityKeys
{
    NSMutableArray *qualities = [NSMutableArray array];
    
    for (id key in [self.currentStreams allKeys]) {
        if (![key isKindOfClass:[NSString class]]) {
            continue;
        }
        
        NSString *quality = (NSString *)key;
        NSString *lower = [quality lowercaseString];
        
        // Не показываем ошибочное качество «1080p Ultra».
        if ([lower rangeOfString:@"1080p"].location != NSNotFound &&
            [lower rangeOfString:@"ultra"].location != NSNotFound) {
            continue;
        }
        
        [qualities addObject:quality];
    }
    
    // Сортируем один и тот же список одинаково для меню и обработки выбора.
    // Наибольшее разрешение будет первым: 1080p, 720p, 480p, 360p.
    [qualities sortUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *qualityA = (NSString *)a;
        NSString *qualityB = (NSString *)b;
        NSInteger valueA = [qualityA integerValue];
        NSInteger valueB = [qualityB integerValue];
        
        if (valueA > valueB) return NSOrderedAscending;
        if (valueA < valueB) return NSOrderedDescending;
        
        return [qualityA compare:qualityB options:NSCaseInsensitiveSearch];
    }];
    
    return qualities;
}

- (void)showQualitySelector
{
    NSArray *qualities = [self availableQualityKeys];
    if ([qualities count] == 0) return;
    
    [self showDarkSelectionSheetWithTitle:@"Качество"
                                    items:qualities
                                      tag:HRActionSheetTagQuality];
}

#pragma mark - HRDarkActionSheetDelegate (Обработка выбора)

- (void)darkActionSheet:(id)sheet didSelectIndex:(NSInteger)index withTag:(NSInteger)tag
{
    if (tag == HRActionSheetTagTranslator) {
        if (index >= 0 && index < [self.translators count]) {
            NSDictionary *t = [self.translators objectAtIndex:index];
            NSInteger newTranslatorId = [[t objectForKey:@"id"] integerValue];
            if (newTranslatorId == self.selectedTranslatorId) return;
            
            self.selectedTranslatorId = newTranslatorId;
            
            /* Сезоны/серии принадлежат конкретной озвучке. Не используем
             список и поток от предыдущего переводчика. */
            [self.seasonsData removeAllObjects];
            self.selectedSeason = 0;
            self.selectedEpisode = 0;
            self.currentStreams = nil;
            self.currentSubtitles = nil;
            
            [self saveCurrentHistory];
            [self.tableView reloadData];
            [self requestVideoStreams];
        }
    }
    else if (tag == HRActionSheetTagSeason) {
        if (index < [self.seasonsData count]) {
            NSDictionary *s = [self.seasonsData objectAtIndex:index];
            self.selectedSeason = [[s objectForKey:@"id"] integerValue];
            NSArray *eps = [s objectForKey:@"episodes"];
            if ([eps count] > 0) {
                self.selectedEpisode = [[[eps objectAtIndex:0] objectForKey:@"id"] integerValue];
            }
            [self saveCurrentHistory];
            [self.tableView reloadData];
            [self requestVideoStreams];
        }
    }
    else if (tag == HRActionSheetTagEpisode) {
        NSArray *eps = [self episodesForSelectedSeason];
        if (index < [eps count]) {
            NSDictionary *ep = [eps objectAtIndex:index];
            self.selectedEpisode = [[ep objectForKey:@"id"] integerValue];
            [self saveCurrentHistory];
            [self.tableView reloadData];
            [self requestVideoStreams];
        }
    }
    else if (tag == HRActionSheetTagQuality) {
        NSArray *qualities = [self availableQualityKeys];
        if (index >= 0 && index < [qualities count]) {
            self.selectedQuality = [qualities objectAtIndex:index];
            [self.tableView reloadData];
        }
    }
}

#pragma mark - Меню скачивания и M3U

- (void)showExportMenu
{
    UIActionSheet *sheet = nil;
    if (self.isSeriesMovie && [self.seasonsData count] > 0) {
        sheet = [[UIActionSheet alloc] initWithTitle:@"Действия с видео и плейлистами"
                                            delegate:self
                                   cancelButtonTitle:@"Отмена"
                              destructiveButtonTitle:nil
                                   otherButtonTitles:@"Скачать текущую серию",
                 @"Скачать весь сезон",
                 @"Открыть плейлист серии в…",
                 @"Открыть плейлист сезона в…", nil];
    } else {
        sheet = [[UIActionSheet alloc] initWithTitle:@"Действия с фильмом"
                                            delegate:self
                                   cancelButtonTitle:@"Отмена"
                              destructiveButtonTitle:nil
                                   otherButtonTitles:@"Скачать фильм",
                 @"Открыть плейлист в…", nil];
    }
    sheet.tag = HRActionSheetTagExport;
    
    if (self.tabBarController.tabBar) {
        [sheet showFromTabBar:self.tabBarController.tabBar];
    } else {
        [sheet showInView:self.view];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == actionSheet.cancelButtonIndex) return;
    
    if (actionSheet.tag == HRActionSheetTagExport) {
        if (self.isSeriesMovie && [self.seasonsData count] > 0) {
            switch (buttonIndex) {
                case 0: [self downloadCurrentVideo]; break;
                case 1: [self downloadEntireSeason]; break;
                case 2: [self shareCurrentVideoM3U]; break;
                case 3: [self shareEntireSeasonM3U]; break;
                default: break;
            }
        } else {
            switch (buttonIndex) {
                case 0: [self downloadCurrentVideo]; break;
                case 1: [self shareCurrentVideoM3U]; break;
                default: break;
            }
        }
    }
}

#pragma mark - Воспроизведение и Загрузка

- (void)playCurrentVideoInPlayer
{
    NSString *streamURL = [self bestStreamURLForCurrentSelection];
    if (!streamURL || [streamURL length] == 0) {
        [self requestVideoStreams];
        [self showSimpleAlertTitle:@"Подождите" message:@"Запрашиваем прямую ссылку у сервера..."];
        return;
    }
    
    streamURL = [streamURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    streamURL = [streamURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *videoURL = [NSURL URLWithString:streamURL];
    if (!videoURL) {
        [self showSimpleAlertTitle:@"Ошибка" message:@"Прямая ссылка имеет неверный формат."];
        return;
    }
    
    HRGestureMoviePlayerViewController *playerVC = [[HRGestureMoviePlayerViewController alloc] initWithContentURL:videoURL];
    [playerVC.moviePlayer prepareToPlay];
    [self presentMoviePlayerViewControllerAnimated:playerVC];
}

- (void)downloadCurrentVideo
{
    NSString *streamURL = [self bestStreamURLForCurrentSelection];
    if (!streamURL || [streamURL length] == 0) {
        [self showSimpleAlertTitle:@"Ошибка" message:@"Прямая ссылка еще не получена."];
        return;
    }
    
    NSString *taskTitle = self.movie.title ?: @"Видео";
    NSString *subTitle = self.isSeriesMovie ? [NSString stringWithFormat:@"Сезон %ld, Серия %ld (%@)", (long)self.selectedSeason, (long)self.selectedEpisode, self.selectedQuality] : [NSString stringWithFormat:@"Фильм (%@)", self.selectedQuality];
    NSString *taskId = self.isSeriesMovie ? [NSString stringWithFormat:@"%@_s%ld_e%ld", self.movie.movieId, (long)self.selectedSeason, (long)self.selectedEpisode] : [NSString stringWithFormat:@"%@_movie", self.movie.movieId];
    
    [[HRDownloadManager sharedManager] downloadMovieTitle:taskTitle
                                                 subtitle:subTitle
                                                urlString:streamURL
                                                   taskId:taskId];
    
    [self showSimpleAlertTitle:@"Загрузка началась" message:@"Значок загрузок на главной стал зелёным. Загрузка продолжится в фоне."];
}

- (void)copyCurrentVideoM3U
{
    NSString *streamURL = [self bestStreamURLForCurrentSelection];
    if (!streamURL || [streamURL length] == 0) {
        [self showSimpleAlertTitle:@"Ошибка" message:@"Прямая ссылка на видео еще не получена."];
        return;
    }
    
    NSString *title = self.isSeriesMovie ? [NSString stringWithFormat:@"%@ - S%02ldE%02ld", self.movie.title, (long)self.selectedSeason, (long)self.selectedEpisode] : self.movie.title;
    [[HRDownloadManager sharedManager] copySingleVideoToClipboardTitle:title urlString:streamURL];
    
    [self showSimpleAlertTitle:@"Скопировано" message:@"M3U-ссылка скопирована в буфер обмена."];
}

- (void)shareM3UContent:(NSString *)content suggestedName:(NSString *)name
{
    if (![content isKindOfClass:[NSString class]] || [content length] == 0) {
        [self showSimpleAlertTitle:@"Ошибка" message:@"Плейлист пустой — нечего передавать."];
        return;
    }
    
    NSString *safeName = [name stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    if ([safeName length] == 0) safeName = @"playlist";
    if (![safeName hasSuffix:@".m3u"]) safeName = [safeName stringByAppendingString:@".m3u"];
    
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:safeName];
    NSError *error = nil;
    if (![content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        [self showSimpleAlertTitle:@"Ошибка" message:@"Не удалось создать файл плейлиста."];
        return;
    }
    
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    self.m3uDocumentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    self.m3uDocumentInteractionController.delegate = self;
    
    // Показываем именно меню приложений, которые зарегистрировали поддержку открытия файлов.
    // На iPad используем небольшую центральную область-якорь, а не весь экран.
    // Это помогает избежать некорректного позиционирования popover-меню.
    CGRect bounds = self.view.bounds;
    CGRect anchorRect = CGRectMake(CGRectGetMidX(bounds),
                                   CGRectGetMidY(bounds),
                                   1.0,
                                   1.0);
    BOOL shown = [self.m3uDocumentInteractionController presentOpenInMenuFromRect:anchorRect
                                                                           inView:self.view
                                                                         animated:YES];
    if (!shown) {
        [self showSimpleAlertTitle:@"Нет подходящего приложения"
                           message:@"iOS не нашла приложение, зарегистрированное для открытия файла M3U. Проверь, поддерживает ли установленный плеер импорт M3U-файлов через меню «Открыть в…». Файл плейлиста создан во временной папке приложения."];
    }
}

- (void)shareCurrentVideoM3U
{
    NSString *streamURL = [self bestStreamURLForCurrentSelection];
    if (![streamURL length]) {
        [self showSimpleAlertTitle:@"Ошибка" message:@"Прямая ссылка на видео еще не получена."];
        return;
    }
    
    NSString *title = self.isSeriesMovie ? [NSString stringWithFormat:@"%@ - S%02ldE%02ld", self.movie.title, (long)self.selectedSeason, (long)self.selectedEpisode] : (self.movie.title ?: @"Видео");
    NSString *content = [NSString stringWithFormat:@"#EXTM3U\n#EXTINF:-1,%@\n%@\n", title, streamURL];
    [self shareM3UContent:content suggestedName:title];
}

- (void)shareEntireSeasonM3U
{
    [self.spinner startAnimating];
    NSArray *episodesList = [self episodesForSelectedSeason];
    
    [HRStreamResolver fetchSeasonEpisodeStreamsForMovieId:self.movie.movieId
                                             translatorId:self.selectedTranslatorId
                                                   season:self.selectedSeason
                                             episodesList:episodesList
                                         preferredQuality:self.selectedQuality
                                               completion:^(NSArray *resolvedEpisodes) {
                                                   [self.spinner stopAnimating];
                                                   if (![resolvedEpisodes count]) {
                                                       [self showSimpleAlertTitle:@"Ошибка" message:@"Не удалось получить ссылки на серии сезона."];
                                                       return;
                                                   }
                                                   
                                                   NSMutableString *m3u = [NSMutableString stringWithString:@"#EXTM3U\n"];
                                                   NSString *seasonTitle = [NSString stringWithFormat:@"Сезон %ld", (long)self.selectedSeason];
                                                   for (NSDictionary *ep in resolvedEpisodes) {
                                                       NSString *epName = [ep objectForKey:@"title"] ?: @"Серия";
                                                       NSString *epURL = [ep objectForKey:@"url"] ?: @"";
                                                       if ([epURL length] > 0) {
                                                           [m3u appendFormat:@"#EXTINF:-1,%@ - %@ (%@)\n%@\n", self.movie.title ?: @"Видео", seasonTitle, epName, epURL];
                                                       }
                                                   }
                                                   NSString *fileName = [NSString stringWithFormat:@"%@ - %@", self.movie.title ?: @"Видео", seasonTitle];
                                                   [self shareM3UContent:m3u suggestedName:fileName];
                                               }];
}

- (void)copyEntireSeasonM3U
{
    [self.spinner startAnimating];
    NSArray *episodesList = [self episodesForSelectedSeason];
    
    [HRStreamResolver fetchSeasonEpisodeStreamsForMovieId:self.movie.movieId
                                             translatorId:self.selectedTranslatorId
                                                   season:self.selectedSeason
                                             episodesList:episodesList
                                         preferredQuality:self.selectedQuality
                                               completion:^(NSArray *resolvedEpisodes) {
                                                   [self.spinner stopAnimating];
                                                   if (!resolvedEpisodes || [resolvedEpisodes count] == 0) {
                                                       [self showSimpleAlertTitle:@"Ошибка" message:@"Не удалось получить ссылки на серии сезона."];
                                                       return;
                                                   }
                                                   
                                                   NSString *seasonTitle = [NSString stringWithFormat:@"Сезон %ld", (long)self.selectedSeason];
                                                   [[HRDownloadManager sharedManager] copySeasonPlaylistToClipboardTitle:self.movie.title
                                                                                                             seasonTitle:seasonTitle
                                                                                                                episodes:resolvedEpisodes];
                                                   
                                                   NSString *msg = [NSString stringWithFormat:@"Плейлист сезона (%lu серий) скопирован в буфер обмена!", (unsigned long)[resolvedEpisodes count]];
                                                   [self showSimpleAlertTitle:@"M3U готов" message:msg];
                                               }];
}

- (void)downloadEntireSeason
{
    [self.spinner startAnimating];
    NSArray *episodesList = [self episodesForSelectedSeason];
    
    [HRStreamResolver fetchSeasonEpisodeStreamsForMovieId:self.movie.movieId
                                             translatorId:self.selectedTranslatorId
                                                   season:self.selectedSeason
                                             episodesList:episodesList
                                         preferredQuality:self.selectedQuality
                                               completion:^(NSArray *resolvedEpisodes) {
                                                   [self.spinner stopAnimating];
                                                   if (!resolvedEpisodes || [resolvedEpisodes count] == 0) {
                                                       [self showSimpleAlertTitle:@"Ошибка" message:@"Не удалось получить список серий сезона."];
                                                       return;
                                                   }
                                                   
                                                   for (NSDictionary *ep in resolvedEpisodes) {
                                                       NSString *epName = [ep objectForKey:@"title"];
                                                       NSString *epUrl = [ep objectForKey:@"url"];
                                                       NSNumber *epNum = [ep objectForKey:@"episode"];
                                                       
                                                       NSString *taskId = [NSString stringWithFormat:@"%@_s%ld_e%@", self.movie.movieId, (long)self.selectedSeason, epNum];
                                                       NSString *subTitle = [NSString stringWithFormat:@"Сезон %ld, %@", (long)self.selectedSeason, epName];
                                                       
                                                       [[HRDownloadManager sharedManager] downloadMovieTitle:self.movie.title
                                                                                                    subtitle:subTitle
                                                                                                   urlString:epUrl
                                                                                                      taskId:taskId];
                                                   }
                                                   
                                                   NSString *msg = [NSString stringWithFormat:@"В очередь загрузки добавлено серий: %lu", (unsigned long)[resolvedEpisodes count]];
                                                   [self showSimpleAlertTitle:@"Сезон в очереди" message:msg];
                                               }];
}

- (void)showSimpleAlertTitle:(NSString *)title message:(NSString *)msg
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title  
                                                    message:msg  
                                                   delegate:nil  
                                          cancelButtonTitle:@"OK"  
                                          otherButtonTitles:nil];  
    [alert show];  
}  

@end  
