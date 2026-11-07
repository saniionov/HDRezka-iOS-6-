#import "HRCatalogViewController.h"
#import "HRCatalogParser.h"
#import "HRHTTPClient.h"
#import "HRMovie.h"
#import "HRMovieCell.h"
#import "HRMovieDetailViewController.h"
#import "HRDownloadsViewController.h"
#import "HRDownloadManager.h"
#import "HRDownloadTask.h"
#import "HRImageCache.h"
#import "HRTheme.h"
#import <QuartzCore/QuartzCore.h>

typedef enum {
    HRCatalogCategoryPopular = 0,
    HRCatalogCategoryFilms = 1,
    HRCatalogCategorySeries = 2
} HRCatalogCategory;

@interface HRCatalogViewController ()
@property (nonatomic, assign) BOOL isSearching;
@property (nonatomic, assign) HRDownloadIndicatorState lastKnownDownloadState;

@property (nonatomic, assign) HRCatalogCategory currentCategory;
@property (nonatomic, strong) UIButton *popularButton;
@property (nonatomic, strong) UIButton *filmsButton;
@property (nonatomic, strong) UIButton *seriesButton;
@property (nonatomic, strong) UIButton *downloadNavButton;

@property (nonatomic, strong) UIView *headerContainer;
@property (nonatomic, strong) UIView *categoriesBar;

- (UIButton *)createCategoryButtonWithTitle:(NSString *)title cornerRadius:(CGFloat)cornerRadius tag:(NSInteger)tag;
- (void)layoutGlossLayerForButton:(UIButton *)btn;
- (void)updateCategoryButtonsStyle;
@end

@implementation HRCatalogViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Кнопка и индикатор загрузок

- (void)setupDownloadNavButton
{
    self.downloadNavButton = [HRTheme createDownloadNavButtonWithTarget:self
                                                                 action:@selector(downloadsButtonTapped)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.downloadNavButton];
    [self forceRefreshDownloadButtonColor];
}

- (void)forceRefreshDownloadButtonColor
{
    dispatch_async(dispatch_get_main_queue(), ^{
        HRDownloadIndicatorState currentState = [HRDownloadManager sharedManager].indicatorState;
        self.lastKnownDownloadState = currentState;
        
        UIColor *targetColor = nil;
        if (currentState == HRDownloadIndicatorStateDownloading) {
            targetColor = [UIColor colorWithRed:0.20f green:0.88f blue:0.30f alpha:1.0f];
        } else if (currentState == HRDownloadIndicatorStateFailed) {
            targetColor = [UIColor colorWithRed:0.95f green:0.15f blue:0.15f alpha:1.0f];
        } else {
            targetColor = [UIColor colorWithWhite:0.65f alpha:1.0f];
        }
        
        UIImage *coloredIcon = [HRTheme createDownloadBarButtonIconWithColor:targetColor];
        [self.downloadNavButton setImage:coloredIcon forState:UIControlStateNormal];
        
        self.downloadNavButton.layer.borderWidth = 0.0f;
        self.downloadNavButton.layer.borderColor = [UIColor clearColor].CGColor;
    });
}

- (void)updateDownloadButtonIndicatorIfNeeded
{
    HRDownloadIndicatorState currentState = [HRDownloadManager sharedManager].indicatorState;
    if (currentState != self.lastKnownDownloadState) {
        [self forceRefreshDownloadButtonColor];
    }
}

