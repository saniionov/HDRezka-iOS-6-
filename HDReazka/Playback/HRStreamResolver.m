#import "HRStreamResolver.h"
#import "HRHTTPClient.h"
#import "HRMovie.h"
#import "HRSeason.h"
#import "HREpisode.h"

@implementation HRStreamResolver

#pragma mark - 1. Полная загрузка и разбор страницы фильма/сериала

+ (void)fetchMoviePageDetails:(HRMovie *)movie
                   completion:(HRMoviePageDetailsCompletionBlock)completion
{
    if (!movie || !movie.detailURLString || [movie.detailURLString length] == 0) {
        if (completion) {
            NSError *err = [NSError errorWithDomain:@"HRStreamResolver" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"Пустой URL карточки фильма"}];
            completion(nil, NO, @[], @[], 0, nil, err);
        }
        return;
    }
    
    [[HRHTTPClient sharedClient] GET:movie.detailURLString parameters:nil completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (error || !data) {
            if (completion) completion(nil, movie.isSeries, @[], @[], 0, nil, error);
            return;
        }
        
        NSString *html = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        if (!html) {
            html = [[NSString alloc] initWithData:data encoding:NSWindowsCP1251StringEncoding];
        }
        if (!html) {
            if (completion) completion(nil, movie.isSeries, @[], @[], 0, nil, nil);
            return;
        }
        
        if (!movie.movieId || [movie.movieId length] == 0) {
            NSRegularExpression *idRegex = [NSRegularExpression regularExpressionWithPattern:@"/(\\d+)-[^/]+\\.html" options:0 error:nil];
            NSTextCheckingResult *idMatch = [idRegex firstMatchInString:movie.detailURLString options:0 range:NSMakeRange(0, [movie.detailURLString length])];
            if (idMatch && idMatch.numberOfRanges > 1) {
                movie.movieId = [movie.detailURLString substringWithRange:[idMatch rangeAtIndex:1]];
            }
        }
        
        NSString *descriptionText = @"Описание отсутствует.";
        NSRange descRange = [html rangeOfString:@"class=\"b-post__description_text\">"];
        if (descRange.location != NSNotFound) {
            NSUInteger start = descRange.location + descRange.length;
            NSRange endRange = [html rangeOfString:@"</div>" options:0 range:NSMakeRange(start, html.length - start)];
            if (endRange.location != NSNotFound) {
                NSString *desc = [html substringWithRange:NSMakeRange(start, endRange.location - start)];
                desc = [desc stringByReplacingOccurrencesOfString:@"<br>" withString:@"\n"];
                desc = [desc stringByReplacingOccurrencesOfString:@"<br/>" withString:@"\n"];
                desc = [desc stringByReplacingOccurrencesOfString:@"<br />" withString:@"\n"];
                NSRegularExpression *stripTags = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>" options:0 error:nil];
                desc = [stripTags stringByReplacingMatchesInString:desc options:0 range:NSMakeRange(0, desc.length) withTemplate:@""];
                descriptionText = [desc stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            }
        }
        
        BOOL isSeries = movie.isSeries;
        if ([html rangeOfString:@"initCDNSeriesEvents"].location != NSNotFound ||
            [html rangeOfString:@"data-season_id="].location != NSNotFound) {
            isSeries = YES;
        } else if ([html rangeOfString:@"initCDNMoviesEvents"].location != NSNotFound) {
            isSeries = NO;
        }
        movie.isSeries = isSeries;
        
        NSMutableArray *translators = [NSMutableArray array];
        NSRegularExpression *transRegex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+data-translator_id=['\"](\\d+)['\"][^>]*>([\\s\\S]*?)</[^>]+>"
                                                                                    options:NSRegularExpressionCaseInsensitive
                                                                                      error:nil];
        NSArray *matches = [transRegex matchesInString:html options:0 range:NSMakeRange(0, html.length)];
        for (NSTextCheckingResult *m in matches) {
            NSString *tId = [html substringWithRange:[m rangeAtIndex:1]];
            NSString *rawTitle = [html substringWithRange:[m rangeAtIndex:2]];
            
            NSRegularExpression *titleAttrRegex = [NSRegularExpression regularExpressionWithPattern:@"title=['\"]([^'\"]+)['\"]" options:0 error:nil];
            NSTextCheckingResult *tm = [titleAttrRegex firstMatchInString:[html substringWithRange:m.range] options:0 range:NSMakeRange(0, m.range.length)];
            
            NSRegularExpression *tagStrip = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>" options:0 error:nil];
            NSString *cleanTitle = [tagStrip stringByReplacingMatchesInString:rawTitle options:0 range:NSMakeRange(0, rawTitle.length) withTemplate:@""];
            cleanTitle = [cleanTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            if ([cleanTitle length] == 0 && tm && tm.numberOfRanges > 1) {
                cleanTitle = [[html substringWithRange:m.range] substringWithRange:[tm rangeAtIndex:1]];
            }
            
            NSInteger currentId = [tId integerValue];
            BOOL exists = NO;
            for (NSDictionary *d in translators) {
                if ([[d objectForKey:@"id"] integerValue] == currentId) {
                    exists = YES;
                    break;
                }
            }
            
            if (!exists) {
                [translators addObject:@{
                 @"id": @(currentId),
                 @"name": ([cleanTitle length] > 0 ? cleanTitle : @"Озвучка")
                 }];
            }
        }
        
        NSInteger defaultTranslatorId = 0;
        NSRegularExpression *jsRegex = [NSRegularExpression regularExpressionWithPattern:@"initCDN(Series|Movies)Events\\s*\\(\\s*(\\d+)\\s*,\\s*(\\d+)"
                                                                                 options:NSRegularExpressionCaseInsensitive
                                                                                   error:nil];
        NSTextCheckingResult *jsMatch = [jsRegex firstMatchInString:html options:0 range:NSMakeRange(0, html.length)];
        if (jsMatch && jsMatch.numberOfRanges > 3) {
            NSString *movieIdFromJS = [html substringWithRange:[jsMatch rangeAtIndex:2]];
            NSString *transIdFromJS = [html substringWithRange:[jsMatch rangeAtIndex:3]];
            if (!movie.movieId || [movie.movieId length] == 0) {
                movie.movieId = movieIdFromJS;
            }
            defaultTranslatorId = [transIdFromJS integerValue];
        } else if ([translators count] > 0) {
            defaultTranslatorId = [[[translators objectAtIndex:0] objectForKey:@"id"] integerValue];
        }
        
        if ([translators count] == 0 && defaultTranslatorId > 0) {
            [translators addObject:@{
             @"id": @(defaultTranslatorId),
             @"name": @"Оригинал / По умолчанию"
             }];
        }
        
        NSArray *seasonsData = [self parseSeasonsFromHTML:html episodesHTML:html];
        if ([seasonsData count] > 0) {
            isSeries = YES;
            movie.isSeries = YES;
        }
        
        NSDictionary *initialStreams = nil;
        NSRegularExpression *streamsInHTMLRegex = [NSRegularExpression regularExpressionWithPattern:@"\"streams\"\\s*:\\s*\"([^\"]+)\""
                                                                                            options:0
                                                                                              error:nil];
        NSTextCheckingResult *streamMatch = [streamsInHTMLRegex firstMatchInString:html options:0 range:NSMakeRange(0, html.length)];
        if (streamMatch && streamMatch.numberOfRanges > 1) {
            NSString *rawStreamStr = [html substringWithRange:[streamMatch rangeAtIndex:1]];
            rawStreamStr = [rawStreamStr stringByReplacingOccurrencesOfString:@"\\/" withString:@"/"];
            NSDictionary *decoded = [self parseStreamsFromRawURLString:rawStreamStr];
            if ([decoded count] > 0) {
                initialStreams = decoded;
            }
        }
        
        if (completion) {
            completion(descriptionText, isSeries, translators, seasonsData, defaultTranslatorId, initialStreams, nil);
        }
    }];
}

