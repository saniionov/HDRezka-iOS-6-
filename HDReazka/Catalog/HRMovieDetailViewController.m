#import "HRMovieDetailViewController.h"
#import "HRStreamResolver.h"
#import "HRMovie.h"
#import "HRImageCache.h"
#import "HRDatabase.h"
#import "HRDownloadManager.h"
#import "HRTheme.h"
#import "HRSelectionSheet.h"
#import "HRM3UExporter.h"
#import "HRGestureMoviePlayerViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import <QuartzCore/QuartzCore.h>

#pragma mark - Типизация меню и секций

typedef NS_ENUM(NSInteger, HRActionSheetTag) {
    HRActionSheetTagTranslator = 100,
    HRActionSheetTagSeason = 101,
    HRActionSheetTagEpisode = 102,
    HRActionSheetTagQuality = 103,
    HRActionSheetTagExport = 104
};

typedef NS_ENUM(NSInteger, HRDetailSectionType) {
    HRDetailSectionTranslator = 0,
    HRDetailSectionSeason,
    HRDetailSectionEpisode,
    HRDetailSectionQuality,
    HRDetailSectionPlay,
    HRDetailSectionDownload
};

#pragma mark - Кастомная шапка для выступающих кнопок (iPad hitTest Fix)

@interface HROverflowHeaderView : UIView
@end

@implementation HROverflowHeaderView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    for (UIView *subview in [self.subviews reverseObjectEnumerator]) {
        if (subview.userInteractionEnabled && !subview.hidden && subview.alpha > 0.01f) {
            CGPoint subPoint = [subview convertPoint:point fromView:self];
            if (CGRectContainsPoint(subview.bounds, subPoint)) {
                UIView *hit = [subview hitTest:subPoint withEvent:event];
                if (hit) return hit;
            }
        }
    }
    return [super hitTest:point withEvent:event];
}

@end

#pragma mark - Кастомная ячейка меню

@interface HRMenuGradientCell : UITableViewCell
@property (nonatomic, strong) UIView *customBgView;
@property (nonatomic, strong) UIView *customSelView;
@property (nonatomic, strong) CAGradientLayer *normalGlossLayer;
@property (nonatomic, strong) CAGradientLayer *selectedGlossLayer;

@property (nonatomic, strong) UILabel *customTextLabel;
@property (nonatomic, strong) UILabel *customDetailLabel;
@property (nonatomic, strong) UIImageView *arrowImageView;
@end

@implementation HRMenuGradientCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.accessoryType = UITableViewCellAccessoryNone;
        
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.backgroundView = nil;
        self.selectedBackgroundView = nil;
        
        CGFloat screenScale = [UIScreen mainScreen].scale;
        BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
        CGFloat menuFontSize = isPad ? 18.0f : 16.5f;
        
        _customBgView = [[UIView alloc] initWithFrame:self.bounds];
        _customBgView.layer.cornerRadius = 9.0f;
        _customBgView.layer.masksToBounds = YES;
        _customBgView.layer.borderWidth = 0.0f;
        _customBgView.backgroundColor = [UIColor clearColor];
        
        _normalGlossLayer = [CAGradientLayer layer];
        _normalGlossLayer.contentsScale = screenScale;
        _normalGlossLayer.locations = @[@(0.0f), @(1.0f)];
        _normalGlossLayer.colors = @[
                                     (id)[UIColor colorWithRed:0.180f green:0.180f blue:0.190f alpha:1.0f].CGColor,
                                     (id)[UIColor colorWithRed:0.150f green:0.150f blue:0.161f alpha:1.0f].CGColor
                                     ];
        [_customBgView.layer insertSublayer:_normalGlossLayer atIndex:0];
        
        _customSelView = [[UIView alloc] initWithFrame:self.bounds];
        _customSelView.layer.cornerRadius = 9.0f;
        _customSelView.layer.masksToBounds = YES;
        _customSelView.layer.borderWidth = 0.0f;
        _customSelView.backgroundColor = [UIColor clearColor];
        
        _selectedGlossLayer = [CAGradientLayer layer];
        _selectedGlossLayer.contentsScale = screenScale;
        _selectedGlossLayer.locations = @[@(0.0f), @(1.0f)];
        _selectedGlossLayer.colors = @[
                                       (id)[UIColor colorWithRed:0.110f green:0.110f blue:0.120f alpha:1.0f].CGColor,
                                       (id)[UIColor colorWithRed:0.110f green:0.110f blue:0.120f alpha:1.0f].CGColor
                                       ];
        [_customSelView.layer insertSublayer:_selectedGlossLayer atIndex:0];
        
        [self addSubview:_customBgView];
        [self addSubview:_customSelView];
        _customSelView.hidden = YES;
        
        _customTextLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _customTextLabel.backgroundColor = [UIColor clearColor];
        _customTextLabel.font = [UIFont boldSystemFontOfSize:menuFontSize];
        _customTextLabel.textColor = [UIColor colorWithWhite:0.92f alpha:1.0f];
        _customTextLabel.shadowColor = [UIColor clearColor];
        _customTextLabel.shadowOffset = CGSizeZero;
        [_customBgView addSubview:_customTextLabel];
        
        _customDetailLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _customDetailLabel.backgroundColor = [UIColor clearColor];
        _customDetailLabel.font = [UIFont boldSystemFontOfSize:menuFontSize];
        _customDetailLabel.textColor = [UIColor colorWithRed:0.95f green:0.25f blue:0.25f alpha:1.0f];
        _customDetailLabel.shadowColor = [UIColor clearColor];
        _customDetailLabel.shadowOffset = CGSizeZero;
        _customDetailLabel.textAlignment = NSTextAlignmentRight;
        [_customBgView addSubview:_customDetailLabel];
        
        _arrowImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _arrowImageView.contentMode = UIViewContentModeCenter;
        _arrowImageView.image = [self drawDisclosureIndicator];
        [_customBgView addSubview:_arrowImageView];
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    self.customSelView.hidden = !highlighted;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    self.customSelView.hidden = !selected;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    
    CGRect btnFrame;
    if (isPad) {
        CGFloat pad = 28.0f;
        CGFloat posterW = 250.0f;
        CGFloat columnGap = 20.0f;
        
        CGFloat rightX = pad + posterW + columnGap;
        CGFloat rightW = self.bounds.size.width - rightX - pad;
        btnFrame = CGRectMake(rightX, 0.0f, rightW, self.bounds.size.height);
    } else {
        CGFloat sideMargin = 10.0f;
        btnFrame = CGRectMake(sideMargin,
                              0.0f,
                              self.bounds.size.width - (sideMargin * 2.0f),
                              self.bounds.size.height);
    }
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.customBgView.frame = btnFrame;
    self.customSelView.frame = btnFrame;
    self.normalGlossLayer.frame = self.customBgView.bounds;
    self.selectedGlossLayer.frame = self.customSelView.bounds;
    [CATransaction commit];
    
    CGFloat w = btnFrame.size.width;
    CGFloat h = btnFrame.size.height;
    CGFloat innerPad = isPad ? 16.0f : 12.0f;
    
    CGFloat arrowW = isPad ? 12.0f : 10.0f;
    CGFloat arrowH = isPad ? 16.0f : 14.0f;
    CGFloat arrowX = w - innerPad - arrowW;
    self.arrowImageView.frame = CGRectMake(arrowX, floorf((h - arrowH) / 2.0f), arrowW, arrowH);
    
    CGSize titleSize = [self.customTextLabel.text sizeWithFont:self.customTextLabel.font];
    CGFloat titleW = ceilf(titleSize.width);
    self.customTextLabel.frame = CGRectMake(innerPad, 0.0f, titleW, h);
    
    CGFloat detailX = innerPad + titleW + 8.0f;
    CGFloat detailW = arrowX - 6.0f - detailX;
    if (detailW < 0.0f) detailW = 0.0f;
    self.customDetailLabel.frame = CGRectMake(detailX, 0.0f, detailW, h);
}

