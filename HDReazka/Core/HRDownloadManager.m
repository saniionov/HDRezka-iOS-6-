#import "HRDownloadManager.h"
#import <UIKit/UIKit.h>
#import <dlfcn.h>

typedef int32_t  IOReturn;
typedef uint32_t IOPMAssertionID;
typedef uint32_t IOPMAssertionLevel;

#define kIOPMAssertionTypePreventUserIdleSystemSleep CFSTR("PreventUserIdleSystemSleep")
#define kIOPMAssertionLevelOn 255

static IOReturn (*pfn_IOPMAssertionCreateWithName)(CFStringRef, IOPMAssertionLevel, CFStringRef, IOPMAssertionID *) = NULL;
static IOReturn (*pfn_IOPMAssertionRelease)(IOPMAssertionID) = NULL;

@interface HRDownloadManager () <NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSMutableArray *internalTasks;
@property (nonatomic, strong) NSMutableDictionary *activeConnections; // taskId -> NSURLConnection
@property (nonatomic, strong) NSMutableDictionary *fileHandles;       // taskId -> NSFileHandle
@property (nonatomic, assign) IOPMAssertionID powerAssertion;
@property (nonatomic, assign) UIBackgroundTaskIdentifier bgTask;

@end

@implementation HRDownloadManager

+ (HRDownloadManager *)sharedManager
{
    static HRDownloadManager *_instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[HRDownloadManager alloc] init];
    });
    return _instance;
}

- (id)init
{
    self = [super init];
    if (self) {
        _internalTasks = [[NSMutableArray alloc] init];
        _activeConnections = [[NSMutableDictionary alloc] init];
        _fileHandles = [[NSMutableDictionary alloc] init];
        _powerAssertion = 0;
        _bgTask = UIBackgroundTaskInvalid;
        
        NSString *dir = [self downloadsDirectory];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
        }
        
        // Восстанавливаем ранее скачанные файлы с диска
        [self restoreExistingDownloads];
    }
    return self;
}

- (void)restoreExistingDownloads
{
    NSString *dir = [self downloadsDirectory];
    NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dir error:nil];
    for (NSString *fileName in files) {
        if ([fileName hasSuffix:@".mp4"]) {
            NSString *fullPath = [dir stringByAppendingPathComponent:fileName];
            NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:nil];
            long long fileSize = [[attrs objectForKey:NSFileSize] longLongValue];
            if (fileSize > 0) {
                HRDownloadTask *task = [[HRDownloadTask alloc] init];
                task.taskId = [fileName stringByDeletingPathExtension];
                task.title = task.taskId;
                task.subtitle = @"Локальный файл";
                task.localFilePath = fullPath;
                task.downloadedBytes = fileSize;
                task.totalBytes = fileSize;
                task.progress = 1.0f;
                task.status = HRDownloadStatusFinished;
                [_internalTasks addObject:task];
            }
        }
    }
}

- (NSArray *)tasks
{
    return [self.internalTasks copy];
}

- (NSString *)downloadsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Downloads"];
}

// Вызывается из UI-потока при полном сбросе приложения.
// Сначала разрываем связи с соединениями, чтобы отложенные delegate-callbacks
// после cancel не нашли уже удалённые задачи и файловые дескрипторы.
- (BOOL)clearAllDownloads
{
    NSArray *connections = [[self.activeConnections allValues] copy];
    [self.activeConnections removeAllObjects];
    for (NSURLConnection *connection in connections) {
        [connection cancel];
    }
    
    NSArray *handles = [[self.fileHandles allValues] copy];
    [self.fileHandles removeAllObjects];
    for (NSFileHandle *handle in handles) {
        @try {
            [handle closeFile];
        }
        @catch (NSException *exception) {
            // Продолжаем очистку остальных файлов; дескриптор уже недоступен менеджеру.
        }
    }
    
    [self.internalTasks removeAllObjects];
    [self updatePowerAssertionState];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *directory = [self downloadsDirectory];
    NSError *error = nil;
    
    if ([fileManager fileExistsAtPath:directory] &&
        ![fileManager removeItemAtPath:directory error:&error]) {
        NSLog(@"[HRDownloadManager] Не удалось удалить каталог загрузок: %@", error);
        [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadProgressNotification object:nil];
        return NO;
    }
    
    error = nil;
    if (![fileManager createDirectoryAtPath:directory
                withIntermediateDirectories:YES
                                 attributes:nil
                                      error:&error]) {
        NSLog(@"[HRDownloadManager] Не удалось создать каталог загрузок: %@", error);
        [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadProgressNotification object:nil];
        return NO;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadProgressNotification object:nil];
    return YES;
}

