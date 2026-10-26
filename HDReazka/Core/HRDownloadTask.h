#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, HRDownloadStatus) {
    HRDownloadStatusWaiting = 0,
    HRDownloadStatusDownloading,
    HRDownloadStatusPaused,
    HRDownloadStatusFinished,
    HRDownloadStatusFailed
};

@interface HRDownloadTask : NSObject

@property (nonatomic, copy) NSString *taskId;         // Уникальный ID ("movie_1234_s1_e2")
@property (nonatomic, copy) NSString *title;          // Название фильма / сериала
@property (nonatomic, copy) NSString *subtitle;       // "Сезон 1, Серия 2 (Дубляж)"
@property (nonatomic, copy) NSString *remoteURLString;// Прямая ссылка на MP4
@property (nonatomic, copy) NSString *localFilePath;  // Путь сохранения на накопителе
@property (nonatomic, assign) HRDownloadStatus status;
@property (nonatomic, assign) long long totalBytes;
@property (nonatomic, assign) long long downloadedBytes;
@property (nonatomic, assign) float progress;         // 0.0 .. 1.0

@end