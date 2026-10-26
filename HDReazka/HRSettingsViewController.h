#import <UIKit/UIKit.h>

@interface HRSettingsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UIWebViewDelegate>

@property (nonatomic, strong) UITableView *tableView;

@end