#import <Foundation/Foundation.h>

@class HRMovie;

@interface HRCatalogParser : NSObject

// Парсинг каталога и поиска
+ (NSArray *)parseCatalogHTML:(NSString *)html;

// Парсинг страницы деталей фильма
+ (NSString *)extractMovieIDFromHTML:(NSString *)html;
+ (NSString *)extractDescriptionFromHTML:(NSString *)html;
+ (NSArray *)parseTranslatorsFromHTML:(NSString *)html;

// Вспомогательный метод поиска подстроки
+ (NSString *)extractBetween:(NSString *)start and:(NSString *)end from:(NSString *)source;

@end