#pragma mark - Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"HDRezka";
    self.navigationItem.titleView = [HRTheme createLogoTitleView];
    self.view.backgroundColor = [UIColor blackColor];
    
    [self setupDownloadNavButton];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(updateDownloadButtonIndicatorIfNeeded)
                                                 name:kHRDownloadProgressNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(forceRefreshDownloadButtonColor)
                                                 name:kHRDownloadFinishedNotification
                                               object:nil];
    
    self.movies = [NSMutableArray array];
    self.currentCategory = HRCatalogCategoryPopular;
    
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    CGFloat searchH = isPad ? 58.0f : 50.0f;
    CGFloat catH = isPad ? 56.0f : 48.0f;
    CGFloat headerH = searchH + catH;
    CGFloat screenW = self.view.bounds.size.width;
    
    // Монолитная темная шапка
    self.headerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenW, headerH)];
    self.headerContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.headerContainer.backgroundColor = [UIColor colorWithRed:0.10f green:0.10f blue:0.11f alpha:1.0f];
    
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, screenW, searchH)];
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Поиск фильмов и сериалов";
    self.searchBar.barStyle = UIBarStyleBlackOpaque;
    self.searchBar.backgroundColor = [UIColor clearColor];
    
    [self applyCleanSearchBarStyle];
    [self.headerContainer addSubview:self.searchBar];
    
    // Блок кнопок категорий
    self.categoriesBar = [[UIView alloc] initWithFrame:CGRectMake(0, searchH, screenW, catH)];
    self.categoriesBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.categoriesBar.backgroundColor = [UIColor clearColor];
    
    CGFloat btnCornerR = isPad ? 11.0f : 8.0f;
    self.popularButton = [self createCategoryButtonWithTitle:@"Популярное" cornerRadius:btnCornerR tag:0];
    self.filmsButton = [self createCategoryButtonWithTitle:@"Фильмы" cornerRadius:btnCornerR tag:1];
    self.seriesButton = [self createCategoryButtonWithTitle:@"Сериалы" cornerRadius:btnCornerR tag:2];
    
    [self.categoriesBar addSubview:self.popularButton];
    [self.categoriesBar addSubview:self.filmsButton];
    [self.categoriesBar addSubview:self.seriesButton];
    [self.headerContainer addSubview:self.categoriesBar];
    
    [self updateCategoryButtonsStyle];
    
    // Таблица каталога
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.rowHeight = isPad ? 150.0f : 96.0f;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.tableHeaderView = self.headerContainer;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    // Серая линия вместо красной
    self.tableView.separatorColor = [UIColor colorWithWhite:0.25f alpha:1.0f];
    [self.view addSubview:self.tableView];
    
    self.loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.loadingIndicator.center = self.view.center;
    self.loadingIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.loadingIndicator];
    
    self.navigationItem.rightBarButtonItem = [HRTheme createGlossyBarButtonWithTitle:@"Обновить"
                                                                              target:self
                                                                              action:@selector(startLoadingProcess)];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(startLoadingProcess)
                                                 name:@"HRNeedReloadCatalogNotification"
                                               object:nil];
    
    [self startLoadingProcess];
}

