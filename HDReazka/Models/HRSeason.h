#import <Foundation/Foundation.h>

@interface HRSeason : NSObject

@property (nonatomic, copy) NSString *seasonId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, strong) NSMutableArray *episodes;

- (id)initWithSeasonId:(NSString *)seasonId title:(NSString *)title;

@end