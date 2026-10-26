#import <UIKit/UIKit.h>

@interface HRCatalogViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) NSMutableArray *movies;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

- (void)startLoadingProcess;
- (void)loadCatalog;
- (void)resetToHomeScreen;

@end