- (UIImage *)drawDisclosureIndicator
{
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    CGSize size = CGSizeMake(isPad ? 12.0f : 10.0f, isPad ? 16.0f : 14.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(2.0f, 2.0f)];
    [path addLineToPoint:CGPointMake(size.width - 3.0f, size.height / 2.0f)];
    [path addLineToPoint:CGPointMake(2.0f, size.height - 2.0f)];
    path.lineWidth = 2.0f;
    path.lineCapStyle = kCGLineCapRound;
    path.lineJoinStyle = kCGLineJoinRound;
    [[UIColor colorWithWhite:0.55f alpha:1.0f] setStroke];
    [path stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end

#pragma mark - Контроллер карточки фильма

@interface HRMovieDetailViewController () <UITableViewDataSource, UITableViewDelegate, HRSelectionSheetDelegate, HRGestureMoviePlayerDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIImageView *posterImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIButton *favoriteButton;

@property (nonatomic, strong) UIButton *padPlayButton;
@property (nonatomic, strong) UIButton *padDownloadButton;

@property (nonatomic, strong) UIView *descriptionBlurContainer;
@property (nonatomic, strong) UITextView *descriptionTextView;

@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) HRM3UExporter *m3uExporter;
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

- (void)playCurrentVideoInPlayer;
- (void)downloadCurrentVideo;
- (void)downloadEntireSeason;
- (void)copyCurrentVideoM3U;
- (void)copyEntireSeasonM3U;
- (void)shareCurrentVideoM3U;
- (void)shareEntireSeasonM3U;
- (void)showExportMenu;
- (void)normalizeSeasonAndEpisodeSelection;
- (void)requestVideoStreams;
- (void)updatePadPlayButtonTitle;
- (UIImage *)drawPlayIconWithColor:(UIColor *)color size:(CGSize)size;
- (UIImage *)drawDownloadIconWithColor:(UIColor *)color size:(CGSize)size;

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
        _m3uExporter = [[HRM3UExporter alloc] init];
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
            NSArray *allHist = [[HRDatabase sharedDatabase] allHistory];
            for (HRMovie *histMovie in allHist) {
                if ([histMovie.movieId isEqualToString:movie.movieId] && histMovie.rating && [histMovie.rating rangeOfString:@"|"].location != NSNotFound) {
                    NSArray *parts = [histMovie.rating componentsSeparatedByString:@"|"];
                    if (parts.count >= 2) {
                        _selectedSeason = [[parts objectAtIndex:0] integerValue];
                        _selectedEpisode = [[parts objectAtIndex:1] integerValue];
                    }
                    if (parts.count >= 3) {
                        _selectedTranslatorId = [[parts objectAtIndex:2] integerValue];
                    }
                    break;
                }
            }
            
            if (_selectedSeason <= 0) _selectedSeason = 1;
            if (_selectedEpisode <= 0) _selectedEpisode = 1;
            if (_selectedTranslatorId < 0) _selectedTranslatorId = 0;
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
    
    self.navigationItem.rightBarButtonItem = [HRTheme createGlossyBarButtonWithTitle:@"Обновить"
                                                                              target:self
                                                                              action:@selector(refreshCardTapped:)];
    
    [self setupHeaderAndTableView];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.spinner.center = self.view.center;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    
    [self loadMoviePageDetails];
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [super willAnimateRotationToInterfaceOrientation:toInterfaceOrientation duration:duration];
    [self setupHeaderAndTableView];
    [self.tableView reloadData];
}

