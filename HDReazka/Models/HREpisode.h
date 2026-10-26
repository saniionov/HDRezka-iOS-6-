#import <Foundation/Foundation.h>

@interface HREpisode : NSObject

@property (nonatomic, copy) NSString *seasonId;
@property (nonatomic, copy) NSString *episodeId;
@property (nonatomic, copy) NSString *title;

- (id)initWithSeasonId:(NSString *)seasonId episodeId:(NSString *)episodeId title:(NSString *)title;

@end