#pragma mark - 2. Парсер сезонов и серий из HTML

+ (NSArray *)parseSeasonsFromHTML:(NSString *)seasonsHTML episodesHTML:(NSString *)episodesHTML
{
    NSMutableArray *seasonsData = [NSMutableArray array];
    if (!seasonsHTML) return seasonsData;
    
    NSRegularExpression *seasonRegex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+data-(?:tab|season)(?:_sub)?_id=['\"](\\d+)['\"][^>]*>([\\s\\S]*?)</[^>]+>"
                                                                                 options:NSRegularExpressionCaseInsensitive
                                                                                   error:nil];
    NSArray *seasonMatches = [seasonRegex matchesInString:seasonsHTML options:0 range:NSMakeRange(0, seasonsHTML.length)];
    
    NSMutableDictionary *episodesBySeason = [NSMutableDictionary dictionary];
    if (episodesHTML) {
        NSRegularExpression *epLiRegex = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+data-episode_id=['\"]\\d+['\"][^>]*>([\\s\\S]*?)</[^>]+>"
                                                                                   options:NSRegularExpressionCaseInsensitive
                                                                                     error:nil];
        NSRegularExpression *sIdAttr = [NSRegularExpression regularExpressionWithPattern:@"data-season_id=['\"](\\d+)['\"]" options:0 error:nil];
        NSRegularExpression *eIdAttr = [NSRegularExpression regularExpressionWithPattern:@"data-episode_id=['\"](\\d+)['\"]" options:0 error:nil];
        NSRegularExpression *tagStrip = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>" options:0 error:nil];
        
        NSArray *epMatches = [epLiRegex matchesInString:episodesHTML options:0 range:NSMakeRange(0, episodesHTML.length)];
        for (NSTextCheckingResult *em in epMatches) {
            NSString *fullTag = [episodesHTML substringWithRange:em.range];
            NSString *innerText = [episodesHTML substringWithRange:[em rangeAtIndex:1]];
            
            NSTextCheckingResult *sm = [sIdAttr firstMatchInString:fullTag options:0 range:NSMakeRange(0, fullTag.length)];
            NSTextCheckingResult *epm = [eIdAttr firstMatchInString:fullTag options:0 range:NSMakeRange(0, fullTag.length)];
            
            if (sm && epm) {
                NSInteger sNum = [[fullTag substringWithRange:[sm rangeAtIndex:1]] integerValue];
                NSInteger eNum = [[fullTag substringWithRange:[epm rangeAtIndex:1]] integerValue];
                
                NSString *cleanEpName = [tagStrip stringByReplacingMatchesInString:innerText options:0 range:NSMakeRange(0, innerText.length) withTemplate:@""];
                cleanEpName = [cleanEpName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                
                NSMutableArray *list = [episodesBySeason objectForKey:@(sNum)];
                if (!list) {
                    list = [NSMutableArray array];
                    [episodesBySeason setObject:list forKey:@(sNum)];
                }
                
                BOOL epExists = NO;
                for (NSDictionary *epDict in list) {
                    if ([[epDict objectForKey:@"id"] integerValue] == eNum) {
                        epExists = YES;
                        break;
                    }
                }
                
                if (!epExists) {
                    [list addObject:@{ @"id": @(eNum), @"name": cleanEpName }];
                }
            }
        }
    }
    
    for (NSTextCheckingResult *sm in seasonMatches) {
        NSInteger sId = [[seasonsHTML substringWithRange:[sm rangeAtIndex:1]] integerValue];
        NSString *rawTitle = [seasonsHTML substringWithRange:[sm rangeAtIndex:2]];
        
        NSRegularExpression *tagStrip = [NSRegularExpression regularExpressionWithPattern:@"<[^>]+>" options:0 error:nil];
        NSString *cleanTitle = [tagStrip stringByReplacingMatchesInString:rawTitle options:0 range:NSMakeRange(0, rawTitle.length) withTemplate:@""];
        cleanTitle = [cleanTitle stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        
        if ([cleanTitle length] == 0) {
            cleanTitle = [NSString stringWithFormat:@"Сезон %ld", (long)sId];
        }
        
        NSArray *eps = [episodesBySeason objectForKey:@(sId)];
        if (!eps) eps = @[];
        
        BOOL exists = NO;
        for (NSDictionary *s in seasonsData) {
            if ([[s objectForKey:@"id"] integerValue] == sId) {
                exists = YES;
                break;
            }
        }
        
        if (!exists) {
            [seasonsData addObject:@{
             @"id": @(sId),
             @"title": cleanTitle,
             @"episodes": eps
             }];
        }
    }
    
    return seasonsData;
}

#pragma mark - 3. Запрос потоков и сезонов (AJAX)

+ (void)fetchStreamsForMovieId:(NSString *)movieId
                  translatorId:(NSInteger)translatorId
                        season:(NSInteger)season
                       episode:(NSInteger)episode
                      isSeries:(BOOL)isSeries
                        action:(NSString *)action
                    completion:(HRStreamCompletionBlock)completion
{
    if (!movieId || [movieId length] == 0) {
        if (completion) completion(nil, nil, nil, [NSError errorWithDomain:@"HRStreamResolver" code:-1 userInfo:nil]);
        return;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *favs = [defaults stringForKey:@"HR_AUTH_FAVS"] ?: @"";
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:movieId forKey:@"id"];
    [params setObject:@(translatorId) forKey:@"translator_id"];
    [params setObject:favs forKey:@"favs"];
    [params setObject:action forKey:@"action"];
    
    if (isSeries) {
        if (season > 0) [params setObject:@(season) forKey:@"season"];
        if (episode > 0) [params setObject:@(episode) forKey:@"episode"];
    }
    
    NSString *ajaxPath = @"/ajax/get_cdn_series/";
    
    [[HRHTTPClient sharedClient] POST:ajaxPath parameters:params completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        if (error || !data) {
            if (completion) completion(nil, nil, nil, error);
            return;
        }
        
        NSError *jsonErr = nil;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        
        if (jsonErr || !json || ![json isKindOfClass:[NSDictionary class]]) {
            if (completion) completion(nil, nil, nil, [NSError errorWithDomain:@"HRStreamResolver" code:-2 userInfo:@{NSLocalizedDescriptionKey: @"Некорректный ответ сервера (возможно сработала защита)."}]);
            return;
        }
        
        BOOL success = [[json objectForKey:@"success"] boolValue];
        if (!success) {
            if (completion) completion(nil, nil, nil, [NSError errorWithDomain:@"HRStreamResolver" code:-3 userInfo:@{NSLocalizedDescriptionKey: @"Сервер вернул success=false"}]);
            return;
        }
        
        NSString *urlStr = [json objectForKey:@"url"];
        NSString *subStr = [json objectForKey:@"subtitle"];
        NSString *episodesHTML = [json objectForKey:@"episodes"];
        NSString *seasonsHTML = [json objectForKey:@"seasons"];
        
        NSDictionary *streams = [self parseStreamsFromRawURLString:urlStr];
        NSArray *updatedSeasons = nil;
        
        if (isSeries && (seasonsHTML || episodesHTML)) {
            updatedSeasons = [self parseSeasonsFromHTML:seasonsHTML episodesHTML:episodesHTML];
        }
        
        if (completion) completion(streams, subStr, updatedSeasons, nil);
    }];
}

#pragma mark - 4. Получение полного сезона (для скачивания / M3U)

+ (void)fetchSeasonEpisodeStreamsForMovieId:(NSString *)movieId
                               translatorId:(NSInteger)translatorId
                                     season:(NSInteger)season
                               episodesList:(NSArray *)episodesList
                           preferredQuality:(NSString *)preferredQuality
                                 completion:(void (^)(NSArray *resolvedEpisodes))completion
{
    if (!episodesList || [episodesList count] == 0) {
        if (completion) completion(nil);
        return;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *favs = [defaults stringForKey:@"HR_AUTH_FAVS"] ?: @"";
    
    NSMutableArray *results = [NSMutableArray array];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 2;
    
    __block NSInteger completedCount = 0;
    
    for (NSDictionary *epData in episodesList) {
        NSInteger epId = [[epData objectForKey:@"id"] integerValue];
        NSString *epName = [epData objectForKey:@"name"];
        
        [queue addOperationWithBlock:^{
            dispatch_semaphore_t sema = dispatch_semaphore_create(0);
            
            NSDictionary *params = @{
                                     @"id": movieId,
                                     @"translator_id": @(translatorId),
                                     @"season": @(season),
                                     @"episode": @(epId),
                                     @"favs": favs,
                                     @"action": @"get_stream"
                                     };
            
            [[HRHTTPClient sharedClient] POST:@"/ajax/get_cdn_series/" parameters:params completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
                if (data && !error) {
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    if ([[json objectForKey:@"success"] boolValue]) {
                        NSString *urlStr = [json objectForKey:@"url"];
                        NSDictionary *streams = [self parseStreamsFromRawURLString:urlStr];
                        if (streams && [streams count] > 0) {
                            NSString *targetQ = [self bestQualityKeyFromStreams:streams preferredQuality:preferredQuality];
                            NSString *targetURL = [streams objectForKey:targetQ];
                            
                            if (targetURL) {
                                @synchronized (results) {
                                    [results addObject:@{
                                     @"episode": @(epId),
                                     @"title": epName ?: [NSString stringWithFormat:@"Серия %ld", (long)epId],
                                     @"url": targetURL
                                     }];
                                }
                            }
                        }
                    }
                }
                
                @synchronized (results) {
                    completedCount++;
                    if (completedCount == [episodesList count]) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            NSArray *sorted = [results sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
                                NSInteger e1 = [[obj1 objectForKey:@"episode"] integerValue];
                                NSInteger e2 = [[obj2 objectForKey:@"episode"] integerValue];
                                if (e1 < e2) return NSOrderedAscending;
                                if (e1 > e2) return NSOrderedDescending;
                                return NSOrderedSame;
                            }];
                            if (completion) completion(sorted);  
                        });  
                    }  
                }  
                dispatch_semaphore_signal(sema);  
            }];  
            
            dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC));  
        }];  
    }  
}  

