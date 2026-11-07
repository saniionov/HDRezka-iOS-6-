#import "HRDownloadManager.h"
#import "HRM3UExporter.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <dlfcn.h>

#define kMaxConcurrentDownloads 2
#define kHRMetadataStoreKey @"HRDownloadMetadata"

typedef int32_t IOReturn;
typedef uint32_t IOPMAssertionID;
typedef uint32_t IOPMAssertionLevel;

#define kIOPMAssertionTypePreventUserIdleSystemSleep CFSTR("PreventUserIdleSystemSleep")
#define kIOPMAssertionLevelOn 255

static IOReturn (*pfn_IOPMAssertionCreateWithName)(CFStringRef, IOPMAssertionLevel, CFStringRef, IOPMAssertionID *) = NULL;
static IOReturn (*pfn_IOPMAssertionRelease)(IOPMAssertionID) = NULL;

@interface HRDownloadManager () <NSURLConnectionDataDelegate>

@property (nonatomic, strong) NSMutableArray *internalTasks;
@property (nonatomic, strong) NSMutableDictionary *activeConnections;
@property (nonatomic, strong) NSMutableDictionary *fileHandles;
@property (nonatomic, assign) IOPMAssertionID powerAssertion;
@property (nonatomic, assign) UIBackgroundTaskIdentifier bgTask;
@property (nonatomic, strong) NSMutableArray *waitingTaskIDs;

// Бесконечный фоновый аудиоплеер для обхода 10-минутного лимита
@property (nonatomic, strong) AVAudioPlayer *silentAudioPlayer;

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
        _waitingTaskIDs = [[NSMutableArray alloc] init];
        _powerAssertion = 0;
        _bgTask = UIBackgroundTaskInvalid;
        
        NSString *dir = [self downloadsDirectory];
        if (![[NSFileManager defaultManager] fileExistsAtPath:dir]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleBackgroundAudioSettingChange:) name:@"HRBackgroundAudioSettingChanged" object:nil];
        
        [self setupSilentAudioPlayer];
        [self restoreExistingDownloads];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Генерация и настройка Silent Audio Loop

- (void)handleBackgroundAudioSettingChange:(NSNotification *)note
{
    BOOL isEnabled = [note.object boolValue];
    NSLog(@"[HRDownloadManager] Получено уведомление о фоновом аудио: %@", isEnabled ? @"ВКЛЮЧИТЬ" : @"ОТКЛЮЧИТЬ");
    
    if (isEnabled) {
        if (!self.silentAudioPlayer) {
            [self setupSilentAudioPlayer];
            NSLog(@"[HRDownloadManager] SilentAudioPlayer создан и запущен.");
        } else {
            NSLog(@"[HRDownloadManager] SilentAudioPlayer уже активен.");
        }
    } else {
        if (self.silentAudioPlayer) {
            [self.silentAudioPlayer stop];
            self.silentAudioPlayer = nil;
            NSLog(@"[HRDownloadManager] SilentAudioPlayer остановлен и освобожден.");
        } else {
            NSLog(@"[HRDownloadManager] SilentAudioPlayer уже был отключен.");
        }
    }
}

- (void)setupSilentAudioPlayer
{
    BOOL isBgEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"HR_BACKGROUND_AUDIO_ENABLED"];
    if (!isBgEnabled) return;
    
    // Программная генерация 1-секундного тишайшего WAV-файла (PCM, 8000 Hz, 16 bit, Mono)
    NSData *wavData = [self generateSilentWAVData];
    if (!wavData) return;
    
    NSError *error = nil;
    _silentAudioPlayer = [[AVAudioPlayer alloc] initWithData:wavData error:&error];
    if (!_silentAudioPlayer || error) {
        NSLog(@"[HRDownloadManager] Ошибка инициализации фонового плеера тишины: %@", error);
        return;
    }
    
    _silentAudioPlayer.numberOfLoops = -1; // Бесконечный цикл воспроизведения
    _silentAudioPlayer.volume = 0.01f;     // Минимальная громкость для удержания аудио-сессии iOS
    [_silentAudioPlayer prepareToPlay];
}

