#import "HRHTTPClient.h"

static NSString * const kHRStoredAuthModeKey     = @"HRStoredAuthModeKey";
static NSString * const kHRPersonalBaseURLKey    = @"HR_PERSONAL_MIRROR_DOMAIN";
static NSString * const kHRPublicBaseURLKey      = @"HR_PUBLIC_MIRROR_DOMAIN";
static NSString * const kHRStoredPublicUAKey     = @"HR_STORED_PUBLIC_USER_AGENT";

@interface HRHTTPClient ()
@property (nonatomic, strong) NSOperationQueue *networkQueue;
@end

@implementation HRHTTPClient

+ (instancetype)sharedClient
{
    static HRHTTPClient *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[HRHTTPClient alloc] init];
    });
    return _sharedInstance;
}

- (id)init
{
    self = [super init];
    if (self) {
        _networkQueue = [[NSOperationQueue alloc] init];
        _networkQueue.maxConcurrentOperationCount = 2;
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:kHRStoredAuthModeKey]) {
            _authMode = (HRAuthMode)[defaults integerForKey:kHRStoredAuthModeKey];
        } else {
            _authMode = HRAuthModePersonal;
        }
        
        // Миграция старого ключа HR_MIRROR_DOMAIN, если он был сохранён ранее
        NSString *legacyDomain = [defaults stringForKey:@"HR_MIRROR_DOMAIN"];
        if (legacyDomain && [legacyDomain length] > 0 && ![defaults objectForKey:kHRPersonalBaseURLKey]) {
            [defaults setObject:legacyDomain forKey:kHRPersonalBaseURLKey];
            [defaults synchronize];
        }
        
        if (_authMode == HRAuthModePersonal) {
            NSString *personalURL = [defaults stringForKey:kHRPersonalBaseURLKey];
            _baseURLString = (personalURL && [personalURL length] > 0) ? personalURL : @"https://rezka.fi";
            _customUserAgent = kHRPublicUserAgent;
        } else {
            NSString *publicURL = [defaults stringForKey:kHRPublicBaseURLKey];
            _baseURLString = (publicURL && [publicURL length] > 0) ? publicURL : @"https://rezka.ag";
            
            // Подгружаем сохранённый User-Agent от твика WK26, если он уже был считан из UIWebView
            NSString *savedPublicUA = [defaults stringForKey:kHRStoredPublicUAKey];
            _customUserAgent = (savedPublicUA && [savedPublicUA length] > 0) ? savedPublicUA : kHRPublicUserAgent;
        }
    }
    return self;
}

- (void)switchToMode:(HRAuthMode)mode newBaseURL:(NSString *)newBaseURL
{
    // Диагностика: выясняем, кто повторно вызывает переключение режима.
    NSUserDefaults *debugDefaults = [NSUserDefaults standardUserDefaults];
    if ([debugDefaults boolForKey:@"HR_DEBUG_MODE"]) {
        NSLog(@"[HRHTTPClient][TRACE] switchToMode ENTER oldMode=%ld oldURL=%@ oldUA=%@ newMode=%ld requestedURL=%@",
              (long)self.authMode, self.baseURLString, self.customUserAgent,
              (long)mode, newBaseURL);
        NSArray *stack = [NSThread callStackSymbols];
        NSLog(@"[HRHTTPClient][TRACE] switchToMode call stack: %@", stack);
    }
    self.authMode = mode;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSString *cleanedURL = [newBaseURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cleanedURL && [cleanedURL length] > 0) {
        if (![cleanedURL hasPrefix:@"http://"] && ![cleanedURL hasPrefix:@"https://"]) {
            cleanedURL = [@"https://" stringByAppendingString:cleanedURL];
        }
        while ([cleanedURL hasSuffix:@"/"]) {
            cleanedURL = [cleanedURL substringToIndex:[cleanedURL length] - 1];
        }
        self.baseURLString = cleanedURL;
    } else {
        if (mode == HRAuthModePersonal) {
            self.baseURLString = [defaults stringForKey:kHRPersonalBaseURLKey] ?: @"https://rezka.fi";
        } else {
            self.baseURLString = [defaults stringForKey:kHRPublicBaseURLKey] ?: @"https://rezka.ag";
        }
    }
    
    [defaults setInteger:self.authMode forKey:kHRStoredAuthModeKey];
    if (mode == HRAuthModePersonal) {
        [defaults setObject:self.baseURLString forKey:kHRPersonalBaseURLKey];
        [defaults setObject:self.baseURLString forKey:@"HR_MIRROR_DOMAIN"];
        self.customUserAgent = kHRPublicUserAgent;
    } else {
        [defaults setObject:self.baseURLString forKey:kHRPublicBaseURLKey];
        [defaults setObject:self.baseURLString forKey:@"HR_MIRROR_DOMAIN"];
        NSString *savedPublicUA = [defaults stringForKey:kHRStoredPublicUAKey];
        self.customUserAgent = (savedPublicUA && [savedPublicUA length] > 0) ? savedPublicUA : kHRPublicUserAgent;
    }
    [defaults synchronize];
    
    if ([defaults boolForKey:@"HR_DEBUG_MODE"]) {
        NSLog(@"[HRHTTPClient] Переключен режим: %ld, URL: %@, UA: %@", (long)self.authMode, self.baseURLString, self.customUserAgent);
        NSLog(@"[HRHTTPClient][TRACE] switchToMode EXIT mode=%ld URL=%@", (long)self.authMode, self.baseURLString);
    }
}