#pragma mark - Удержание питания (IOKit + UIBackgroundTask)

- (void)updatePowerAssertionState
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *iokitHandle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
        if (!iokitHandle) {
            iokitHandle = dlopen(NULL, RTLD_NOW);
        }
        if (iokitHandle) {
            pfn_IOPMAssertionCreateWithName = (IOReturn (*)(CFStringRef, IOPMAssertionLevel, CFStringRef, IOPMAssertionID *))dlsym(iokitHandle, "IOPMAssertionCreateWithName");
            pfn_IOPMAssertionRelease = (IOReturn (*)(IOPMAssertionID))dlsym(iokitHandle, "IOPMAssertionRelease");
        }
    });
    
    BOOL hasActive = NO;
    for (HRDownloadTask *task in self.internalTasks) {
        if (task.status == HRDownloadStatusDownloading) {
            hasActive = YES;
            break;
        }
    }
    
    if (hasActive) {
        if (self.bgTask == UIBackgroundTaskInvalid) {
            self.bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                [[UIApplication sharedApplication] endBackgroundTask:self.bgTask];
                self.bgTask = UIBackgroundTaskInvalid;
            }];
        }
        if (self.powerAssertion == 0 && pfn_IOPMAssertionCreateWithName != NULL) {
            CFStringRef reason = CFSTR("HDRezka Background Video Download");
            IOPMAssertionID newAssertion = 0;
            IOReturn ret = pfn_IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep,
                                                           kIOPMAssertionLevelOn,
                                                           reason,
                                                           &newAssertion);
            if (ret == 0) {
                self.powerAssertion = newAssertion;
                NSLog(@"[IOKit] Сон системы заблокирован для фоновой загрузки.");
            }
        }
    } else {
        if (self.powerAssertion != 0 && pfn_IOPMAssertionRelease != NULL) {
            pfn_IOPMAssertionRelease(self.powerAssertion);
            self.powerAssertion = 0;
            NSLog(@"[IOKit] Блокировка сна снята.");
        }
        if (self.bgTask != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.bgTask];
            self.bgTask = UIBackgroundTaskInvalid;
        }
    }
}

#pragma mark - Управление задачами

- (void)downloadMovieTitle:(NSString *)title
                  subtitle:(NSString *)subtitle
                 urlString:(NSString *)urlString
                    taskId:(NSString *)taskId
{
    if (!urlString || [urlString length] == 0) return;
    
    for (HRDownloadTask *t in self.internalTasks) {
        if ([t.taskId isEqualToString:taskId]) {
            t.remoteURLString = urlString;
            t.title = title;
            t.subtitle = subtitle;
            if (t.status == HRDownloadStatusPaused || t.status == HRDownloadStatusFailed) {
                [self resumeTask:t];
            }
            return;
        }
    }
    
    HRDownloadTask *task = [[HRDownloadTask alloc] init];
    task.taskId = taskId;
    task.title = title;
    task.subtitle = subtitle;
    task.remoteURLString = urlString;
    
    NSString *safeName = [NSString stringWithFormat:@"%@.mp4", taskId];
    task.localFilePath = [[self downloadsDirectory] stringByAppendingPathComponent:safeName];
    
    [self.internalTasks addObject:task];
    [self startDownloadingTask:task];
}

- (void)startDownloadingTask:(HRDownloadTask *)task
{
    task.status = HRDownloadStatusDownloading;
    [self updatePowerAssertionState];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:task.localFilePath]) {
        [fm createFileAtPath:task.localFilePath contents:nil attributes:nil];
    }
    
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:task.localFilePath];
    [handle seekToEndOfFile];
    task.downloadedBytes = (long long)[handle offsetInFile];
    [self.fileHandles setObject:handle forKey:task.taskId];
    
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:task.remoteURLString]
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:60.0];
    [req setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 6_1_3 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10B326 Safari/8536.25" forHTTPHeaderField:@"User-Agent"];
    
    if (task.downloadedBytes > 0) {
        NSString *rangeVal = [NSString stringWithFormat:@"bytes=%lld-", task.downloadedBytes];
        [req setValue:rangeVal forHTTPHeaderField:@"Range"];
    }
    
    NSURLConnection *conn = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:NO];
    [conn scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    [conn start];
    
    [self.activeConnections setObject:conn forKey:task.taskId];
}

