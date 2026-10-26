#import <Foundation/Foundation.h>

@class HRMovie;

// Блок для парсинга страницы фильма/сериала
typedef void (^HRMoviePageDetailsCompletionBlock)(NSString *descriptionText,
BOOL isSeries,
NSArray *translators,
NSArray *seasonsData,
NSInteger defaultTranslatorId,
NSDictionary *initialStreams,
NSError *error);

// Блок для получения конкретных потоков видео
typedef void (^HRStreamCompletionBlock)(NSDictionary *streams,
NSString *subtitles,
NSArray *updatedSeasonsData,
NSError *error);

@interface HRStreamResolver : NSObject

// 1. Полная загрузка и разбор страницы фильма/сериала
+ (void)fetchMoviePageDetails:(HRMovie *)movie
                   completion:(HRMoviePageDetailsCompletionBlock)completion;

// 2. Запрос потоков и сезонов (AJAX)
+ (void)fetchStreamsForMovieId:(NSString *)movieId
                  translatorId:(NSInteger)translatorId
                        season:(NSInteger)season
                       episode:(NSInteger)episode
                      isSeries:(BOOL)isSeries
                        action:(NSString *)action
                    completion:(HRStreamCompletionBlock)completion;

// 3. Получение полного сезона (для скачивания / M3U)
+ (void)fetchSeasonEpisodeStreamsForMovieId:(NSString *)movieId
                               translatorId:(NSInteger)translatorId
                                     season:(NSInteger)season
                               episodesList:(NSArray *)episodesList
                           preferredQuality:(NSString *)preferredQuality
                                 completion:(void (^)(NSArray *resolvedEpisodes))completion;

// 4. Вспомогательные парсеры URL
+ (NSDictionary *)parseStreamsFromRawURLString:(NSString *)rawString;
+ (NSString *)bestQualityKeyFromStreams:(NSDictionary *)streams preferredQuality:(NSString *)preferred;

@end