#import "HRHTTPClient.h"
#import "HRDatabase.h"
#import "HRDownloadManager.h"
#import "HRImageCache.h"

static NSString * const kHRStoredAuthModeKey = @"HRStoredAuthModeKey";
NSString * const kHRPersonalBaseURLKey = @"HR_PERSONAL_MIRROR_DOMAIN";
NSString * const kHRPublicBaseURLKey = @"HR_PUBLIC_MIRROR_DOMAIN";
static NSString * const kHRStoredPublicUAKey = @"HR_STORED_PUBLIC_USER_AGENT";

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
        _networkQueue.maxConcurrentOperationCount = 1;
        
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
    NSUserDefaults *debugDefaults = [NSUserDefaults standardUserDefaults];
    if ([debugDefaults boolForKey:@"HR_DEBUG_MODE"]) {
        NSLog(@"[HRHTTPClient][TRACE] switchToMode ENTER oldMode=%ld oldURL=%@ oldUA=%@ newMode=%ld requestedURL=%@",
              (long)self.authMode, self.baseURLString, self.customUserAgent,
              (long)mode, newBaseURL);
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
    }
}

- (void)updatePublicUserAgent:(NSString *)userAgent
{
    if (![userAgent isKindOfClass:[NSString class]]) return;
    if ([userAgent length] == 0) return;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *savedUA = [defaults stringForKey:kHRStoredPublicUAKey];
    BOOL changed = (savedUA == nil || ![savedUA isEqualToString:userAgent]);
    BOOL clientChanged = (self.customUserAgent == nil || ![self.customUserAgent isEqualToString:userAgent]);
    
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

#pragma mark - Безопасная проверка доменов Cookie

- (BOOL)isCookieDomain:(NSString *)cookieDomain matchesHost:(NSString *)host
{
    if (!cookieDomain || !host) return NO;
    
    NSString *cDomain = [cookieDomain lowercaseString];
    NSString *tHost = [host lowercaseString];
    
    // Убираем ведущую точку у cookie domain (.rezka.ag -> rezka.ag)
    if ([cDomain hasPrefix:@"."]) {
        cDomain = [cDomain substringFromIndex:1];
    }
    
    // Точное совпадение
    if ([tHost isEqualToString:cDomain]) {
        return YES;
    }
    
    // Проверка на поддомен (например, mirror.rezka.ag оканчивается на .rezka.ag)
    NSString *dotDomain = [@"." stringByAppendingString:cDomain];
    if ([tHost hasSuffix:dotDomain]) {
        return YES;
    }
    
    return NO;
}

- (void)purgeRezkaCookies
{
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSArray *cookies = [storage cookies];
    NSUInteger count = 0;
    NSURL *baseURL = [NSURL URLWithString:self.baseURLString ?: @"https://rezka.ag"];
    NSString *currentHost = [baseURL.host lowercaseString];
    
    for (NSHTTPCookie *cookie in cookies) {
        if ([self isCookieDomain:cookie.domain matchesHost:currentHost]) {
            [storage deleteCookie:cookie];
            count++;
        }
    }
    
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"HR_DEBUG_MODE"]) {
        NSLog(@"[HRHTTPClient] Очищено кук зеркала: %lu", (unsigned long)count);
    }
}

#pragma mark - Авторизация и управление сессией

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

- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
               completion:(void (^)(BOOL success, NSError *error))completion
{
    NSString *cleanLogin = [username stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!cleanLogin || [cleanLogin length] == 0 || !password || [password length] == 0) {
        if (completion) {
            completion(NO, nil);
        }
        return;
    }
    
    NSDictionary *params = @{
                             @"login_name": cleanLogin,
                             @"login_password": password,
                             @"login_not_save": @"0"
                             };
    
    [self POST:@"/ajax/login/" parameters:params completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (error || !data) {
            if (completion) {
                completion(NO, error);
            }
            return;
        }
        
        NSError *jsonErr = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        BOOL ok = [[json objectForKey:@"success"] boolValue];
        if (completion) {
            completion(ok, nil);
        }
    }];
}

