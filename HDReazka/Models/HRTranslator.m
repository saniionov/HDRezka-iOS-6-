#import "HRTranslator.h"

@implementation HRTranslator

- (id)initWithId:(NSString *)tId name:(NSString *)name isPremium:(BOOL)isPremium
{
    self = [super init];
    if (self) {
        _translatorId = [tId copy];
        _name = [name copy];
        _isPremium = isPremium;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"[HRTranslator id=%@, name='%@', premium=%d]",
            self.translatorId, self.name, self.isPremium];
}

@end