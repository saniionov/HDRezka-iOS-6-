#import <UIKit/UIKit.h>

typedef enum {
    HRLocalListModeFavorites = 0,
    HRLocalListModeHistory   = 1
} HRLocalListMode;

@interface HRLocalListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>

@property (nonatomic, assign) HRLocalListMode mode;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *items;

- (id)initWithMode:(HRLocalListMode)mode;
- (void)reloadDataFromDatabase;

@end