- (void)updatePublicUserAgent:(NSString *)userAgent
{
    if (![userAgent isKindOfClass:[NSString class]]) return;
    if ([userAgent length] == 0) return;
    
    // WK26 может сообщать один и тот же UA многократно. Не записываем его
    // в defaults и не логируем повторно, если значение фактически не изменилось.
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedUA = [defaults stringForKey:kHRStoredPublicUAKey];
    BOOL changed = (savedUA == nil || ![savedUA isEqualToString:userAgent]);
    BOOL clientChanged = (self.customUserAgent == nil || ![self.customUserAgent isEqualToString:userAgent]);
    
    // Храним UA твика отдельно для публичного режима; персональный режим
    // намеренно не переключаем на UA WK26.
    if (self.authMode == HRAuthModePublic) {
        if (clientChanged) self.customUserAgent = userAgent;
        if (changed) {
            [defaults setObject:userAgent forKey:kHRStoredPublicUAKey];
            [defaults synchronize];
        }
    }
    
    if ((changed || clientChanged) && [defaults boolForKey:@"HR_DEBUG_MODE"]) {
        NSLog(@"[HRHTTPClient] User-Agent WK26 %@: %@",
              (changed || clientChanged) ? @"обновлён" : @"не изменился", userAgent);
    }
}

- (void)purgeRezkaCookies
{
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *cookies = [storage cookies];
    NSUInteger count = 0;
    NSURL *baseURL = [NSURL URLWithString:self.baseURLString ?: @"https://rezka.ag"];
    NSString *currentHost = [baseURL.host lowercaseString];
    
    for (NSHTTPCookie *cookie in cookies) {
        NSString *cookieDomain = [cookie.domain lowercaseString];
        if ([cookieDomain rangeOfString:@"rezka"].location != NSNotFound ||
            (currentHost && [cookieDomain rangeOfString:currentHost].location != NSNotFound)) {
            [storage deleteCookie:cookie];
            count++;
        }
    }
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"HR_DEBUG_MODE"]) {
        NSLog(@"[HRHTTPClient] Очищено кук зеркала: %lu", (unsigned long)count);
    }
}

- (void)GET:(NSString *)path
 parameters:(NSDictionary *)parameters
 completion:(HRHTTPClientCompletionBlock)completion
{
    [self performRequestWithMethod:@"GET" path:path parameters:parameters completion:completion];
}

- (void)POST:(NSString *)path
  parameters:(NSDictionary *)parameters
  completion:(HRHTTPClientCompletionBlock)completion
{
    [self performRequestWithMethod:@"POST" path:path parameters:parameters completion:completion];
}