- (void)backButtonTapped:(id)sender
{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)refreshCardTapped:(id)sender
{
    self.streamRequestGeneration++;
    self.currentStreams = nil;
    self.currentSubtitles = nil;
    [self updatePadPlayButtonTitle];
    [self.tableView reloadData];
    [self loadMoviePageDetails];
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
    CGFloat targetRowHeight = isPad ? 52.0f : 46.0f;
    
    if (!self.tableView) {
        self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
        self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.tableView.dataSource = self;
        self.tableView.delegate = self;
        self.tableView.rowHeight = targetRowHeight;
        self.tableView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
        self.tableView.separatorColor = [UIColor clearColor];
        
        UIView *bgView = [[UIView alloc] initWithFrame:self.tableView.bounds];
        bgView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
        self.tableView.backgroundView = bgView;
        [self.view addSubview:self.tableView];
    } else {
        self.tableView.rowHeight = targetRowHeight;
    }
    
    CGFloat posterW = isPad ? 250.0f : 110.0f;
    CGFloat posterH = isPad ? 365.0f : 160.0f;
    CGFloat pad = isPad ? 28.0f : 12.0f;
    CGFloat favBtnH = isPad ? 42.0f : 30.0f;
    CGFloat actionBtnH = 50.0f;
    CGFloat actionGap = 10.0f;
    
    self.posterImageView = [[UIImageView alloc] initWithFrame:CGRectMake(pad, pad, posterW, posterH)];
    self.posterImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.posterImageView.clipsToBounds = YES;
    self.posterImageView.backgroundColor = [UIColor colorWithWhite:0.15f alpha:1.0f];
    self.posterImageView.layer.cornerRadius = isPad ? 8.0f : 3.0f;
    
    if (self.movie.posterURLString && [self.movie.posterURLString length] > 0) {
        [[HRImageCache sharedCache] loadImageForURLString:self.movie.posterURLString completion:^(UIImage *image) {
            if (image) {
                self.posterImageView.image = image;
            }
        }];
    }
    
    self.favoriteButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.favoriteButton.frame = CGRectMake(pad, pad + posterH + 10.0f, posterW, favBtnH);
    self.favoriteButton.backgroundColor = [UIColor colorWithRed:0.18 green:0.18 blue:0.18 alpha:1.0];
    self.favoriteButton.layer.cornerRadius = isPad ? 8.0f : 5.0f;
    self.favoriteButton.layer.borderWidth = 0.0f;
    self.favoriteButton.titleLabel.font = [UIFont boldSystemFontOfSize:(isPad ? 15.0f : 12.0f)];
    [self updateFavoriteButtonStyle];
    [self.favoriteButton addTarget:self action:@selector(toggleFavorite:) forControlEvents:UIControlEventTouchUpInside];
    
    if (isPad) {
        CGFloat actionTopGap = 20.0f;
        CGFloat playY = pad + posterH + 10.0f + favBtnH + actionTopGap;
        self.padPlayButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.padPlayButton.frame = CGRectMake(pad, playY, posterW, actionBtnH);
        self.padPlayButton.backgroundColor = [UIColor colorWithRed:0.449f green:0.030f blue:0.047f alpha:1.0f];
        self.padPlayButton.layer.cornerRadius = 12.0f;
        self.padPlayButton.layer.masksToBounds = YES;
        self.padPlayButton.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
        [self.padPlayButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [self.padPlayButton setImage:[self drawPlayIconWithColor:[UIColor whiteColor] size:CGSizeMake(20.0f, 20.0f)] forState:UIControlStateNormal];
        self.padPlayButton.imageEdgeInsets = UIEdgeInsetsMake(0, -8, 0, 8);
        [self.padPlayButton addTarget:self action:@selector(playCurrentVideoInPlayer) forControlEvents:UIControlEventTouchUpInside];
        
        CGFloat dlY = playY + actionBtnH + actionGap;
        self.padDownloadButton = [UIButton buttonWithType:UIButtonTypeCustom];
        self.padDownloadButton.frame = CGRectMake(pad, dlY, posterW, actionBtnH);
        self.padDownloadButton.backgroundColor = [UIColor colorWithRed:0.150f green:0.150f blue:0.161f alpha:1.0f];
        self.padDownloadButton.layer.cornerRadius = 12.0f;
        self.padDownloadButton.layer.masksToBounds = YES;
        self.padDownloadButton.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
        [self.padDownloadButton setTitleColor:[UIColor colorWithWhite:0.92f alpha:1.0f] forState:UIControlStateNormal];
        [self.padDownloadButton setTitle:@"Скачать / Плейлист" forState:UIControlStateNormal];
        [self.padDownloadButton setImage:[self drawDownloadIconWithColor:[UIColor colorWithWhite:0.92f alpha:1.0f] size:CGSizeMake(20.0f, 20.0f)] forState:UIControlStateNormal];
        self.padDownloadButton.imageEdgeInsets = UIEdgeInsetsMake(0, -8, 0, 8);
        [self.padDownloadButton addTarget:self action:@selector(showExportMenu) forControlEvents:UIControlEventTouchUpInside];
        
        [self updatePadPlayButtonTitle];
    } else {
        self.padPlayButton = nil;
        self.padDownloadButton = nil;
    }
    
    CGFloat textLeft = pad + posterW + (isPad ? 20.0f : 10.0f);
    CGFloat textWidth = self.view.bounds.size.width - textLeft - pad;
    CGFloat titleH = isPad ? 68.0f : 42.0f;
    
    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(textLeft, pad, textWidth, titleH)];
    self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.titleLabel.font = [UIFont boldSystemFontOfSize:(isPad ? 25.0f : 15.0f)];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.backgroundColor = [UIColor clearColor];
    self.titleLabel.numberOfLines = 2;
    self.titleLabel.text = self.movie.title;
    
    CGFloat descY = pad + titleH + (isPad ? 10.0f : 4.0f);
    CGFloat descBottom = isPad ? (pad + posterH) : (pad + posterH + 10.0f + favBtnH);
    CGFloat descH = descBottom - descY;
    
    if (descH < 100.0f) descH = 100.0f;
    
    CGFloat headerH = descY + descH + (isPad ? 6.0f : 12.0f);
    
    HROverflowHeaderView *headerView = [[HROverflowHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, self.view.bounds.size.width, headerH)];
    headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    headerView.backgroundColor = [UIColor clearColor];
    
    [headerView addSubview:self.posterImageView];
    [headerView addSubview:self.favoriteButton];
    if (isPad) {
        [headerView addSubview:self.padPlayButton];
        [headerView addSubview:self.padDownloadButton];
    }
    [headerView addSubview:self.titleLabel];
    
    self.descriptionBlurContainer = [[UIView alloc] initWithFrame:CGRectMake(textLeft, descY, textWidth, descH)];
    self.descriptionBlurContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.descriptionBlurContainer.layer.cornerRadius = isPad ? 8.0f : 6.0f;
    self.descriptionBlurContainer.layer.masksToBounds = YES;
    self.descriptionBlurContainer.backgroundColor = [UIColor colorWithRed:0.10f green:0.10f blue:0.11f alpha:0.95f];
    
    CGFloat screenScale = [UIScreen mainScreen].scale;
    self.descriptionBlurContainer.layer.borderWidth = (screenScale >= 2.0f) ? 0.5f : 1.0f;
    self.descriptionBlurContainer.layer.borderColor = [UIColor colorWithWhite:1.0f alpha:0.10f].CGColor;
    
    CGFloat innerPadX = isPad ? 12.0f : 6.0f;
    CGFloat safeTextW = (textWidth - (innerPadX * 2.0f) > 0.0f) ? (textWidth - (innerPadX * 2.0f)) : textWidth;
    CGRect textFrame = CGRectMake(innerPadX, 0.0f, safeTextW, descH);
    
    NSString *existingDesc = self.descriptionTextView.text;
    self.descriptionTextView = [[UITextView alloc] initWithFrame:textFrame];
    self.descriptionTextView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.descriptionTextView.backgroundColor = [UIColor clearColor];
    self.descriptionTextView.textColor = [UIColor colorWithWhite:0.92f alpha:1.0f];
    self.descriptionTextView.font = [UIFont systemFontOfSize:(isPad ? 17.0f : 12.0f)];
    self.descriptionTextView.editable = NO;
    self.descriptionTextView.scrollEnabled = YES;
    self.descriptionTextView.alwaysBounceVertical = NO;
    self.descriptionTextView.alwaysBounceHorizontal = NO;
    self.descriptionTextView.showsHorizontalScrollIndicator = NO;
    self.descriptionTextView.showsVerticalScrollIndicator = YES;
    self.descriptionTextView.contentInset = UIEdgeInsetsMake(isPad ? 10.0f : 6.0f, 0.0f, isPad ? 10.0f : 6.0f, 0.0f);
    self.descriptionTextView.text = ([existingDesc length] > 0) ? existingDesc : @"Загрузка описания...";
    
    [self.descriptionBlurContainer addSubview:self.descriptionTextView];
    [headerView addSubview:self.descriptionBlurContainer];
    
    self.tableView.tableHeaderView = headerView;
}

