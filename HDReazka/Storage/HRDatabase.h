#import <Foundation/Foundation.h>
#import <sqlite3.h>

@class HRMovie;

@interface HRDatabase : NSObject

+ (instancetype)sharedDatabase;

// Избранное с сохранением позиции (сезон, серия, озвучка)
- (BOOL)addFavorite:(HRMovie *)movie
             season:(NSString *)season
            episode:(NSString *)episode
       translatorId:(NSString *)translatorId;

- (BOOL)removeFavoriteWithMovieId:(NSString *)movieId;
- (BOOL)isFavorite:(NSString *)movieId;
- (NSArray *)allFavorites;

// История просмотров
- (void)savePlaybackHistoryForMovie:(HRMovie *)movie
                             season:(NSString *)season
                            episode:(NSString *)episode
                       translatorId:(NSString *)translatorId;

- (NSArray *)allHistory;

- (void)setupDatabase;
- (BOOL)closeDatabase;

@end