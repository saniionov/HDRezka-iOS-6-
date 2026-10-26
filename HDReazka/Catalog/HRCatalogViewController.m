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
    HRCatalogCategoryFilms   = 1,
    HRCatalogCategorySeries  = 2
} HRCatalogCategory;

// Состояния индикатора кнопки загрузок
typedef enum {
    HRDownloadNavStateIdle        = 0, // Серый (нет активных закачек и ошибок)
    HRDownloadNavStateDownloading = 1, // Зелёный (идёт скачивание)
    HRDownloadNavStateFailed      = 2  // Красный (ошибка скачивания)
} HRDownloadNavState;

@interface HRCatalogViewController ()
@property (nonatomic, assign) BOOL isSearching;
@property (nonatomic, assign) HRDownloadNavState lastKnownDownloadState;

@property (nonatomic, assign) HRCatalogCategory currentCategory;
@property (nonatomic, strong) UIButton *popularButton;
@property (nonatomic, strong) UIButton *filmsButton;
@property (nonatomic, strong) UIButton *seriesButton;
@property (nonatomic, strong) UIButton *downloadNavButton;
@end

@implementation HRCatalogViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Генерация цветной иконки загрузок (Серый / Зелёный / Красный)

- (UIImage *)createDownloadBarButtonIconWithColor:(UIColor *)iconColor
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20.0f, 20.0f), NO, 0.0f);
    
    [iconColor setFill];
    [iconColor setStroke];
    
    // Стрелка вниз
    UIBezierPath *arrowPath = [UIBezierPath bezierPath];
    [arrowPath moveToPoint:CGPointMake(10.0f, 13.0f)];
    [arrowPath addLineToPoint:CGPointMake(5.0f, 8.0f)];
    [arrowPath addLineToPoint:CGPointMake(8.0f, 8.0f)];
    [arrowPath addLineToPoint:CGPointMake(8.0f, 1.0f)];
    [arrowPath addLineToPoint:CGPointMake(12.0f, 1.0f)];
    [arrowPath addLineToPoint:CGPointMake(12.0f, 8.0f)];
    [arrowPath addLineToPoint:CGPointMake(15.0f, 8.0f)];
    [arrowPath closePath];
    [arrowPath fill];
    
    // Лоток под стрелкой
    UIBezierPath *trayPath = [UIBezierPath bezierPath];
    [trayPath moveToPoint:CGPointMake(3.0f, 11.0f)];
    [trayPath addLineToPoint:CGPointMake(3.0f, 17.0f)];
    [trayPath addLineToPoint:CGPointMake(17.0f, 17.0f)];
    [trayPath addLineToPoint:CGPointMake(17.0f, 11.0f)];
    trayPath.lineWidth = 2.0f;
    trayPath.lineCapStyle = kCGLineCapRound;
    trayPath.lineJoinStyle = kCGLineJoinRound;
    [trayPath stroke];
    
    UIImage *icon = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return icon;
}

- (HRDownloadNavState)calculateCurrentDownloadState
{
    BOOL isDownloading = NO;
    BOOL hasFailed = NO;
    
    for (HRDownloadTask *task in [HRDownloadManager sharedManager].tasks) {
        if (task.status == HRDownloadStatusDownloading) {
            isDownloading = YES;
        } else if (task.status == HRDownloadStatusFailed) {
            hasFailed = YES;
        }
    }
    
    if (isDownloading) {
        return HRDownloadNavStateDownloading;
    }
    if (hasFailed) {
        return HRDownloadNavStateFailed;
    }
    return HRDownloadNavStateIdle;
}

