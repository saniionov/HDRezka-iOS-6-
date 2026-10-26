#import <Foundation/Foundation.h>
#import "HRDownloadTask.h"

#define kHRDownloadProgressNotification @"kHRDownloadProgressNotification"
#define kHRDownloadFinishedNotification @"kHRDownloadFinishedNotification"

@interface HRDownloadManager : NSObject

+ (HRDownloadManager *)sharedManager;

@property (nonatomic, strong, readonly) NSArray *tasks;

// Добавление задачи на скачивание
- (void)downloadMovieTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                 urlString:(NSString *)urlString
                    taskId:(NSString *)taskId;

// Управление задачей
- (void)pauseTask:(HRDownloadTask *)task;
- (void)resumeTask:(HRDownloadTask *)task;
- (void)cancelTask:(HRDownloadTask *)task;

// Экспорт M3U-плейлистов в системный буфер обмена
- (void)copySingleVideoToClipboardTitle:(NSString *)title urlString:(NSString *)urlString;
- (void)copySeasonPlaylistToClipboardTitle:(NSString *)showTitle
                               seasonTitle:(NSString *)seasonTitle
                                  episodes:(NSArray *)episodes; // Массив NSDictionary @{@"title": @"", @"url": @""}

// Удалить все загрузки, остановив активные соединения и закрыв файлы.
- (BOOL)clearAllDownloads;

// Папка с загрузками в Documents
- (NSString *)downloadsDirectory;

@end