#pragma mark - Вспомогательные парсеры URL  

+ (NSDictionary *)parseStreamsFromRawURLString:(NSString *)rawString  
{  
    NSMutableDictionary *result = [NSMutableDictionary dictionary];  
    if (!rawString || [rawString length] == 0) return result;  
    
    NSString *trashPattern = @"\\/\\/([a-zA-Z0-9]{2,10})\\.([a-zA-Z0-9]{2,10})\\.([a-zA-Z0-9]{2,10})\\.([a-zA-Z0-9]{2,10})\\/";  
    NSString *cleanString = [self removeTrashStrings:rawString usingPattern:trashPattern];  
    
    NSArray *parts = [cleanString componentsSeparatedByString:@","];  
    for (NSString *part in parts) {  
        NSArray *kv = [part componentsSeparatedByString:@"]"];  
        if ([kv count] == 2) {  
            NSString *qRaw = [kv objectAtIndex:0];  
            NSString *uRaw = [kv objectAtIndex:1];  
            
            NSString *quality = [qRaw stringByReplacingOccurrencesOfString:@"[" withString:@""];  
            quality = [quality stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];  
            
            NSArray *allowedQualities = @[@"360p", @"480p", @"720p", @"1080p"];  
            if (![allowedQualities containsObject:quality]) {  
                continue;  
            }  
            
            NSArray *urls = [uRaw componentsSeparatedByString:@" or "];  
            NSString *finalURL = nil;  
            if ([urls count] > 0) {  
                finalURL = [urls objectAtIndex:0];  
            }  
            finalURL = [finalURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];  
            
            // ВАЖНО: iOS 6 MPMoviePlayerController не может играть видео по современному HTTPS.  
            // Мы принудительно переключаем поток на HTTP!  
            if ([finalURL hasPrefix:@"//"]) {  
                finalURL = [@"http:" stringByAppendingString:finalURL];  
            } else if ([finalURL hasPrefix:@"https://"]) {  
                finalURL = [finalURL stringByReplacingOccurrencesOfString:@"https://" withString:@"http://"];  
            }  
            
            if (quality && finalURL) {  
                [result setObject:finalURL forKey:quality];  
            }  
        }  
    }  
    
    return result;  
}  

