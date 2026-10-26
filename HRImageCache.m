#import "HRImageCache.h"
#import "HRHTTPClient.h"

@interface HRImageCache ()
@property (nonatomic, strong) NSCache *memoryCache;
@property (nonatomic, strong) NSOperationQueue *downloadQueue;
@end

@implementation HRImageCache

+ (instancetype)sharedCache
{
    static HRImageCache *_instance = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        _instance = [[HRImageCache alloc] init];
    });
    
    return _instance;
}

- (id)init
{
    self = [super init];
    
    if (self) {
        _memoryCache = [[NSCache alloc] init];
        [_memoryCache setCountLimit:120];
        
        _downloadQueue = [[NSOperationQueue alloc] init];
        [_downloadQueue setMaxConcurrentOperationCount:4];
    }
    
    return self;
}

- (NSString *)normalizeURLString:(NSString *)urlString
{
    if (!urlString || [urlString length] == 0) {
        return @"";
    }
    
    NSString *clean = [urlString stringByTrimmingCharactersInSet:
                       [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if ([clean hasPrefix:@"//"]) {
        return [NSString stringWithFormat:@"https:%@", clean];
    }
    
    if ([clean hasPrefix:@"/"]) {
        NSString *base = [HRHTTPClient sharedClient].baseURLString;
        
        if (!base || [base length] == 0) {
            base = @"https://rezka.fi";
        }
        
        return [NSString stringWithFormat:@"%@%@", base, clean];
    }
    
    if (![clean hasPrefix:@"http://"] &&
        ![clean hasPrefix:@"https://"]) {
        return [NSString stringWithFormat:@"https://%@", clean];
    }
    
    return clean;
}

- (void)loadImageForURLString:(NSString *)rawURLString
                   completion:(void (^)(UIImage *image))completion
{
    NSString *urlString = [self normalizeURLString:rawURLString];
    
    if ([urlString length] == 0) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(nil);
            });
        }
        return;
    }
    
    // 1. Поиск изображения в оперативной памяти
    UIImage *memImage = [self.memoryCache objectForKey:urlString];
    
    if (memImage) {
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(memImage);
            });
        }
        return;
    }
    
    // 2. Загрузка изображения в фоновой очереди
    [self.downloadQueue addOperationWithBlock:^{
        
        NSURL *url = [NSURL URLWithString:urlString];
        
        if (!url) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(nil);
                }
            });
            return;
        }
        
        NSMutableURLRequest *req =
        [NSMutableURLRequest requestWithURL:url
                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                            timeoutInterval:10.0];
        
        [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 6_1_3 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10B326 Safari/8536.25"
   forHTTPHeaderField:@"User-Agent"];
        
        [req setValue:@"image/jpeg,image/png,image/*;q=0.8"
   forHTTPHeaderField:@"Accept"];
        
        NSURLResponse *response = nil;
        NSError *error = nil;
        
        NSData *data = [NSURLConnection sendSynchronousRequest:req
                                             returningResponse:&response
                                                         error:&error];
        
        // 3. Проверка загруженных данных
        if (data && [data length] > 0) {
            UIImage *img = [UIImage imageWithData:data];
            
            if (img) {
                [self.memoryCache setObject:img forKey:urlString];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (completion) {
                        completion(img);
                    }
                });
                
                return;
            }
        }
        
        // 4. Ошибка загрузки: возвращаем nil
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(nil);
            }
        });
    }];
}

- (void)clearCache
{
    [self.memoryCache removeAllObjects];
}

@end