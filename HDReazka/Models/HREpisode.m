#import "HREpisode.h"

@implementation HREpisode

- (id)initWithSeasonId:(NSString *)seasonId episodeId:(NSString *)episodeId title:(NSString *)title
{
    self = [super init];
    if (self) {
        _seasonId = [seasonId copy];
        _episodeId = [episodeId copy];
        _title = [title copy];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[S%@ E%@: %@]", self.seasonId, self.episodeId, self.title];
}

@end