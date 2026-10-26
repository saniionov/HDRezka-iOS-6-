#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

@class HRMovie;

// Общий видеоплеер с жестами (Яркость слева / Звук справа / Перемотка 20с)
@interface HRGestureMoviePlayerViewController : MPMoviePlayerViewController <UIGestureRecognizerDelegate>
@end

@interface HRMovieDetailViewController : UIViewController

@property (nonatomic, strong) HRMovie *movie;

- (id)initWithMovie:(HRMovie *)movie;

@end