- (void)setupDownloadNavButton
{
    self.downloadNavButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.downloadNavButton.frame = CGRectMake(0, 0, 36, 30);
    self.downloadNavButton.backgroundColor = [UIColor colorWithRed:0.15f green:0.15f blue:0.15f alpha:1.0f];
    self.downloadNavButton.layer.cornerRadius = 5.0f;
    self.downloadNavButton.layer.borderWidth = 1.0f;
    [self.downloadNavButton addTarget:self action:@selector(downloadsButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:self.downloadNavButton];
    [self forceRefreshDownloadButtonColor];
}

- (void)forceRefreshDownloadButtonColor
{
    HRDownloadNavState currentState = [self calculateCurrentDownloadState];
    self.lastKnownDownloadState = currentState;
    
    UIColor *targetColor = nil;
    if (currentState == HRDownloadNavStateDownloading) {
        // Зелёный — идёт закачка
        targetColor = [UIColor colorWithRed:0.20f green:0.85f blue:0.25f alpha:1.0f];
    } else if (currentState == HRDownloadNavStateFailed) {
        // Красный — ошибка закачки
        targetColor = [UIColor colorWithRed:0.90f green:0.20f blue:0.20f alpha:1.0f];
    } else {
        // Серый — закачек нет (или завершены / на паузе)
        targetColor = [UIColor colorWithWhite:0.62f alpha:1.0f];
    }
    
    UIImage *coloredIcon = [self createDownloadBarButtonIconWithColor:targetColor];
    [self.downloadNavButton setImage:coloredIcon forState:UIControlStateNormal];
    self.downloadNavButton.layer.borderColor = [targetColor colorWithAlphaComponent:0.55f].CGColor;
}

- (void)updateDownloadButtonIndicatorIfNeeded
{
    HRDownloadNavState currentState = [self calculateCurrentDownloadState];
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
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedDomain = [defaults stringForKey:@"HR_MIRROR_DOMAIN"];
    if (savedDomain && [savedDomain length] > 0) {
        [HRHTTPClient sharedClient].baseURLString = savedDomain;
    }
    
    // 1. Шапка: Поиск + Категории
    CGFloat screenW = self.view.bounds.size.width;
    UIView *headerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, screenW, 102)];
    headerContainer.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    headerContainer.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, screenW, 52)];
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Поиск фильмов и сериалов";
    self.searchBar.barStyle = UIBarStyleBlackOpaque;
    
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
            searchField.backgroundColor = [UIColor colorWithRed:0.16 green:0.16 blue:0.16 alpha:1.0];
            searchField.layer.borderColor = [[UIColor colorWithRed:0.55 green:0.10 blue:0.10 alpha:0.80] CGColor];
            searchField.layer.borderWidth = 1.0f;
            searchField.layer.cornerRadius = 6.0f;
            searchField.layer.masksToBounds = YES;
            [searchField setValue:[UIColor colorWithWhite:0.55f alpha:1.0f] forKeyPath:@"_placeholderLabel.textColor"];
        }
    }
    [headerContainer addSubview:self.searchBar];
    
    // 2. Блок кнопок категорий
    UIView *categoriesBar = [[UIView alloc] initWithFrame:CGRectMake(0, 56, screenW, 46)];
    categoriesBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    categoriesBar.backgroundColor = [UIColor colorWithRed:0.09 green:0.09 blue:0.09 alpha:1.0];
    
    CGFloat btnW = (screenW - 32.0f) / 3.0f;
    self.popularButton = [self createCategoryButtonWithTitle:@"Популярное" frame:CGRectMake(8, 6, btnW, 32) tag:0];
    self.filmsButton   = [self createCategoryButtonWithTitle:@"Фильмы"     frame:CGRectMake(16 + btnW, 6, btnW, 32) tag:1];
    self.seriesButton  = [self createCategoryButtonWithTitle:@"Сериалы"    frame:CGRectMake(24 + btnW * 2, 6, btnW, 32) tag:2];
    
    [categoriesBar addSubview:self.popularButton];
    [categoriesBar addSubview:self.filmsButton];
    [categoriesBar addSubview:self.seriesButton];
    [headerContainer addSubview:categoriesBar];
    
    [self updateCategoryButtonsStyle];
    
    // 3. Таблица каталога
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.rowHeight = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 150.0f : 96.0f;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.tableHeaderView = headerContainer;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    self.tableView.separatorColor = [UIColor colorWithRed:0.55 green:0.10 blue:0.10 alpha:0.50];
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

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self forceRefreshDownloadButtonColor];
}

// Автоматическое обновление ширины хедера и кнопок при повороте экрана iPad/iPhone
- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    CGFloat screenW = self.view.bounds.size.width;
    UIView *header = self.tableView.tableHeaderView;
    if (header) {
        CGRect hFrame = header.frame;
        hFrame.size.width = screenW;
        header.frame = hFrame;
        self.tableView.tableHeaderView = header;
    }
    
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    CGFloat btnH = isPad ? 40.0f : 32.0f;
    CGFloat btnW = (screenW - 32.0f) / 3.0f;
    
    self.popularButton.frame = CGRectMake(8, 6, btnW, btnH);
    self.filmsButton.frame   = CGRectMake(16 + btnW, 6, btnW, btnH);
    self.seriesButton.frame  = CGRectMake(24 + btnW * 2, 6, btnW, btnH);
    
    self.loadingIndicator.center = CGPointMake(screenW / 2.0f, self.view.bounds.size.height / 2.0f);
}