- (void)applyCleanSearchBarStyle
{
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    CGFloat cornerR = isPad ? 8.0f : 6.0f;
    
    for (UIView *subview in self.searchBar.subviews) {
        if ([subview isKindOfClass:NSClassFromString(@"UISearchBarBackground")]) {
            subview.alpha = 0.0f;
        }
        if ([subview isKindOfClass:[UITextField class]]) {
            UITextField *searchField = (UITextField *)subview;
            searchField.background = nil;
            searchField.disabledBackground = nil;
            searchField.borderStyle = UITextBorderStyleNone;
            searchField.textColor = [UIColor whiteColor];
            searchField.font = [UIFont systemFontOfSize:isPad ? 16.0f : 14.0f];
            
            searchField.backgroundColor = [UIColor colorWithRed:0.153f green:0.153f blue:0.162f alpha:1.0f];
            
            searchField.layer.borderWidth = 0.0f;
            searchField.layer.borderColor = [UIColor clearColor].CGColor;
            searchField.layer.cornerRadius = cornerR;
            searchField.layer.masksToBounds = YES;
            
            [searchField setValue:[UIColor colorWithWhite:0.65f alpha:1.0f] forKeyPath:@"_placeholderLabel.textColor"];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self forceRefreshDownloadButtonColor];
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    CGFloat screenW = self.view.bounds.size.width;
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    
    CGFloat searchH = isPad ? 58.0f : 50.0f;
    CGFloat padOffset = isPad ? 20.0f : 10.0f;
    CGFloat spacing = isPad ? 10.0f : 7.0f;
    CGFloat btnH = isPad ? 38.0f : 32.0f;
    CGFloat posterTopInCell = isPad ? 12.0f : 8.0f;
    
    CGFloat visibleSearchBottom = 0.0f;
    for (UIView *subview in self.searchBar.subviews) {
        if ([subview isKindOfClass:[UITextField class]]) {
            visibleSearchBottom = CGRectGetMaxY(subview.frame);
            break;
        }
    }
    if (visibleSearchBottom <= 0.0f) {
        visibleSearchBottom = isPad ? 44.0f : 39.0f;
    }
    
    CGFloat searchBarBottomSpace = searchH - visibleSearchBottom;
    CGFloat bottomExtraGap = 8.0f;
    CGFloat catH = searchBarBottomSpace + posterTopInCell + btnH + bottomExtraGap;
    CGFloat totalH = searchH + catH;
    
    if (self.headerContainer) {
        self.headerContainer.frame = CGRectMake(0, 0, screenW, totalH);
        self.searchBar.frame = CGRectMake(0, 0, screenW, searchH);
        self.categoriesBar.frame = CGRectMake(0, searchH, screenW, catH);
        self.tableView.tableHeaderView = self.headerContainer;
    }
    
    CGFloat btnY = floorf((searchBarBottomSpace + posterTopInCell) / 2.0f);
    
    CGFloat totalAvailableW = screenW - (padOffset * 2.0f);
    CGFloat btnW = floorf((totalAvailableW - (spacing * 2.0f)) / 3.0f);
    
    CGFloat x0 = floorf(padOffset);
    CGFloat x1 = floorf(padOffset + btnW + spacing);
    CGFloat x2 = floorf(screenW - padOffset - btnW);
    
    self.popularButton.frame = CGRectIntegral(CGRectMake(x0, btnY, btnW, btnH));
    self.filmsButton.frame = CGRectIntegral(CGRectMake(x1, btnY, btnW, btnH));
    self.seriesButton.frame = CGRectIntegral(CGRectMake(x2, btnY, btnW, btnH));
    
    [self layoutGlossLayerForButton:self.popularButton];
    [self layoutGlossLayerForButton:self.filmsButton];
    [self layoutGlossLayerForButton:self.seriesButton];
    
    self.loadingIndicator.center = CGPointMake(screenW / 2.0f, self.view.bounds.size.height / 2.0f);
}

- (void)layoutGlossLayerForButton:(UIButton *)btn
{
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CGFloat h = btn.bounds.size.height;
    CGFloat w = btn.bounds.size.width;
    
    for (CALayer *layer in btn.layer.sublayers) {
        if ([layer.name isEqualToString:@"CategorySubtleGloss"]) {
            layer.frame = CGRectMake(0.0f, 0.0f, w, h);
            break;
        }
    }
    [CATransaction commit];
}

- (void)downloadsButtonTapped
{
    [self.searchBar resignFirstResponder];
    HRDownloadsViewController *downloadsVC = [[HRDownloadsViewController alloc] init];
    [self.navigationController pushViewController:downloadsVC animated:YES];
}

- (UIButton *)createCategoryButtonWithTitle:(NSString *)title cornerRadius:(CGFloat)cornerRadius tag:(NSInteger)tag
{
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.tag = tag;
    
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:isPad ? 15.5f : 13.5f];
    [btn setTitle:title forState:UIControlStateNormal];
    
    [btn setTitleShadowColor:[UIColor blackColor] forState:UIControlStateNormal];
    btn.titleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
    
    CGFloat screenScale = [UIScreen mainScreen].scale;
    btn.titleLabel.layer.contentsScale = screenScale;
    btn.titleLabel.layer.rasterizationScale = screenScale;
    
    btn.layer.cornerRadius = cornerRadius;
    btn.layer.masksToBounds = YES;
    
    btn.layer.borderWidth = (screenScale >= 2.0f) ? 0.5f : 1.0f;
    btn.layer.borderColor = [UIColor clearColor].CGColor;
    
    CAGradientLayer *volumeLayer = [CAGradientLayer layer];
    volumeLayer.name = @"CategorySubtleGloss";
    volumeLayer.contentsScale = screenScale;
    [btn.layer insertSublayer:volumeLayer atIndex:0];
    
    [btn addTarget:self action:@selector(categoryButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)updateCategoryButtonsStyle
{
    NSArray *buttons = @[self.popularButton, self.filmsButton, self.seriesButton];
    for (UIButton *btn in buttons) {
        CAGradientLayer *volumeLayer = nil;
        for (CALayer *layer in btn.layer.sublayers) {
            if ([layer.name isEqualToString:@"CategorySubtleGloss"]) {
                volumeLayer = (CAGradientLayer *)layer;
                break;
            }
        }
        
        if (btn.tag == (NSInteger)self.currentCategory) {
            btn.backgroundColor = [UIColor colorWithRed:0.449f green:0.030f blue:0.047f alpha:1.0f];
            btn.layer.borderColor = [UIColor colorWithRed:0.65f green:0.08f blue:0.11f alpha:0.50f].CGColor;
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            
            if (volumeLayer) {
                volumeLayer.locations = @[@(0.0f), @(0.40f), @(1.0f)];
                volumeLayer.colors = @[
                                       (id)[UIColor colorWithWhite:1.0f alpha:0.09f].CGColor,
                                       (id)[UIColor colorWithWhite:1.0f alpha:0.01f].CGColor,
                                       (id)[UIColor colorWithWhite:0.0f alpha:0.10f].CGColor
                                       ];
            }
        } else {
            btn.backgroundColor = [UIColor colorWithRed:0.150f green:0.150f blue:0.161f alpha:1.0f];
            btn.layer.borderColor = [UIColor colorWithWhite:1.0f alpha:0.07f].CGColor;
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            
            if (volumeLayer) {
                volumeLayer.locations = @[@(0.0f), @(0.40f), @(1.0f)];
                volumeLayer.colors = @[
                                       (id)[UIColor colorWithWhite:1.0f alpha:0.05f].CGColor,
                                       (id)[UIColor colorWithWhite:1.0f alpha:0.00f].CGColor,
                                       (id)[UIColor colorWithWhite:0.0f alpha:0.04f].CGColor
                                       ];
            }
        }
    }
}

- (void)categoryButtonTapped:(UIButton *)sender
{
    if (self.currentCategory == (HRCatalogCategory)sender.tag && !self.isSearching) return;
    
    self.currentCategory = (HRCatalogCategory)sender.tag;
    [self updateCategoryButtonsStyle];
    
    self.isSearching = NO;
    self.searchBar.text = @"";
    [self.searchBar resignFirstResponder];
    [self.searchBar setShowsCancelButton:NO animated:YES];
    
    [self loadCatalog];
}

#pragma mark - Авторизация и загрузка каталога

- (void)startLoadingProcess
{
    [self.loadingIndicator startAnimating];
    
    HRHTTPClient *client = [HRHTTPClient sharedClient];
    if (client.authMode == HRAuthModePersonal && ![client hasSessionCookies]) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *login = [defaults stringForKey:@"HR_AUTH_LOGIN"] ?: @"";
        NSString *password = [defaults stringForKey:@"HR_AUTH_PASSWORD"] ?: @"";
        
        if ([login length] > 0 && [password length] > 0) {
            [client loginWithUsername:login
                             password:password
                           completion:^(BOOL success, NSError *error) {
                               if (success) {
                                   [self loadCatalog];
                               } else {
                                   [self.loadingIndicator stopAnimating];
                               }
                           }];
            return;
        }
    }
    
    [self loadCatalog];
}

- (void)resetToHomeScreen
{
    BOOL needsReload = self.isSearching || self.currentCategory != HRCatalogCategoryPopular;
    
    self.isSearching = NO;
    self.currentCategory = HRCatalogCategoryPopular;
    self.searchBar.text = @"";
    [self.searchBar resignFirstResponder];
    [self.searchBar setShowsCancelButton:NO animated:NO];
    [self updateCategoryButtonsStyle];
    
    if (needsReload || [self.movies count] == 0) {
        [self loadCatalog];
    } else {
        [self.tableView reloadData];
    }
}

- (void)loadCatalog
{
    self.isSearching = NO;
    NSString *path = @"/";
    if (self.currentCategory == HRCatalogCategoryFilms) {
        path = @"/films/";
    } else if (self.currentCategory == HRCatalogCategorySeries) {
        path = @"/series/";
    }
    
    [self.loadingIndicator startAnimating];
    
    [[HRHTTPClient sharedClient] GET:path parameters:nil completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        [self.loadingIndicator stopAnimating];
        
        if (error || !data) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка сети"
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }
        
        NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSArray *parsedMovies = [HRCatalogParser parseCatalogHTML:html];
        
        [self.movies removeAllObjects];
        [self.movies addObjectsFromArray:parsedMovies];
        [self.tableView reloadData];
    }];
}

