#import "HRLocalListViewController.h"
#import "HRDatabase.h"
#import "HRMovie.h"
#import "HRMovieCell.h"
#import "HRMovieDetailViewController.h"
#import "HRImageCache.h"
#import <QuartzCore/QuartzCore.h>
#import <sqlite3.h>

@interface HRLocalListViewController ()
@property (nonatomic, strong) UILabel *emptyLabel;
@end

@implementation HRLocalListViewController

- (id)initWithMode:(HRLocalListMode)mode
{
    self = [super init];
    if (self) {
        _mode = mode;
        _items = [NSMutableArray array];
        self.title = (_mode == HRLocalListModeFavorites) ? @"Избранное" : @"История";
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    
    if (self.mode == HRLocalListModeHistory) {
        UIButton *clearBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        clearBtn.frame = CGRectMake(0, 0, 72, 30);
        clearBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0f];
        [clearBtn setTitle:@"Очистить" forState:UIControlStateNormal];
        [clearBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        clearBtn.backgroundColor = [UIColor colorWithRed:0.62 green:0.08 blue:0.08 alpha:1.0];
        clearBtn.layer.cornerRadius = 4.0f;
        clearBtn.layer.borderWidth = 1.0f;
        clearBtn.layer.borderColor = [[UIColor colorWithRed:0.85 green:0.20 blue:0.20 alpha:1.0] CGColor];
        clearBtn.layer.masksToBounds = YES;
        [clearBtn addTarget:self action:@selector(clearHistoryTapped) forControlEvents:UIControlEventTouchUpInside];
        
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:clearBtn];
    }
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.rowHeight = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 150.0f : 96.0f;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    
    // КРАСНАЯ ЛИНИЯ РАЗДЕЛЕНИЯ В ИСТОРИИ И ИЗБРАННОМ
    self.tableView.separatorColor = [UIColor colorWithRed:0.55 green:0.10 blue:0.10 alpha:0.50];
    [self.view addSubview:self.tableView];
    
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 160, self.view.bounds.size.width - 40, 60)];
    self.emptyLabel.numberOfLines = 2;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor colorWithWhite:0.5f alpha:1.0f];
    self.emptyLabel.font = [UIFont systemFontOfSize:15.0f];
    self.emptyLabel.text = (self.mode == HRLocalListModeFavorites) ? @"Список закладок пуст" : @"История просмотров пуста";
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self reloadDataFromDatabase];
}

- (void)reloadDataFromDatabase
{
    [self.items removeAllObjects];
    
    if (self.mode == HRLocalListModeFavorites) {
        [self.items addObjectsFromArray:[[HRDatabase sharedDatabase] allFavorites]];
    } else {
        [self.items addObjectsFromArray:[[HRDatabase sharedDatabase] allHistory]];
    }
    
    self.emptyLabel.hidden = ([self.items count] > 0);
    [self.tableView reloadData];
}

- (void)clearHistoryTapped
{
    if ([self.items count] == 0) return;
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Очистить историю?"
                                                    message:@"Все записи просмотров будут удалены без возможности восстановления."
                                                   delegate:self
                                          cancelButtonTitle:@"Отмена"
                                          otherButtonTitles:@"Очистить", nil];
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 1) {
        sqlite3 *db = NULL;
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *docsDir = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
        NSString *dbPath = [docsDir stringByAppendingPathComponent:@"hdrezka_storage.sqlite"];
        
        if (sqlite3_open([dbPath UTF8String], &db) == SQLITE_OK) {
            sqlite3_exec(db, "DELETE FROM history;", NULL, NULL, NULL);
            sqlite3_close(db);
        }
        
        [self reloadDataFromDatabase];
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.items count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"HRLocalMovieCustomCell";
    HRMovieCell *cell = (HRMovieCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[HRMovieCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    HRMovie *movie = [self.items objectAtIndex:indexPath.row];
    [cell configureWithMovie:movie];
    
    if (self.mode == HRLocalListModeHistory && movie.rating && [movie.rating rangeOfString:@"|"].location != NSNotFound) {
        NSArray *parts = [movie.rating componentsSeparatedByString:@"|"];
        if ([parts count] >= 2) {
            cell.subtitleLabel.text = [NSString stringWithFormat:@"S%@ | E%@", [parts objectAtIndex:0], [parts objectAtIndex:1]];
            cell.badgeSeriesLabel.hidden = NO;
            cell.badgeSeriesLabel.text = [NSString stringWithFormat:@"E%@", [parts objectAtIndex:1]];
        }
    }
    
    cell.posterImageView.image = nil;
    if ([movie.posterURLString length] > 0) {
        NSString *urlToLoad = movie.posterURLString;
        __weak HRMovieCell *weakCell = cell;
        [[HRImageCache sharedCache] loadImageForURLString:urlToLoad completion:^(UIImage *image) {
            if (image && weakCell) {
                weakCell.posterImageView.image = image;
                [weakCell.posterImageView setNeedsDisplay];
            }
        }];
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    HRMovie *movie = [self.items objectAtIndex:indexPath.row];
    if ([movie.detailURLString rangeOfString:@"/series/"].location != NSNotFound) {
        movie.isSeries = YES;
    }
    
    HRMovieDetailViewController *detailVC = [[HRMovieDetailViewController alloc] initWithMovie:movie];
    [self.navigationController pushViewController:detailVC animated:YES];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return (self.mode == HRLocalListModeFavorites);
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete && self.mode == HRLocalListModeFavorites) {
        HRMovie *movie = [self.items objectAtIndex:indexPath.row];
        [[HRDatabase sharedDatabase] removeFavoriteWithMovieId:movie.movieId];
        [self.items removeObjectAtIndex:indexPath.row];
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
        self.emptyLabel.hidden = ([self.items count] > 0);
    }
}

@end