- (void)performRequestWithMethod:(NSString *)method
                            path:(NSString *)path
                      parameters:(NSDictionary *)parameters
                      completion:(HRHTTPClientCompletionBlock)completion
{
    NSString *fullURLString = nil;
    if ([path hasPrefix:@"http://"] || [path hasPrefix:@"https://"]) {
        NSURL *tmp = [NSURL URLWithString:path];
        fullURLString = [NSString stringWithFormat:@"%@%@", self.baseURLString, tmp.path];
        if (tmp.query) {
            fullURLString = [fullURLString stringByAppendingFormat:@"?%@", tmp.query];
        }
    } else {
        NSString *clean = [path hasPrefix:@"/"] ? path : [NSString stringWithFormat:@"/%@", path];
        fullURLString = [NSString stringWithFormat:@"%@%@", self.baseURLString, clean];
    }
    
    NSURL *targetURL = [NSURL URLWithString:fullURLString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:targetURL
                                                           cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                       timeoutInterval:15.0];
    [request setHTTPMethod:method];
    [request setHTTPShouldHandleCookies:YES];
    
    NSString *uaToSend = (self.customUserAgent && [self.customUserAgent length] > 0) ? self.customUserAgent : kHRPublicUserAgent;
    [request setValue:uaToSend forHTTPHeaderField:@"User-Agent"];
    [request setValue:@"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8" forHTTPHeaderField:@"Accept"];
    [request setValue:self.baseURLString forHTTPHeaderField:@"Referer"];
    
    // Подстановка cookies как для текущего целевого URL, так и для всех поддоменов зеркала
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSMutableArray *matched = [NSMutableArray array];
    
    NSArray *urlCookies = [cookieStorage cookiesForURL:targetURL];
    if (urlCookies) {
        [matched addObjectsFromArray:urlCookies];
    }
    
    NSString *targetHost = [targetURL.host lowercaseString];
    for (NSHTTPCookie *c in [cookieStorage cookies]) {
        if (![matched containsObject:c]) {
            NSString *cDomain = [c.domain lowercaseString];
            if ([cDomain rangeOfString:@"rezka"].location != NSNotFound ||
                (targetHost && [cDomain rangeOfString:targetHost].location != NSNotFound)) {
                [matched addObject:c];
            }
        }
    }
    
    if ([matched count] > 0) {
        NSDictionary *headers = [NSHTTPCookie requestHeaderFieldsWithCookies:matched];
        NSString *cookieStr = [headers objectForKey:@"Cookie"];
        if (cookieStr && [cookieStr length] > 0) {
            [request setValue:cookieStr forHTTPHeaderField:@"Cookie"];
        }
    }
    
    if ([method isEqualToString:@"POST"]) {
        [request setValue:@"application/x-www-form-urlencoded; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"XMLHttpRequest" forHTTPHeaderField:@"X-Requested-With"];
        
        NSMutableString *bodyString = [NSMutableString string];
        NSEnumerator *keyEnum = [parameters keyEnumerator];
        NSString *key = nil;
        BOOL isFirst = YES;
        while ((key = [keyEnum nextObject])) {
            NSString *val = [parameters objectForKey:key];
            NSString *escapedVal = [self percentEscapeString:[NSString stringWithFormat:@"%@", val]];
            NSString *escapedKey = [self percentEscapeString:key];
            if (!isFirst) {
                [bodyString appendString:@"&"];
            }
            [bodyString appendFormat:@"%@=%@", escapedKey, escapedVal];
            isFirst = NO;
        }
        
        NSData *bodyData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
        [request setHTTPBody:bodyData];
        [request setValue:[NSString stringWithFormat:@"%lu", (unsigned long)[bodyData length]] forHTTPHeaderField:@"Content-Length"];
    }
    
    [self.networkQueue addOperationWithBlock:^{
        NSURLResponse *response = nil;
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request
                                             returningResponse:&response
                                                         error:&error];
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(data, httpResponse, error);
            }
        });
    }];
}

- (NSString *)percentEscapeString:(NSString *)string
{
    return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(
                                                                                 kCFAllocatorDefault,
                                                                                 (__bridge CFStringRef)string,
                                                                                 NULL,
                                                                                 CFSTR(":/?#[]@!$&'()*+,;="),
                                                                                 kCFStringEncodingUTF8
                                                                                 );
}

- (void)cancelAllRequests
{
    [self.networkQueue cancelAllOperations];
}

@end