- (void)performSearchWithQuery:(NSString *)query
{
    if ([query length] == 0) return;
    
    self.isSearching = YES;
    [self.loadingIndicator startAnimating];
    
    NSString *escapedQuery = (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(
                                                                                                   kCFAllocatorDefault,
                                                                                                   (__bridge CFStringRef)query,
                                                                                                   NULL,
                                                                                                   CFSTR(":/?#[]@!$&'()*+,;="),
                                                                                                   kCFStringEncodingUTF8
                                                                                                   );
    
    NSString *searchPath = [NSString stringWithFormat:@"/search/?do=search&subaction=search&q=%@", escapedQuery];
    
    [[HRHTTPClient sharedClient] GET:searchPath parameters:nil completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        [self.loadingIndicator stopAnimating];
        
        if (error || !data) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Ошибка поиска"
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }
        
        NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSArray *results = [HRCatalogParser parseCatalogHTML:html];
        
        [self.movies removeAllObjects];
        [self.movies addObjectsFromArray:results];
        [self.tableView reloadData];
    }];
}

#pragma mark - UISearchBarDelegate

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    [searchBar resignFirstResponder];
    [self performSearchWithQuery:searchBar.text];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    [searchBar setShowsCancelButton:NO animated:YES];
    [self loadCatalog];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    if ([searchBar.text length] == 0) {
        [searchBar setShowsCancelButton:NO animated:YES];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.movies count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"HRMovieCustomCell";
    HRMovieCell *cell = (HRMovieCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[HRMovieCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    HRMovie *movie = nil;
    if (indexPath.row < [self.movies count]) {
        movie = [self.movies objectAtIndex:indexPath.row];
        [cell configureWithMovie:movie];
    }
    
    cell.posterImageView.image = nil;
    if (movie && [movie.posterURLString length] > 0) {
        NSString *urlToLoad = movie.posterURLString;
        __weak HRMovieCell *weakCell = cell;
        [[HRImageCache sharedCache] loadImageForURLString:urlToLoad completion:^(UIImage *image) {
            if (image && weakCell) {
                weakCell.posterImageView.image = image;
                [weakCell.posterImageView setNeedsDisplay];
            }
        }];
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.searchBar resignFirstResponder];
    
    HRMovie *selectedMovie = [self.movies objectAtIndex:indexPath.row];
    
    HRMovie *movieToPass = [[HRMovie alloc] init];
    movieToPass.movieId = selectedMovie.movieId;
    movieToPass.title = selectedMovie.title;
    movieToPass.detailURLString = selectedMovie.detailURLString;
    movieToPass.posterURLString = selectedMovie.posterURLString;
    movieToPass.info = selectedMovie.info;
    movieToPass.isSeries = selectedMovie.isSeries;
    movieToPass.rating = selectedMovie.rating;
    
    HRMovieDetailViewController *detailVC = [[HRMovieDetailViewController alloc] initWithMovie:movieToPass];
    [self.navigationController pushViewController:detailVC animated:YES];
}

@end