- (NSData *)generateSilentWAVData
{
    const uint32_t sampleRate = 8000;
    const uint16_t numChannels = 1;
    const uint16_t bitsPerSample = 16;
    const uint32_t numSamples = sampleRate; // 1 секунда звука
    const uint32_t dataSize = numSamples * numChannels * (bitsPerSample / 8);
    const uint32_t chunkSize = 36 + dataSize;
    
    NSMutableData *data = [NSMutableData dataWithCapacity:44 + dataSize];
    
    // RIFF Header
    [data appendBytes:"RIFF" length:4];
    [data appendBytes:&chunkSize length:4];
    [data appendBytes:"WAVE" length:4];
    
    // fmt Subchunk
    [data appendBytes:"fmt " length:4];
    uint32_t subchunk1Size = 16;
    uint16_t audioFormat = 1; // PCM
    uint32_t byteRate = sampleRate * numChannels * (bitsPerSample / 8);
    uint16_t blockAlign = numChannels * (bitsPerSample / 8);
    
    [data appendBytes:&subchunk1Size length:4];
    [data appendBytes:&audioFormat length:2];
    [data appendBytes:&numChannels length:2];
    [data appendBytes:&sampleRate length:4];
    [data appendBytes:&byteRate length:4];
    [data appendBytes:&blockAlign length:2];
    [data appendBytes:&bitsPerSample length:2];
    
    // data Subchunk (заполнен нулями — чистая тишина)
    [data appendBytes:"data" length:4];
    [data appendBytes:&dataSize length:4];
    
    void *zeroBytes = calloc(1, dataSize);
    if (zeroBytes) {
        [data appendBytes:zeroBytes length:dataSize];
        free(zeroBytes);
    }
    
    return data;
}

#pragma mark - Сохранение Состояния (База Метаданных)

- (void)saveMetadataForTask:(HRDownloadTask *)task
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *meta = [[defaults dictionaryForKey:kHRMetadataStoreKey] mutableCopy];
    if (!meta) meta = [[NSMutableDictionary alloc] init];
    
    NSDictionary *taskInfo = @{
                               @"title": task.title ?: @"",
                               @"subtitle": task.subtitle ?: @"",
                               @"totalBytes": @(task.totalBytes),
                               @"status": @(task.status)
                               };
    [meta setObject:taskInfo forKey:task.taskId];
    
    [defaults setObject:meta forKey:kHRMetadataStoreKey];
    [defaults synchronize];
}

- (void)removeMetadataForTaskId:(NSString *)taskId
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *meta = [[defaults dictionaryForKey:kHRMetadataStoreKey] mutableCopy];
    if (meta && [meta objectForKey:taskId]) {
        [meta removeObjectForKey:taskId];
        [defaults setObject:meta forKey:kHRMetadataStoreKey];
        [defaults synchronize];
    }
}

- (void)restoreExistingDownloads
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *meta = [defaults dictionaryForKey:kHRMetadataStoreKey];
    
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
                task.localFilePath = fullPath;
                task.downloadedBytes = fileSize;
                
                NSDictionary *taskInfo = [meta objectForKey:task.taskId];
                if (taskInfo) {
                    task.title = [taskInfo objectForKey:@"title"];
                    task.subtitle = [taskInfo objectForKey:@"subtitle"];
                    task.totalBytes = [[taskInfo objectForKey:@"totalBytes"] longLongValue];
                    
                    NSInteger savedStatus = [[taskInfo objectForKey:@"status"] integerValue];
                    if (savedStatus == HRDownloadStatusDownloading || savedStatus == HRDownloadStatusWaiting) {
                        task.status = HRDownloadStatusPaused;
                    } else {
                        task.status = savedStatus;
                    }
                } else {
                    task.title = task.taskId;
                    task.subtitle = @"Локальный файл";
                    task.totalBytes = fileSize;
                    task.status = HRDownloadStatusFinished;
                }
                
                if (task.totalBytes > 0 && task.downloadedBytes >= task.totalBytes) {
                    task.status = HRDownloadStatusFinished;
                    task.downloadedBytes = task.totalBytes;
                    task.progress = 1.0f;
                } else if (task.totalBytes > 0) {
                    task.progress = (float)task.downloadedBytes / (float)task.totalBytes;
                } else {
                    task.progress = 0.0f;
                }
                
                [_internalTasks addObject:task];
            }
        }
    }
}

- (NSArray *)tasks
{
    return [self.internalTasks copy];
}

- (HRDownloadIndicatorState)indicatorState
{
    BOOL isDownloading = NO;
    BOOL hasFailed = NO;
    
    for (HRDownloadTask *task in self.internalTasks) {
        if (task.status == HRDownloadStatusDownloading) {
            isDownloading = YES;
        } else if (task.status == HRDownloadStatusFailed) {
            hasFailed = YES;
        }
    }
    
    if (isDownloading) return HRDownloadIndicatorStateDownloading;
    if (hasFailed) return HRDownloadIndicatorStateFailed;
    return HRDownloadIndicatorStateIdle;
}

- (NSString *)downloadsDirectory
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[paths objectAtIndex:0] stringByAppendingPathComponent:@"Downloads"];
}

