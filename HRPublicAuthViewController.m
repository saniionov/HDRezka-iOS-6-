#import "HRPublicAuthViewController.h"
#import "HRHTTPClient.h"

@interface HRPublicAuthViewController () <UIWebViewDelegate>
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) NSTimer *cookieCheckTimer;
@property (nonatomic, assign) BOOL authCompleted;
@end

@implementation HRPublicAuthViewController

- (void)dealloc
{
    [self.cookieCheckTimer invalidate];
    self.cookieCheckTimer = nil;
    self.webView.delegate = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Авторизация WK26";
    self.view.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.05 alpha:1.0];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Закрыть"
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:self
                                                                            action:@selector(closeTapped)];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Обновить"
                                                                              style:UIBarButtonItemStyleBordered
                                                                             target:self
                                                                             action:@selector(reloadPage)];
    
    [[NSHTTPCookieStorage sharedHTTPCookieStorage] setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    
    // Используем чистый UIWebView, чтобы твик WK26 мог свободно делать свои инъекции
    self.webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.webView.delegate = self;
    self.webView.scalesPageToFit = YES;
    self.webView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:self.webView];
    
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    self.spinner.center = CGPointMake(self.view.bounds.size.width / 2.0f, self.view.bounds.size.height / 2.0f);
    self.spinner.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, self.view.bounds.size.height - 32, self.view.bounds.size.width, 32)];
    self.statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.statusLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:12.0f];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.text = @"Подключение к зеркалу...";
    [self.view addSubview:self.statusLabel];
    
    [self reloadPage];
    
    self.cookieCheckTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                             target:self
                                                           selector:@selector(checkAuthStatus)
                                                           userInfo:nil
                                                            repeats:YES];
}

- (void)logPageDiagnostics:(NSString *)event
{
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"HR_DEBUG_MODE"]) return;
    NSString *url = [self.webView stringByEvaluatingJavaScriptFromString:@"location.href"];
    NSString *title = [self.webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    NSString *ready = [self.webView stringByEvaluatingJavaScriptFromString:@"document.readyState"];
    NSString *items = [self.webView stringByEvaluatingJavaScriptFromString:@"document.querySelectorAll('.b-content__inline_item').length.toString()"];
    NSMutableArray *cookieNames = [NSMutableArray array];
    NSURL *targetURL = [NSURL URLWithString:self.targetURLString ?: @"https://rezka.ag"];
    NSString *targetHost = [targetURL.host lowercaseString];
    for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies]) {
        NSString *domain = [cookie.domain lowercaseString];
        if ([domain rangeOfString:@"rezka"].location != NSNotFound ||
            (targetHost && [domain rangeOfString:targetHost].location != NSNotFound)) {
            if (cookie.name) [cookieNames addObject:cookie.name];
        }
    }
    NSLog(@"[HRPublicAuth][TRACE] %@ url=%@ title=%@ ready=%@ items=%@ cookieNames=%@ completed=%d",
          event, url, title, ready, items, cookieNames, self.authCompleted);
}

- (void)reloadPage
{
    self.authCompleted = NO;
    [self.spinner startAnimating];
    
    NSString *urlStr = self.targetURLString ?: [HRHTTPClient sharedClient].baseURLString ?: @"https://rezka.ag";
    if (![urlStr hasPrefix:@"http://"] && ![urlStr hasPrefix:@"https://"]) {
        urlStr = [@"https://" stringByAppendingString:urlStr];
    }
    self.targetURLString = urlStr;
    
    NSURL *url = [NSURL URLWithString:urlStr];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:45.0];
    [req setHTTPShouldHandleCookies:YES];
    
    [self.webView loadRequest:req];
}

- (void)syncWebViewUserAgent
{
    NSString *webUA = [self.webView stringByEvaluatingJavaScriptFromString:@"navigator.userAgent"];
    if (webUA && [webUA length] > 0) {
        [[HRHTTPClient sharedClient] updatePublicUserAgent:webUA];
    }
}

