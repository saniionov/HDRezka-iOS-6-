#import "HRMovie.h"

@implementation HRMovie

- (id)initWithDictionary:(NSDictionary *)dict
{
    self = [super init];
    if (self) {
        _movieId = [dict objectForKey:@"id"] ?: @"";
        _title = [dict objectForKey:@"title"] ?: @"";
        _originalTitle = [dict objectForKey:@"originalTitle"] ?: @"";
        _posterURLString = [dict objectForKey:@"poster"] ?: @"";
        _detailURLString = [dict objectForKey:@"url"] ?: @"";
        _info = [dict objectForKey:@"info"] ?: @"";
        _rating = [dict objectForKey:@"rating"] ?: @"";
        _isSeries = [[dict objectForKey:@"isSeries"] boolValue];
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[HRMovie id=%@, title='%@', info='%@', series=%d]",
            self.movieId, self.title, self.info, self.isSeries];
}

@end