#pragma mark - Сервисные методы сброса данных

- (void)performAuthReset
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"HR_AUTH_LOGIN"];
    [defaults removeObjectForKey:@"HR_AUTH_PASSWORD"];
    [defaults synchronize];
    
    [self purgeRezkaCookies];
}

- (BOOL)performFullApplicationResetWithErrorMessage:(NSString **)outErrorMessage
{
    // 1. Закрываем SQLite перед удалением файла базы
    HRDatabase *database = [HRDatabase sharedDatabase];
    if (![database closeDatabase]) {
        if (outErrorMessage) {
            *outErrorMessage = @"Не удалось безопасно закрыть базу данных. Повторите попытку после перезапуска приложения.";
        }
        return NO;
    }
    
    // 2. Останавливаем активные загрузки и удаляем папку загрузок
    if (![[HRDownloadManager sharedManager] clearAllDownloads]) {
        [database setupDatabase];
        if (outErrorMessage) {
            *outErrorMessage = @"Не удалось безопасно очистить загрузки. База данных оставлена без изменений; попробуйте ещё раз.";
        }
        return NO;
    }
    
    // 3. Удаляем файл базы данных SQLite
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *docDir = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
    NSString *dbPath = [docDir stringByAppendingPathComponent:@"hdrezka_storage.sqlite"];
    
    NSError *dbError = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:dbPath] &&
        ![fileManager removeItemAtPath:dbPath error:&dbError]) {
        [database setupDatabase];
        if (outErrorMessage) {
            *outErrorMessage = @"Не удалось удалить файл базы данных. Загрузки уже остановлены и очищены; остальные настройки и авторизация сохранены.";
        }
        return NO;
    }
    
    // 4. Переоткрываем чистую базу данных
    [database setupDatabase];
    
    // 5. Очищаем NSUserDefaults
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (appDomain) {
        [defaults removePersistentDomainForName:appDomain];
    }
    [defaults synchronize];
    
    // 6. Очищаем все cookies и кэш изображений
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    for (NSHTTPCookie *cookie in [storage cookies]) {
        [storage deleteCookie:cookie];
    }
    
    [[HRImageCache sharedCache] clearCache];
    
    // 7. Восстанавливаем дефолтное состояние клиента
    self.authMode = HRAuthModePersonal;
    self.baseURLString = @"https://rezka.fi";
    self.customUserAgent = kHRPublicUserAgent;
    
    return YES;
}

#pragma mark - Выполнение сетевых запросов

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
        NSString *base = self.baseURLString;
        while ([base hasSuffix:@"/"]) {
            base = [base substringToIndex:[base length] - 1];
        }
        NSString *clean = [path hasPrefix:@"/"] ? path : [NSString stringWithFormat:@"/%@", path];
        fullURLString = [NSString stringWithFormat:@"%@%@", base, clean];
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
    
    NSHTTPCookieStorage *cookieStorage = [NSHTTPCookieStorage sharedHTTPCookieStorage];
    NSMutableArray *matched = [NSMutableArray array];
    
    NSArray *urlCookies = [cookieStorage cookiesForURL:targetURL];
    if (urlCookies) {
        [matched addObjectsFromArray:urlCookies];
    }
    
    NSString *targetHost = [targetURL.host lowercaseString];
    for (NSHTTPCookie *c in [cookieStorage cookies]) {
        if (![matched containsObject:c]) {
            if ([self isCookieDomain:c.domain matchesHost:targetHost]) {
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
    // Добавлен знак '%' в список обязательного экранирования для безопасности form-urlencoded
    return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(
                                                                                 kCFAllocatorDefault,
                                                                                 (__bridge CFStringRef)string,
                                                                                 NULL,
                                                                                 CFSTR("%:/?#[]@!$&'()*+,;="),
                                                                                 kCFStringEncodingUTF8
                                                                                 );
}

- (void)cancelAllRequests
{
    [self.networkQueue cancelAllOperations];
}

@end