- (BOOL)clearAllDownloads
{
    [self.waitingTaskIDs removeAllObjects];
    
    NSArray *connections = [[self.activeConnections allValues] copy];
    [self.activeConnections removeAllObjects];
    for (NSURLConnection *connection in connections) {
        [connection cancel];
    }
    
    NSArray *handles = [[self.fileHandles allValues] copy];
    [self.fileHandles removeAllObjects];
    for (NSFileHandle *handle in handles) {
        @try { [handle closeFile]; } @catch (NSException *exception) {}
    }
    
    [self.internalTasks removeAllObjects];
    [self updatePowerAssertionState];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *directory = [self downloadsDirectory];
    NSArray *files = [fileManager contentsOfDirectoryAtPath:directory error:nil];
    BOOL allDeleted = YES;
    
    for (NSString *file in files) {
        NSString *fullPath = [directory stringByAppendingPathComponent:file];
        if (![fileManager removeItemAtPath:fullPath error:nil]) {
            allDeleted = NO;
        }
    }
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kHRMetadataStoreKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadProgressNotification object:nil];
    return allDeleted;
}

#pragma mark - Удержание питания и Фоновый аудио-режим

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
        // 1. Стандартный UIBackgroundTaskIdentifier
        if (self.bgTask == UIBackgroundTaskInvalid) {
            self.bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
                [[UIApplication sharedApplication] endBackgroundTask:self.bgTask];
                self.bgTask = UIBackgroundTaskInvalid;
            }];
        }
        
        // 2. IOKit: блокировка засыпания устройства при заблокированном экране
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
        
        // 3. Silent Audio: бесконечная работа при свернутом приложении (кнопка Home)
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [session setCategory:AVAudioSessionCategoryPlayback error:nil];
        [session setActive:YES error:nil];
        
        if (self.silentAudioPlayer && !self.silentAudioPlayer.isPlaying) {
            [self.silentAudioPlayer play];
            NSLog(@"[Background Audio] Бесконечный фоновый аудиоплеер запущен.");
        }
        
    } else {
        // Загрузок нет: освобождаем ресурсы
        if (self.silentAudioPlayer && self.silentAudioPlayer.isPlaying) {
            [self.silentAudioPlayer pause];
            [[AVAudioSession sharedInstance] setActive:NO error:nil];
            NSLog(@"[Background Audio] Фоновый аудиоплеер остановлен.");
        }
        
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

#pragma mark - Логика Очереди (Queue Limit)

- (void)processDownloadQueue
{
    while (self.activeConnections.count < kMaxConcurrentDownloads && self.waitingTaskIDs.count > 0) {
        NSString *nextTaskId = [self.waitingTaskIDs objectAtIndex:0];
        [self.waitingTaskIDs removeObjectAtIndex:0];
        
        HRDownloadTask *taskToStart = nil;
        for (HRDownloadTask *t in self.internalTasks) {
            if ([t.taskId isEqualToString:nextTaskId]) {
                taskToStart = t;
                break;
            }
        }
        
        if (taskToStart) {
            [self startDownloadingTask:taskToStart];
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
            [self saveMetadataForTask:t];
            
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
    
    // Формируем понятное человеческое имя: "Название - Серия (taskId).mp4"
    NSMutableString *rawName = [NSMutableString string];
    if (title && [title length] > 0) {
        [rawName appendString:title];
    }
    if (subtitle && [subtitle length] > 0) {
        if ([rawName length] > 0) [rawName appendString:@" - "];
        [rawName appendString:subtitle];
    }
    if ([rawName length] == 0) {
        [rawName appendString:taskId];
    } else {
        [rawName appendFormat:@" (%@)", taskId];
    }
    
    // Заменяем все запрещенные символы файловой системы на дефис
    NSCharacterSet *invalidChars = [NSCharacterSet characterSetWithCharactersInString:@"/:\\?%*|\"<>"];
    NSArray *components = [rawName componentsSeparatedByCharactersInSet:invalidChars];
    NSString *sanitizedName = [components componentsJoinedByString:@"-"];
    
    // Убираем двойные пробелы/дефисы по краям
    sanitizedName = [sanitizedName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    NSString *safeName = [NSString stringWithFormat:@"%@.mp4", sanitizedName];
    task.localFilePath = [[self downloadsDirectory] stringByAppendingPathComponent:safeName];
    
    [self saveMetadataForTask:task];
    [self.internalTasks addObject:task];
    
    if (self.activeConnections.count < kMaxConcurrentDownloads) {
        [self startDownloadingTask:task];
    } else {
        task.status = HRDownloadStatusWaiting;
        [self saveMetadataForTask:task];
        [self.waitingTaskIDs addObject:task.taskId];
        [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadProgressNotification object:task];
    }
}

- (void)startDownloadingTask:(HRDownloadTask *)task
{
    task.status = HRDownloadStatusDownloading;
    [self saveMetadataForTask:task];
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
    [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadProgressNotification object:task];
}

- (void)pauseTask:(HRDownloadTask *)task
{
    [self.waitingTaskIDs removeObject:task.taskId];
    
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
    [self saveMetadataForTask:task];
    
    [self updatePowerAssertionState];
    [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadProgressNotification object:task];
    
    [self processDownloadQueue];
}

- (void)resumeTask:(HRDownloadTask *)task
{
    if (task.status == HRDownloadStatusDownloading || task.status == HRDownloadStatusWaiting) return;
    
    if (task.totalBytes > 0 && task.downloadedBytes >= task.totalBytes) {
        task.status = HRDownloadStatusFinished;
        task.progress = 1.0f;
        [self saveMetadataForTask:task];
        [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadFinishedNotification object:task];
        return;
    }
    
    if (self.activeConnections.count < kMaxConcurrentDownloads) {
        [self startDownloadingTask:task];
    } else {
        if (![self.waitingTaskIDs containsObject:task.taskId]) {
            task.status = HRDownloadStatusWaiting;
            [self saveMetadataForTask:task];
            [self.waitingTaskIDs addObject:task.taskId];
            [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadProgressNotification object:task];
        }
    }
}

- (void)cancelTask:(HRDownloadTask *)task
{
    [self pauseTask:task];
    
    [[NSFileManager defaultManager] removeItemAtPath:task.localFilePath error:nil];
    [self removeMetadataForTaskId:task.taskId];
    [self.internalTasks removeObject:task];
    [self updatePowerAssertionState];
}

#pragma mark - Массовое управление

- (void)pauseAllTasks
{
    [self.waitingTaskIDs removeAllObjects];
    
    NSArray *keys = [self.activeConnections allKeys];
    for (NSString *tId in keys) {
        NSURLConnection *conn = [self.activeConnections objectForKey:tId];
        [conn cancel];
        
        NSFileHandle *handle = [self.fileHandles objectForKey:tId];
        if (handle) {
            [handle closeFile];
        }
    }
    [self.activeConnections removeAllObjects];
    [self.fileHandles removeAllObjects];
    
    for (HRDownloadTask *task in self.internalTasks) {
        if (task.status == HRDownloadStatusDownloading || task.status == HRDownloadStatusWaiting) {
            task.status = HRDownloadStatusPaused;
            [self saveMetadataForTask:task];
            [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadProgressNotification object:task];
        }
    }
    
    [self updatePowerAssertionState];
}

- (void)resumeAllTasks
{
    for (HRDownloadTask *task in self.internalTasks) {
        if (task.status == HRDownloadStatusPaused || task.status == HRDownloadStatusFailed) {
            [self resumeTask:task];
        }
    }
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
        
        if (statusCode == 416) {
            if (task.downloadedBytes > 0 && task.downloadedBytes >= task.totalBytes) {
                [connection cancel];
                [self connectionDidFinishLoading:connection];
            } else {
                [connection cancel];
                [self connection:connection didFailWithError:[NSError errorWithDomain:@"HRManager" code:416 userInfo:nil]];
            }
            return;
        }
        
        if (statusCode == 200 && task.downloadedBytes > 0) {
            NSFileHandle *handle = [self.fileHandles objectForKey:task.taskId];
            [handle truncateFileAtOffset:0];
            task.downloadedBytes = 0;
        }
    }
    
    long long expected = [response expectedContentLength];
    if (expected != NSURLResponseUnknownLength) {
        if ([(NSHTTPURLResponse *)response statusCode] == 206) {
            task.totalBytes = task.downloadedBytes + expected;
        } else {
            task.totalBytes = expected;
        }
        [self saveMetadataForTask:task];
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
    [self saveMetadataForTask:task];
    
    [self updatePowerAssertionState];
    [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadFinishedNotification object:task];
    
    [self processDownloadQueue];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    HRDownloadTask *task = [self taskForConnection:connection];
    if (!task) return;
    
    [self pauseTask:task];
    task.status = HRDownloadStatusFailed;
    [self saveMetadataForTask:task];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kHRDownloadProgressNotification object:task];
}

#pragma mark - Экспорт в буфер обмена (M3U)

- (void)copySingleVideoToClipboardTitle:(NSString *)title urlString:(NSString *)urlString
{
    [HRM3UExporter copySingleVideoToClipboardTitle:title urlString:urlString];
}

- (void)copySeasonPlaylistToClipboardTitle:(NSString *)showTitle
                               seasonTitle:(NSString *)seasonTitle
                                  episodes:(NSArray *)episodes
{
    [HRM3UExporter copySeasonPlaylistToClipboardTitle:showTitle seasonTitle:seasonTitle episodes:episodes];
}

@end