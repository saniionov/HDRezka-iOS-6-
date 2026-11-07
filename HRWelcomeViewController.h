#import <UIKit/UIKit.h>

@interface HRWelcomeViewController : UIViewController <UITextViewDelegate>

@property (nonatomic, copy) NSString *textFileName;
@property (nonatomic, copy) NSString *displayTitle;
@property (nonatomic, copy) NSString *displaySubtitle;

@end