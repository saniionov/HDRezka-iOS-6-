#import "HRM3UExporter.h"

@interface HRM3UExporter ()
@property (nonatomic, strong) UIDocumentInteractionController *documentInteractionController;
@end

@implementation HRM3UExporter

+ (NSString *)playlistContentForSingleVideoTitle:(NSString *)title
                                       urlString:(NSString *)urlString
{
    if (![urlString isKindOfClass:[NSString class]] || [urlString length] == 0) {
        return nil;
    }
    NSString *safeTitle = ([title isKindOfClass:[NSString class]] && [title length] > 0) ? title : @"Видео";
    return [NSString stringWithFormat:@"#EXTM3U\n#EXTINF:-1,%@\n%@\n", safeTitle, urlString];
}

+ (NSString *)playlistContentForSeasonShowTitle:(NSString *)showTitle
                                    seasonTitle:(NSString *)seasonTitle
                                       episodes:(NSArray *)episodes
{
    if (![episodes isKindOfClass:[NSArray class]] || [episodes count] == 0) {
        return nil;
    }
    
    NSString *safeShow = ([showTitle isKindOfClass:[NSString class]] && [showTitle length] > 0) ? showTitle : @"Видео";
    NSString *safeSeason = ([seasonTitle isKindOfClass:[NSString class]] && [seasonTitle length] > 0) ? seasonTitle : @"Сезон";
    
    NSMutableString *m3u = [NSMutableString stringWithString:@"#EXTM3U\n"];
    NSUInteger validCount = 0;
    
    for (NSDictionary *ep in episodes) {
        NSString *epName = [ep objectForKey:@"title"] ?: @"Серия";
        NSString *epURL = [ep objectForKey:@"url"] ?: @"";
        if ([epURL length] > 0) {
            [m3u appendFormat:@"#EXTINF:-1,%@ - %@ (%@)\n%@\n", safeShow, safeSeason, epName, epURL];
            validCount++;
        }
    }
    
    return (validCount > 0) ? m3u : nil;
}

+ (BOOL)copySingleVideoToClipboardTitle:(NSString *)title
                              urlString:(NSString *)urlString
{
    NSString *content = [self playlistContentForSingleVideoTitle:title urlString:urlString];
    if (!content) return NO;
    [UIPasteboard generalPasteboard].string = content;
    return YES;
}

+ (BOOL)copySeasonPlaylistToClipboardTitle:(NSString *)showTitle
                               seasonTitle:(NSString *)seasonTitle
                                  episodes:(NSArray *)episodes
{
    NSString *content = [self playlistContentForSeasonShowTitle:showTitle seasonTitle:seasonTitle episodes:episodes];
    if (!content) return NO;
    [UIPasteboard generalPasteboard].string = content;
    return YES;
}

- (void)presentOpenInMenuWithContent:(NSString *)content
                       suggestedName:(NSString *)suggestedName
                              inView:(UIView *)view
                        errorHandler:(void (^)(NSString *errorTitle, NSString *errorMessage))errorHandler
{
    if (![content isKindOfClass:[NSString class]] || [content length] == 0) {
        if (errorHandler) {
            errorHandler(@"Ошибка", @"Плейлист пустой — нечего передавать.");
        }
        return;
    }
    
    NSString *safeName = [suggestedName stringByReplacingOccurrencesOfString:@"/" withString:@"-"];
    safeName = [safeName stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    if (!safeName || [safeName length] == 0) {
        safeName = @"playlist";
    }
    if (![safeName hasSuffix:@".m3u"]) {
        safeName = [safeName stringByAppendingString:@".m3u"];
    }
    
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:safeName];
    NSError *writeError = nil;
    if (![content writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:&writeError]) {
        if (errorHandler) {
            errorHandler(@"Ошибка", @"Не удалось создать файл плейлиста.");
        }
        return;
    }
    
    NSURL *fileURL = [NSURL fileURLWithPath:path];
    self.documentInteractionController = [UIDocumentInteractionController interactionControllerWithURL:fileURL];
    self.documentInteractionController.delegate = self;
    
    // Небольшая центральная область-якорь предотвращает ошибки позиционирования UIPopoverController на iPad
    CGRect bounds = view.bounds;
    CGRect anchorRect = CGRectMake(CGRectGetMidX(bounds), CGRectGetMidY(bounds), 1.0f, 1.0f);
    
    BOOL shown = [self.documentInteractionController presentOpenInMenuFromRect:anchorRect
                                                                        inView:view
                                                                      animated:YES];
    if (!shown && errorHandler) {
        errorHandler(@"Нет подходящего приложения",
                     @"iOS не нашла приложение, зарегистрированное для открытия файла M3U. Проверь, поддерживает ли установленный плеер импорт M3U-файлов через меню «Открыть в…». Файл плейлиста создан во временной папке приложения.");
    }
}

@end