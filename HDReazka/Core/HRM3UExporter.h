#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface HRM3UExporter : NSObject <UIDocumentInteractionControllerDelegate>

// Сборка текста #EXTM3U
+ (NSString *)playlistContentForSingleVideoTitle:(NSString *)title
                                       urlString:(NSString *)urlString;

+ (NSString *)playlistContentForSeasonShowTitle:(NSString *)showTitle
                                    seasonTitle:(NSString *)seasonTitle
                                       episodes:(NSArray *)episodes;

// Копирование в системный буфер обмена
+ (BOOL)copySingleVideoToClipboardTitle:(NSString *)title
                              urlString:(NSString *)urlString;

+ (BOOL)copySeasonPlaylistToClipboardTitle:(NSString *)showTitle
                               seasonTitle:(NSString *)seasonTitle
                                  episodes:(NSArray *)episodes;

// Сохранение временного .m3u файла и вызов системного меню «Открыть в...»
- (void)presentOpenInMenuWithContent:(NSString *)content
                       suggestedName:(NSString *)suggestedName
                              inView:(UIView *)view
                        errorHandler:(void (^)(NSString *errorTitle, NSString *errorMessage))errorHandler;

@end