#import <Foundation/Foundation.h>

@interface HRMovie : NSObject

@property (nonatomic, copy) NSString *movieId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *originalTitle;
@property (nonatomic, copy) NSString *posterURLString;
@property (nonatomic, copy) NSString *detailURLString;
@property (nonatomic, copy) NSString *info; // Год, страна, жанр
@property (nonatomic, copy) NSString *rating;
@property (nonatomic, assign) BOOL isSeries;

- (id)initWithDictionary:(NSDictionary *)dict;

@end