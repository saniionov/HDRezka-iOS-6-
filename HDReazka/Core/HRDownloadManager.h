#import <Foundation/Foundation.h>
#import "HRDownloadTask.h"

#define kHRDownloadProgressNotification @"kHRDownloadProgressNotification"
#define kHRDownloadFinishedNotification @"kHRDownloadFinishedNotification"

typedef NS_ENUM(NSInteger, HRDownloadIndicatorState) {
    HRDownloadIndicatorStateIdle = 0,       // Серый (нет активных закачек и ошибок)
    HRDownloadIndicatorStateDownloading = 1, // Зелёный (идёт скачивание)
    HRDownloadIndicatorStateFailed = 2       // Красный (ошибка скачивания)
};

@interface HRDownloadManager : NSObject

+ (HRDownloadManager *)sharedManager;

@property (nonatomic, strong, readonly) NSArray *tasks;
@property (nonatomic, assign, readonly) HRDownloadIndicatorState indicatorState;

// Добавление задачи на скачивание
- (void)downloadMovieTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                 urlString:(NSString *)urlString
                    taskId:(NSString *)taskId;

// Управление задачей
- (void)pauseTask:(HRDownloadTask *)task;
- (void)resumeTask:(HRDownloadTask *)task;
- (void)cancelTask:(HRDownloadTask *)task;

// Массовое управление очередью (НОВЫЕ КНОПКИ)
- (void)pauseAllTasks;
- (void)resumeAllTasks;

// Экспорт M3U-плейлистов в системный буфер обмена
- (void)copySingleVideoToClipboardTitle:(NSString *)title urlString:(NSString *)urlString;
- (void)copySeasonPlaylistToClipboardTitle:(NSString *)showTitle
                               seasonTitle:(NSString *)seasonTitle
                                  episodes:(NSArray *)episodes;

// Удалить все загрузки
- (BOOL)clearAllDownloads;

// Папка с загрузками в Documents
- (NSString *)downloadsDirectory;

@end