- (void)downloadsButtonTapped
{
    [self.searchBar resignFirstResponder];
    HRDownloadsViewController *downloadsVC = [[HRDownloadsViewController alloc] init];
    [self.navigationController pushViewController:downloadsVC animated:YES];
}

- (UIButton *)createCategoryButtonWithTitle:(NSString *)title frame:(CGRect)frame tag:(NSInteger)tag
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = frame;
    btn.tag = tag;
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0f];
    [btn setTitle:title forState:UIControlStateNormal];
    btn.layer.cornerRadius = 4.0f;
    btn.layer.masksToBounds = YES;
    btn.layer.borderWidth = 1.0f;
    [btn addTarget:self action:@selector(categoryButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)updateCategoryButtonsStyle
{
    NSArray *buttons = @[self.popularButton, self.filmsButton, self.seriesButton];
    for (UIButton *btn in buttons) {
        if (btn.tag == (NSInteger)self.currentCategory) {
            btn.backgroundColor = [UIColor colorWithRed:0.62 green:0.08 blue:0.08 alpha:1.0];
            btn.layer.borderColor = [[UIColor colorWithRed:0.85 green:0.20 blue:0.20 alpha:1.0] CGColor];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        } else {
            btn.backgroundColor = [UIColor colorWithRed:0.14 green:0.14 blue:0.14 alpha:1.0];
            btn.layer.borderColor = [[UIColor colorWithWhite:0.22f alpha:1.0f] CGColor];
            [btn setTitleColor:[UIColor colorWithWhite:0.75f alpha:1.0f] forState:UIControlStateNormal];
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

- (BOOL)hasSessionCookies
{
    NSArray *cookies = [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies];
    for (NSHTTPCookie *c in cookies) {
        if ([[c name] isEqualToString:@"dle_user_id"] ||
            [[c name] isEqualToString:@"PHPSESSID"] ||
            [[c name] rangeOfString:@"anubis-auth"].location != NSNotFound) {
            return YES;
        }
    }
    return NO;
}

- (void)startLoadingProcess
{
    [self.loadingIndicator startAnimating];
    
    if ([HRHTTPClient sharedClient].authMode == HRAuthModePersonal && ![self hasSessionCookies]) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *login = [defaults stringForKey:@"HR_AUTH_LOGIN"] ?: @"";
        NSString *password = [defaults stringForKey:@"HR_AUTH_PASSWORD"] ?: @"";
        
        if ([login length] > 0 && [password length] > 0) {
            [self performLoginWithCompletion:^(BOOL success) {
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

- (void)performLoginWithCompletion:(void (^)(BOOL success))completion
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *login = [defaults stringForKey:@"HR_AUTH_LOGIN"] ?: @"";
    NSString *password = [defaults stringForKey:@"HR_AUTH_PASSWORD"] ?: @"";
    
    if ([login length] == 0 || [password length] == 0) {
        if (completion) completion(NO);
        return;
    }
    
    NSDictionary *params = @{
                             @"login_name": login,
                             @"login_password": password,
                             @"login_not_save": @"0"
                             };
    
    [[HRHTTPClient sharedClient] POST:@"/ajax/login/" parameters:params completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (error || !data) {
            if (completion) completion(NO);
            return;
        }
        
        NSError *jsonErr = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        BOOL ok = [[json objectForKey:@"success"] boolValue];
        if (completion) completion(ok);
    }];
}

- (void)resetToHomeScreen
{
    // Возврат на главную: сбрасываем поиск и возвращаем категорию «Популярное».
    BOOL needsReload = self.isSearching || self.currentCategory != HRCatalogCategoryPopular;
    
    self.isSearching = NO;
    self.currentCategory = HRCatalogCategoryPopular;
    self.searchBar.text = @"";
    [self.searchBar resignFirstResponder];
    [self.searchBar setShowsCancelButton:NO animated:NO];
    [self updateCategoryButtonsStyle];
    
    // Перезагружаем каталог, чтобы убрать результаты предыдущего поиска.
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
    
    HRMovie *movie = [self.movies objectAtIndex:indexPath.row];
    [cell configureWithMovie:movie];
    
    cell.posterImageView.image = nil;
    if ([movie.posterURLString length] > 0) {
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