- (void)updatePadPlayButtonTitle
{
    if (self.padPlayButton) {
        NSString *title = ([self.currentStreams count] > 0) ? @"Смотреть онлайн" : @"Загрузка потока...";
        [self.padPlayButton setTitle:title forState:UIControlStateNormal];
    }
}

- (void)updateFavoriteButtonStyle
{
    BOOL isFav = [[HRDatabase sharedDatabase] isFavorite:self.movie.movieId];
    if (isFav) {
        [self.favoriteButton setTitle:@"★ В избранном" forState:UIControlStateNormal];
        [self.favoriteButton setTitleColor:[UIColor colorWithRed:0.90 green:0.18 blue:0.18 alpha:1.0] forState:UIControlStateNormal];
    } else {
        [self.favoriteButton setTitle:@"☆ В избранное" forState:UIControlStateNormal];
        [self.favoriteButton setTitleColor:[UIColor colorWithWhite:0.75 alpha:1.0] forState:UIControlStateNormal];
    }
}

- (void)toggleFavorite:(UIButton *)sender
{
    BOOL isFav = [[HRDatabase sharedDatabase] isFavorite:self.movie.movieId];
    if (isFav) {
        [[HRDatabase sharedDatabase] removeFavoriteWithMovieId:self.movie.movieId];
    } else {
        NSString *sStr = [NSString stringWithFormat:@"%ld", (long)self.selectedSeason];
        NSString *eStr = [NSString stringWithFormat:@"%ld", (long)self.selectedEpisode];
        NSString *tStr = [NSString stringWithFormat:@"%ld", (long)self.selectedTranslatorId];
        [[HRDatabase sharedDatabase] addFavorite:self.movie season:sStr episode:eStr translatorId:tStr];
    }
    [self updateFavoriteButtonStyle];
}

#pragma mark - Значки для кнопок действий

- (UIImage *)drawPlayIconWithColor:(UIColor *)color size:(CGSize)size
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(3.0f, 2.0f)];
    [path addLineToPoint:CGPointMake(size.width - 2.0f, size.height / 2.0f)];
    [path addLineToPoint:CGPointMake(3.0f, size.height - 2.0f)];
    [path closePath];
    [color setFill];
    [path fill];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

