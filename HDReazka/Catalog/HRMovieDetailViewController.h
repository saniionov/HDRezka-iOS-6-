#import <UIKit/UIKit.h>

@class HRMovie;

@interface HRMovieDetailViewController : UIViewController

@property (nonatomic, strong) HRMovie *movie;

- (id)initWithMovie:(HRMovie *)movie;

@end