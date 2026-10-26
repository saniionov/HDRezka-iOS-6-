#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface HRImageCache : NSObject

+ (instancetype)sharedCache;

- (void)loadImageForURLString:(NSString *)urlString completion:(void (^)(UIImage *image))completion;

// Единый метод очистки кэша постеров (вызывается при полном сбросе приложения)
- (void)clearCache;

@end