- (UIImage *)drawDownloadIconWithColor:(UIColor *)color size:(CGSize)size
{
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    UIBezierPath *path = [UIBezierPath bezierPath];
    CGFloat midX = size.width / 2.0f;
    [path moveToPoint:CGPointMake(midX - 3.0f, 2.0f)];
    [path addLineToPoint:CGPointMake(midX + 3.0f, 2.0f)];
    [path addLineToPoint:CGPointMake(midX + 3.0f, size.height - 9.0f)];
    [path addLineToPoint:CGPointMake(midX + 7.5f, size.height - 9.0f)];
    [path addLineToPoint:CGPointMake(midX, size.height - 2.5f)];
    [path addLineToPoint:CGPointMake(midX - 7.5f, size.height - 9.0f)];
    [path addLineToPoint:CGPointMake(midX - 3.0f, size.height - 9.0f)];
    [path closePath];
    UIBezierPath *bar = [UIBezierPath bezierPathWithRect:CGRectMake(2.0f, size.height - 2.5f, size.width - 4.0f, 2.0f)];
    [path appendPath:bar];
    [color setFill];
    [path fill];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - Загрузка страницы и потоков

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
                                     self.descriptionTextView.text = ([descriptionText length] > 0) ? descriptionText : @"Описание отсутствует.";
                                     [self.descriptionTextView setContentOffset:CGPointZero animated:NO];
                                     
                                     [self.translators removeAllObjects];
                                     if (translators) {
                                         [self.translators addObjectsFromArray:translators];
                                     }
                                     
                                     [self.seasonsData removeAllObjects];
                                     if (seasonsData) {
                                         [self.seasonsData addObjectsFromArray:seasonsData];
                                     }
                                     
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
                                     
                                     if (self.selectedTranslatorId != defaultTranslatorId) {
                                         [self.seasonsData removeAllObjects];
                                     }
                                     
                                     [self normalizeSeasonAndEpisodeSelection];
                                     
                                     self.currentStreams = nil;
                                     self.currentSubtitles = nil;
                                     [self updatePadPlayButtonTitle];
                                     
                                     [self.tableView reloadData];
                                     [self saveCurrentHistory];
                                     [self requestVideoStreams];
                                 }];
}