- (void)checkAuthStatus
{
    if (!self.webView || self.authCompleted) return;
    
    NSString *urlStr = [self.webView stringByEvaluatingJavaScriptFromString:@"location.href"] ?: @"";
    NSString *title = [self.webView stringByEvaluatingJavaScriptFromString:@"document.title"] ?: @"";
    NSString *ready = [self.webView stringByEvaluatingJavaScriptFromString:@"document.readyState"] ?: @"";
    NSString *bodyText = [self.webView stringByEvaluatingJavaScriptFromString:
                          @"(document.body && document.body.innerText) ? document.body.innerText : ''"] ?: @"";
    NSString *itemsCountStr = [self.webView stringByEvaluatingJavaScriptFromString:
                               @"document.querySelectorAll('.b-content__inline_item').length.toString()"];
    NSInteger itemsCount = [itemsCountStr integerValue];
    
    NSString *lowerTitle = [title lowercaseString];
    NSString *lowerBody = [bodyText lowercaseString];
    BOOL onChallengePage =
    ([lowerTitle rangeOfString:@"не бот"].location != NSNotFound) ||
    ([lowerTitle rangeOfString:@"checking"].location != NSNotFound) ||
    ([lowerTitle rangeOfString:@"anubis"].location != NSNotFound) ||
    ([lowerBody rangeOfString:@"проверяем, что вы не бот"].location != NSNotFound) ||
    ([lowerBody rangeOfString:@"проверка безопасности"].location != NSNotFound) ||
    ([lowerBody rangeOfString:@"checking your browser"].location != NSNotFound) ||
    ([lowerBody rangeOfString:@"verify you are human"].location != NSNotFound);
    
    // A challenge cookie alone is not proof that the challenge page has completed.
    // Wait until the challenge text disappears and the document has finished loading.
    BOOL pageLooksReady = ([ready isEqualToString:@"complete"] ||
                           [ready isEqualToString:@"interactive"]);
    BOOL hasCatalogContent = (itemsCount > 0);
    BOOL leftChallenge = !onChallengePage &&
    pageLooksReady &&
    [urlStr rangeOfString:@"about:blank"].location == NSNotFound &&
    [urlStr length] > 0;
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"HR_DEBUG_MODE"]) {
        NSLog(@"[HRPublicAuth][TRACE] auth-check url=%@ title=%@ ready=%@ items=%ld challenge=%d leftChallenge=%d",
              urlStr, title, ready, (long)itemsCount, onChallengePage, leftChallenge);
    }
    
    // Catalog content is a strong success signal. Otherwise, accept only a loaded
    // non-challenge page; never close merely because an Anubis/Cloudflare cookie exists.
    if (hasCatalogContent || leftChallenge) {
        self.authCompleted = YES;
        [self.spinner stopAnimating];
        self.statusLabel.backgroundColor = [UIColor colorWithRed:0.10 green:0.45 blue:0.15 alpha:0.95];
        self.statusLabel.textColor = [UIColor whiteColor];
        self.statusLabel.text = @"✓ Проверка завершена. Возвращаемся...";
        [self performSelector:@selector(closeTapped) withObject:nil afterDelay:1.2];
    } else if (onChallengePage) {
        self.statusLabel.text = @"Ожидание завершения проверки безопасности...";
    }
}

- (void)closeTapped
{
    [self.cookieCheckTimer invalidate];
    self.cookieCheckTimer = nil;
    [self syncWebViewUserAgent];
    [self.webView stopLoading];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"HRNeedReloadCatalogNotification" object:nil];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self logPageDiagnostics:@"didStartLoad"];
    if (!self.authCompleted) {
        self.statusLabel.text = @"Прохождение проверки безопасности...";
        [self.spinner startAnimating];
    }
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self logPageDiagnostics:@"didFinishLoad-before-UA-sync"];
    [self.spinner stopAnimating];
    [self syncWebViewUserAgent];
    [self checkAuthStatus];
    
    if (!self.authCompleted) {
        NSString *pageTitle = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
        if ([pageTitle length] > 0) {
            self.statusLabel.text = [NSString stringWithFormat:@"Статус: %@", pageTitle];
        }
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"HR_DEBUG_MODE"]) {
        NSLog(@"[HRPublicAuth][TRACE] didFailLoad errorDomain=%@ code=%ld description=%@",
              error.domain, (long)error.code, error.localizedDescription);
    }
    if (error.code == NSURLErrorCancelled) return;
    [self.spinner stopAnimating];
    self.statusLabel.text = [NSString stringWithFormat:@"Ошибка: %@", error.localizedDescription];
    self.statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.35 blue:0.35 alpha:1.0];
}

@end