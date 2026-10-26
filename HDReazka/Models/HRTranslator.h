#import <Foundation/Foundation.h>

@interface HRTranslator : NSObject

@property (nonatomic, copy) NSString *translatorId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) BOOL isPremium;

- (id)initWithId:(NSString *)tId name:(NSString *)name isPremium:(BOOL)isPremium;

@end