- (void)normalizeSeasonAndEpisodeSelection
{
    if (!self.isSeriesMovie) {
        self.selectedSeason = 0;
        self.selectedEpisode = 0;
        return;
    }
    
    if ([self.seasonsData count] == 0) {
        if (self.selectedSeason <= 0) self.selectedSeason = 1;
        if (self.selectedEpisode <= 0) self.selectedEpisode = 1;
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
        if (self.selectedEpisode <= 0) self.selectedEpisode = 1;
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
                                          [self updatePadPlayButtonTitle];
                                          [self.tableView reloadData];
                                          return;
                                      }
                                      
                                      if (updatedSeasonsData) {
                                          [self.seasonsData removeAllObjects];
                                          [self.seasonsData addObjectsFromArray:updatedSeasonsData];
                                          [self normalizeSeasonAndEpisodeSelection];
                                      }
                                      
                                      if ([action isEqualToString:@"get_episodes"] && [self.seasonsData count] > 0) {
                                          self.currentStreams = nil;
                                          self.currentSubtitles = nil;
                                          [self updatePadPlayButtonTitle];
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
                                      
                                      [self updatePadPlayButtonTitle];
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

#pragma mark - Маппинг секций и таблицы

- (HRDetailSectionType)sectionTypeForIndex:(NSInteger)section
{
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    if (isPad) {
        if (self.isSeriesMovie) {
            return (HRDetailSectionType)section;
        } else {
            return (section == 0) ? HRDetailSectionTranslator : HRDetailSectionQuality;
        }
    } else {
        if (self.isSeriesMovie) {
            return (HRDetailSectionType)section;
        } else {
            if (section == 0) return HRDetailSectionTranslator;
            if (section == 1) return HRDetailSectionQuality;
            if (section == 2) return HRDetailSectionPlay;
            return HRDetailSectionDownload;
        }
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    if (isPad) {
        return self.isSeriesMovie ? 4 : 2;
    } else {
        return self.isSeriesMovie ? 6 : 4;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 0.01f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    HRDetailSectionType type = [self sectionTypeForIndex:section];
    
    if (type == HRDetailSectionTranslator || type == HRDetailSectionSeason || type == HRDetailSectionEpisode) {
        return isPad ? 6.0f : 4.0f;
    }
    if (type == HRDetailSectionQuality) {
        return isPad ? 0.01f : 10.0f;
    }
    if (type == HRDetailSectionPlay) {
        return 8.0f;
    }
    return 10.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    CGFloat h = [self tableView:tableView heightForFooterInSection:section];
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, h)];
    v.backgroundColor = [UIColor clearColor];
    return v;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [UIColor clearColor];
    cell.backgroundView = nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    HRDetailSectionType type = [self sectionTypeForIndex:indexPath.section];
    
    if (type <= HRDetailSectionQuality) {
        static NSString *MenuID = @"HRMenuGradientCellID";
        HRMenuGradientCell *cell = [tableView dequeueReusableCellWithIdentifier:MenuID];
        if (!cell) {
            cell = [[HRMenuGradientCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:MenuID];
        }
        
        switch (type) {
            case HRDetailSectionTranslator:
                cell.customTextLabel.text = @"Озвучка";
                cell.customDetailLabel.text = [self currentTranslatorName];
                break;
            case HRDetailSectionSeason:
                cell.customTextLabel.text = @"Сезон";
                cell.customDetailLabel.text = [NSString stringWithFormat:@"Сезон %ld", (long)self.selectedSeason];
                break;
            case HRDetailSectionEpisode:
                cell.customTextLabel.text = @"Серия";
                cell.customDetailLabel.text = [NSString stringWithFormat:@"Серия %ld", (long)self.selectedEpisode];
                break;
            case HRDetailSectionQuality:
                cell.customTextLabel.text = @"Качество";
                cell.customDetailLabel.text = self.selectedQuality ?: @"720p";
                break;
            default:
                break;
        }
        return cell;
    } else {
        static NSString *ButtonID = @"ButtonCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ButtonID];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ButtonID];
            cell.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
            cell.backgroundColor = [UIColor clearColor];
            cell.contentView.backgroundColor = [UIColor clearColor];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            UIView *btnView = [[UIView alloc] initWithFrame:CGRectZero];
            btnView.tag = 777;
            btnView.layer.cornerRadius = 14.0f;
            btnView.layer.masksToBounds = YES;
            
            UIImageView *iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
            iconView.tag = 778;
            iconView.contentMode = UIViewContentModeScaleAspectFit;
            [btnView addSubview:iconView];
            
            UILabel *titleLbl = [[UILabel alloc] initWithFrame:CGRectZero];
            titleLbl.tag = 779;
            titleLbl.backgroundColor = [UIColor clearColor];
            titleLbl.font = [UIFont boldSystemFontOfSize:14.0f];
            titleLbl.shadowColor = [UIColor clearColor];
            titleLbl.shadowOffset = CGSizeZero;
            [btnView addSubview:titleLbl];
            
            [cell.contentView addSubview:btnView];
        }
        
        UIView *btnView = [cell.contentView viewWithTag:777];
        UIImageView *iconView = (UIImageView *)[btnView viewWithTag:778];
        UILabel *titleLbl = (UILabel *)[btnView viewWithTag:779];
        
        CGFloat tableW = tableView.bounds.size.width;
        CGFloat cellExpectedW = tableW - 20.0f;
        CGFloat btnW = floorf(tableW * 0.70f);
        CGFloat btnH = tableView.rowHeight > 0 ? tableView.rowHeight : 44.0f;
        CGFloat btnX = floorf((cellExpectedW - btnW) / 2.0f);
        
        btnView.frame = CGRectMake(btnX, 0.0f, btnW, btnH);
        
        NSString *btnTitle = (type == HRDetailSectionPlay) ?
        (([self.currentStreams count] > 0) ? @"Смотреть онлайн" : @"Загрузка потока...") :
        @"Скачать / Плейлист M3U";
        
        CGSize titleSize = [btnTitle sizeWithFont:titleLbl.font];
        CGSize iconSize = CGSizeMake(22.0f, 22.0f);
        CGFloat spacing = 8.0f;
        CGFloat contentW = iconSize.width + spacing + ceilf(titleSize.width);
        CGFloat startX = floorf((btnW - contentW) / 2.0f);
        if (startX < 6.0f) startX = 6.0f;
        
        iconView.frame = CGRectMake(startX, floorf((btnH - iconSize.height) / 2.0f), iconSize.width, iconSize.height);
        titleLbl.frame = CGRectMake(startX + iconSize.width + spacing, 0.0f, btnW - startX - iconSize.width - spacing, btnH);
        titleLbl.text = btnTitle;
        
        if (type == HRDetailSectionPlay) {
            btnView.backgroundColor = [UIColor colorWithRed:0.449f green:0.030f blue:0.047f alpha:1.0f];
            titleLbl.textColor = [UIColor whiteColor];
            iconView.image = [self drawPlayIconWithColor:[UIColor whiteColor] size:iconSize];
        } else {
            btnView.backgroundColor = [UIColor colorWithRed:0.150f green:0.150f blue:0.161f alpha:1.0f];
            titleLbl.textColor = [UIColor colorWithWhite:0.92f alpha:1.0f];
            iconView.image = [self drawDownloadIconWithColor:[UIColor colorWithWhite:0.92f alpha:1.0f] size:iconSize];
        }
        
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    HRDetailSectionType type = [self sectionTypeForIndex:indexPath.section];
    switch (type) {
        case HRDetailSectionTranslator:
            [self showTranslatorSelector];
            break;
        case HRDetailSectionSeason:
            [self showSeasonSelector];
            break;
        case HRDetailSectionEpisode:
            [self showEpisodeSelector];
            break;
        case HRDetailSectionQuality:
            [self showQualitySelector];
            break;
        case HRDetailSectionPlay:
            [self playCurrentVideoInPlayer];
            break;
        case HRDetailSectionDownload:
            [self showExportMenu];
            break;
    }
}

#pragma mark - Вызовы списков выбора

- (void)showSelectionSheetWithTitle:(NSString *)title items:(NSArray *)items tag:(NSInteger)tag
{
    HRSelectionSheet *sheet = [[HRSelectionSheet alloc] initWithTitle:title items:items delegate:self tag:tag];
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
    [self showSelectionSheetWithTitle:@"Озвучка" items:names tag:HRActionSheetTagTranslator];
}

- (void)showSeasonSelector
{
    if ([self.seasonsData count] == 0) return;
    NSMutableArray *names = [NSMutableArray array];
    for (NSDictionary *s in self.seasonsData) {
        [names addObject:[s objectForKey:@"title"]];
    }
    [self showSelectionSheetWithTitle:@"Сезон" items:names tag:HRActionSheetTagSeason];
}

- (void)showEpisodeSelector
{
    NSArray *eps = [self episodesForSelectedSeason];
    if ([eps count] == 0) return;
    NSMutableArray *names = [NSMutableArray array];
    for (NSDictionary *ep in eps) {
        [names addObject:[ep objectForKey:@"name"]];
    }
    [self showSelectionSheetWithTitle:@"Серия" items:names tag:HRActionSheetTagEpisode];
}

- (NSArray *)availableQualityKeys
{
    NSMutableArray *qualities = [NSMutableArray array];
    for (id key in [self.currentStreams allKeys]) {
        if (![key isKindOfClass:[NSString class]]) continue;
        NSString *quality = (NSString *)key;
        NSString *lower = [quality lowercaseString];
        if ([lower rangeOfString:@"1080p"].location != NSNotFound && [lower rangeOfString:@"ultra"].location != NSNotFound) {
            continue;
        }
        [qualities addObject:quality];
    }
    
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
    [self showSelectionSheetWithTitle:@"Качество" items:qualities tag:HRActionSheetTagQuality];
}

- (void)showExportMenu
{
    NSArray *exportItems = nil;
    NSString *menuTitle = nil;
    
    if (self.isSeriesMovie && [self.seasonsData count] > 0) {
        menuTitle = @"Действия с видео и плейлистами";
        exportItems = @[
                        @"Скачать текущую серию",
                        @"Скачать весь сезон",
                        @"Открыть плейлист серии в…",
                        @"Открыть плейлист сезона в…"
                        ];
    } else {
        menuTitle = @"Действия с фильмом";
        exportItems = @[
                        @"Скачать фильм",
                        @"Открыть плейлист в…"
                        ];
    }
    [self showSelectionSheetWithTitle:menuTitle items:exportItems tag:HRActionSheetTagExport];
}

#pragma mark - HRSelectionSheetDelegate

- (void)selectionSheet:(HRSelectionSheet *)sheet didSelectIndex:(NSInteger)index withTag:(NSInteger)tag
{
    if (tag == HRActionSheetTagTranslator) {
        if (index >= 0 && index < [self.translators count]) {
            NSDictionary *t = [self.translators objectAtIndex:index];
            NSInteger newTranslatorId = [[t objectForKey:@"id"] integerValue];
            if (newTranslatorId == self.selectedTranslatorId) return;
            
            self.selectedTranslatorId = newTranslatorId;
            [self.seasonsData removeAllObjects];
            self.currentStreams = nil;
            self.currentSubtitles = nil;
            [self updatePadPlayButtonTitle];
            
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
    else if (tag == HRActionSheetTagExport) {
        if (self.isSeriesMovie && [self.seasonsData count] > 0) {
            switch (index) {
                case 0: [self downloadCurrentVideo]; break;
                case 1: [self downloadEntireSeason]; break;
                case 2: [self shareCurrentVideoM3U]; break;
                case 3: [self shareEntireSeasonM3U]; break;
                default: break;
            }
        } else {
            switch (index) {
                case 0: [self downloadCurrentVideo]; break;
                case 1: [self shareCurrentVideoM3U]; break;
                default: break;
            }
        }
    }
}

#pragma mark - Воспроизведение, Загрузка и M3U

- (void)playCurrentVideoInPlayer
{
    NSString *streamURL = [self bestStreamURLForCurrentSelection];
    if (!streamURL || [streamURL length] == 0) {
        [self requestVideoStreams];
        [self showSimpleAlertTitle:@"Подождите" message:@"Запрашиваем прямую ссылку у сервера..."];
        return;
    }
    
    [self saveCurrentHistory];
    
    // Безопасное экранирование пробелов и кириллицы для iOS 6
    NSString *cleanURL = [streamURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    cleanURL = [cleanURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *videoURL = [NSURL URLWithString:cleanURL];
    if (!videoURL) {
        [self showSimpleAlertTitle:@"Ошибка" message:@"Прямая ссылка имеет неверный формат."];
        return;
    }
    
    HRGestureMoviePlayerViewController *playerVC = [[HRGestureMoviePlayerViewController alloc] initWithContentURL:videoURL];
    playerVC.movieTitle = self.isSeriesMovie ?
    [NSString stringWithFormat:@"%@ — S%02ldE%02ld", self.movie.title, (long)self.selectedSeason, (long)self.selectedEpisode] :
    (self.movie.title ?: @"Видео");
    playerVC.delegate = self;
    
    [playerVC.moviePlayer prepareToPlay];
    [self presentViewController:playerVC animated:YES completion:nil];
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
    [HRM3UExporter copySingleVideoToClipboardTitle:title urlString:streamURL];
    
    [self showSimpleAlertTitle:@"Скопировано" message:@"M3U-ссылка скопирована в буфер обмена."];
}

- (void)shareCurrentVideoM3U
{
    NSString *streamURL = [self bestStreamURLForCurrentSelection];
    if (![streamURL length]) {
        [self showSimpleAlertTitle:@"Ошибка" message:@"Прямая ссылка на видео еще не получена."];
        return;
    }
    
    NSString *title = self.isSeriesMovie ? [NSString stringWithFormat:@"%@ - S%02ldE%02ld", self.movie.title, (long)self.selectedSeason, (long)self.selectedEpisode] : (self.movie.title ?: @"Видео");
    NSString *content = [HRM3UExporter playlistContentForSingleVideoTitle:title urlString:streamURL];
    
    UIView *targetView = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && self.padDownloadButton) ? self.padDownloadButton : self.view;
    
    __weak typeof(self) weakSelf = self;
    [self.m3uExporter presentOpenInMenuWithContent:content
                                     suggestedName:title
                                            inView:targetView
                                      errorHandler:^(NSString *errorTitle, NSString *errorMessage) {
                                          [weakSelf showSimpleAlertTitle:errorTitle message:errorMessage];
                                      }];
}

- (void)shareEntireSeasonM3U
{
    [self.spinner startAnimating];
    NSArray *episodesList = [self episodesForSelectedSeason];
    
    __weak typeof(self) weakSelf = self;
    [HRStreamResolver fetchSeasonEpisodeStreamsForMovieId:self.movie.movieId
                                             translatorId:self.selectedTranslatorId
                                                   season:self.selectedSeason
                                             episodesList:episodesList
                                         preferredQuality:self.selectedQuality
                                               completion:^(NSArray *resolvedEpisodes) {
                                                   [weakSelf.spinner stopAnimating];
                                                   if (![resolvedEpisodes count]) {
                                                       [weakSelf showSimpleAlertTitle:@"Ошибка" message:@"Не удалось получить ссылки на серии сезона."];
                                                       return;
                                                   }
                                                   
                                                   NSString *seasonTitle = [NSString stringWithFormat:@"Сезон %ld", (long)weakSelf.selectedSeason];
                                                   NSString *m3u = [HRM3UExporter playlistContentForSeasonShowTitle:weakSelf.movie.title
                                                                                                        seasonTitle:seasonTitle
                                                                                                           episodes:resolvedEpisodes];
                                                   NSString *fileName = [NSString stringWithFormat:@"%@ - %@", weakSelf.movie.title ?: @"Видео", seasonTitle];
                                                   
                                                   UIView *targetView = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && weakSelf.padDownloadButton) ? weakSelf.padDownloadButton : weakSelf.view;
                                                   [self.m3uExporter presentOpenInMenuWithContent:m3u
                                                                                    suggestedName:fileName
                                                                                           inView:targetView
                                                                                     errorHandler:^(NSString *errorTitle, NSString *errorMessage) {
                                                                                         [weakSelf showSimpleAlertTitle:errorTitle message:errorMessage];
                                                                                     }];
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
                                                   [HRM3UExporter copySeasonPlaylistToClipboardTitle:self.movie.title
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

#pragma mark - HRGestureMoviePlayerDelegate

- (void)moviePlayerDidRequestNextTrack:(HRGestureMoviePlayerViewController *)player
{
    if (!self.isSeriesMovie) return;
    [self switchToEpisodeOffset:1 inPlayer:player];
}

- (void)moviePlayerDidRequestPreviousTrack:(HRGestureMoviePlayerViewController *)player
{
    if (!self.isSeriesMovie) return;
    [self switchToEpisodeOffset:-1 inPlayer:player];
}

- (void)switchToEpisodeOffset:(NSInteger)offset inPlayer:(HRGestureMoviePlayerViewController *)player
{
    NSArray *episodes = [self episodesForSelectedSeason];
    if ([episodes count] == 0) return;
    
    NSInteger currentIndex = -1;
    for (NSInteger i = 0; i < [episodes count]; i++) {
        NSDictionary *ep = [episodes objectAtIndex:i];
        if ([[ep objectForKey:@"id"] integerValue] == self.selectedEpisode) {
            currentIndex = i;
            break;
        }
    }
    if (currentIndex == -1) return;
    
    NSInteger targetIndex = currentIndex + offset;
    if (targetIndex >= 0 && targetIndex < [episodes count]) {
        self.selectedEpisode = [[[episodes objectAtIndex:targetIndex] objectForKey:@"id"] integerValue];
        [self loadAndPlayNewEpisodeInPlayer:player];
    } else {
        NSInteger currentSeasonIndex = -1;
        for (NSInteger i = 0; i < [self.seasonsData count]; i++) {
            NSDictionary *s = [self.seasonsData objectAtIndex:i];
            if ([[s objectForKey:@"id"] integerValue] == self.selectedSeason) {
                currentSeasonIndex = i;
                break;
            }
        }
        
        if (currentSeasonIndex != -1) {
            NSInteger targetSeasonIndex = currentSeasonIndex + offset;
            if (targetSeasonIndex >= 0 && targetSeasonIndex < [self.seasonsData count]) {
                NSDictionary *targetSeason = [self.seasonsData objectAtIndex:targetSeasonIndex];
                self.selectedSeason = [[targetSeason objectForKey:@"id"] integerValue];
                NSArray *targetEpisodes = [targetSeason objectForKey:@"episodes"];
                if ([targetEpisodes count] > 0) {
                    if (offset > 0) {
                        self.selectedEpisode = [[[targetEpisodes objectAtIndex:0] objectForKey:@"id"] integerValue];
                    } else {
                        self.selectedEpisode = [[[targetEpisodes lastObject] objectForKey:@"id"] integerValue];
                    }
                    [self loadAndPlayNewEpisodeInPlayer:player];
                }
            }
        }
    }
}

- (void)loadAndPlayNewEpisodeInPlayer:(HRGestureMoviePlayerViewController *)player
{
    [self saveCurrentHistory];
    [self.tableView reloadData];
    
    [player showLoadingIndicator];
    
    __weak typeof(self) weakSelf = self;
    [HRStreamResolver fetchStreamsForMovieId:self.movie.movieId
                                translatorId:self.selectedTranslatorId
                                      season:self.selectedSeason
                                     episode:self.selectedEpisode
                                    isSeries:self.isSeriesMovie
                                      action:@"get_stream"
                                  completion:^(NSDictionary *streams, NSString *subtitles, NSArray *updatedSeasonsData, NSError *error) {
                                      if (error) {
                                          [player hideLoadingIndicator];
                                          return;
                                      }
                                      
                                      weakSelf.currentStreams = streams;
                                      weakSelf.currentSubtitles = subtitles;
                                      [weakSelf syncSelectedQualityWithAvailableStreams];
                                      [weakSelf updatePadPlayButtonTitle];
                                      
                                      NSString *streamURL = [weakSelf bestStreamURLForCurrentSelection];
                                      if (streamURL) {
                                          // Безопасное экранирование пробелов и кириллицы
                                          NSString *cleanURL = [streamURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                                          cleanURL = [cleanURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                                          
                                          NSURL *url = [NSURL URLWithString:cleanURL];
                                          if (!url) {
                                              [player hideLoadingIndicator];
                                              [weakSelf showSimpleAlertTitle:@"Ошибка" message:@"Прямая ссылка имеет неверный формат."];
                                              return;
                                          }
                                          
                                          NSString *title = [NSString stringWithFormat:@"%@ — S%02ldE%02ld", weakSelf.movie.title, (long)weakSelf.selectedSeason, (long)weakSelf.selectedEpisode];
                                          [player playNewVideoWithURL:url title:title];
                                      } else {
                                          [player hideLoadingIndicator];
                                      }
                                  }];
}

@end