+ (NSString *)removeTrashStrings:(NSString *)input usingPattern:(NSString *)pattern  
{  
    if (!input || [input length] == 0) return input;  
    if ([input rangeOfString:@"#h"].location == NSNotFound) return input;  
    
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];  
    NSMutableString *mutableInput = [input mutableCopy];  
    
    while (YES) {  
        NSRange searchRange = NSMakeRange(0, mutableInput.length);  
        NSTextCheckingResult *match = [regex firstMatchInString:mutableInput options:0 range:searchRange];  
        if (!match) break;  
        
        NSString *trashPart = [mutableInput substringWithRange:match.range];  
        NSString *replacement = [self decodeTrashString:trashPart];  
        [mutableInput replaceCharactersInRange:match.range withString:replacement];  
    }  
    
    NSString *clean = [mutableInput stringByReplacingOccurrencesOfString:@"//_//" withString:@"//"];  
    return clean;  
}  

+ (NSString *)decodeTrashString:(NSString *)trash  
{  
    NSString *clean = [trash stringByReplacingOccurrencesOfString:@"/" withString:@""];  
    clean = [clean stringByReplacingOccurrencesOfString:@"." withString:@""];  
    
    if ([clean length] == 0) return @"";  
    
    NSString *plistStr = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\"><plist version=\"1.0\"><data>%@</data></plist>", clean];  
    NSData *plistData = [plistStr dataUsingEncoding:NSUTF8StringEncoding];  
    
    NSData *data = [NSPropertyListSerialization propertyListFromData:plistData  
                                                    mutabilityOption:NSPropertyListImmutable  
                                                              format:NULL  
                                                    errorDescription:NULL];  
    if (!data) return @"";  
    
    NSString *decoded = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];  
    return decoded ?: @"";  
}  

+ (NSString *)bestQualityKeyFromStreams:(NSDictionary *)streams preferredQuality:(NSString *)preferred  
{  
    if (!streams || [streams count] == 0) return nil;  
    if (preferred && [streams objectForKey:preferred]) {  
        return preferred;  
    }  
    
    NSArray *order = @[@"1080p", @"720p", @"480p", @"360p"];  
    
    if (preferred) {  
        NSUInteger pIdx = [order indexOfObject:preferred];  
        if (pIdx != NSNotFound) {  
            for (NSUInteger i = pIdx; i < [order count]; i++) {  
                NSString *q = [order objectAtIndex:i];  
                if ([streams objectForKey:q]) return q;  
            }  
        }  
    }  
    
    for (NSString *q in order) {  
        if ([streams objectForKey:q]) return q;  
    }  
    
    for (NSString *key in [streams allKeys]) {  
        return key;  
    }  
    return nil;  
}  

@end  
