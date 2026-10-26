#import "HRSeason.h"
#import "HREpisode.h"

@implementation HRSeason

- (id)initWithSeasonId:(NSString *)seasonId title:(NSString *)title
{
    self = [super init];
    if (self) {
        _seasonId = [seasonId copy];
        _title = [title copy];
        _episodes = [[NSMutableArray alloc] init];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[HRSeason id=%@, title='%@', episodesCount=%lu]",
            self.seasonId, self.title, (unsigned long)[self.episodes count]];
}

@end