- (void)pauseTask:(HRDownloadTask *)task
{
    NSURLConnection *conn = [self.activeConnections objectForKey:task.taskId];
    if (conn) {
        [conn cancel];
        [self.activeConnections removeObjectForKey:task.taskId];
    }
    
    NSFileHandle *handle = [self.fileHandles objectForKey:task.taskId];
    if (handle) {
        [handle closeFile];
        [self.fileHandles removeObjectForKey:task.taskId];
    }
    
    task.status = HRDownloadStatusPaused;
    [self updatePowerAssertionState];
    [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadProgressNotification object:task];
}

- (void)resumeTask:(HRDownloadTask *)task
{
    if (task.status == HRDownloadStatusDownloading) return;
    [self startDownloadingTask:task];
}

- (void)cancelTask:(HRDownloadTask *)task
{
    [self pauseTask:task];
    [[NSFileManager defaultManager] removeItemAtPath:task.localFilePath error:nil];
    [self.internalTasks removeObject:task];
    [self updatePowerAssertionState];
}

#pragma mark - NSURLConnectionDataDelegate

- (HRDownloadTask *)taskForConnection:(NSURLConnection *)connection
{
    for (NSString *tId in [self.activeConnections allKeys]) {
        if ([self.activeConnections objectForKey:tId] == connection) {
            for (HRDownloadTask *t in self.internalTasks) {
                if ([t.taskId isEqualToString:tId]) return t;
            }
        }
    }
    return nil;
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    HRDownloadTask *task = [self taskForConnection:connection];
    if (!task) return;
    
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
        // Если сервер проигнорировал Range и отдал 200 OK с самого начала — перезаписываем файл с 0
        if (statusCode == 200 && task.downloadedBytes > 0) {
            NSFileHandle *handle = [self.fileHandles objectForKey:task.taskId];
            [handle truncateFileAtOffset:0];
            task.downloadedBytes = 0;
        }
    }
    
    long long expected = [response expectedContentLength];
    if (expected != NSURLResponseUnknownLength) {
        task.totalBytes = task.downloadedBytes + expected;
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    HRDownloadTask *task = [self taskForConnection:connection];
    if (!task) return;
    
    NSFileHandle *handle = [self.fileHandles objectForKey:task.taskId];
    if (handle) {
        [handle writeData:data];
        task.downloadedBytes += [data length];
        
        if (task.totalBytes > 0) {
            task.progress = (float)task.downloadedBytes / (float)task.totalBytes;
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadProgressNotification object:task];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    HRDownloadTask *task = [self taskForConnection:connection];
    if (!task) return;
    
    NSFileHandle *handle = [self.fileHandles objectForKey:task.taskId];
    if (handle) {
        [handle closeFile];
        [self.fileHandles removeObjectForKey:task.taskId];
    }
    [self.activeConnections removeObjectForKey:task.taskId];
    
    task.status = HRDownloadStatusFinished;
    task.progress = 1.0f;
    
    [self updatePowerAssertionState];
    [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadFinishedNotification object:task];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    HRDownloadTask *task = [self taskForConnection:connection];
    if (!task) return;
    
    [self pauseTask:task];
    task.status = HRDownloadStatusFailed;
    [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadProgressNotification object:task];
}

#pragma mark - Экспорт в буфер обмена (M3U)

- (void)copySingleVideoToClipboardTitle:(NSString *)title urlString:(NSString *)urlString
{
    if (!urlString || [urlString length] == 0) return;
    
    NSMutableString *m3u = [NSMutableString stringWithString:@"#EXTM3U\n"];
    [m3u appendFormat:@"#EXTINF:-1,%@\n%@\n", title ?: @"Видео", urlString];
    
    [UIPasteboard generalPasteboard].string = m3u;
}

- (void)copySeasonPlaylistToClipboardTitle:(NSString *)showTitle
                               seasonTitle:(NSString *)seasonTitle
                                  episodes:(NSArray *)episodes
{
    if (!episodes || [episodes count] == 0) return;
    
    NSMutableString *m3u = [NSMutableString stringWithString:@"#EXTM3U\n"];
    for (NSDictionary *ep in episodes) {
        NSString *epName = [ep objectForKey:@"title"] ?: @"Серия";
        NSString *epUrl = [ep objectForKey:@"url"] ?: @"";
        if ([epUrl length] > 0) {
            [m3u appendFormat:@"#EXTINF:-1,%@ - %@ (%@)\n%@\n", showTitle, seasonTitle, epName, epUrl];
        }
    }
    
    [UIPasteboard generalPasteboard].string = m3u;
}

@end