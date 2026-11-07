#import "HRLocalListViewController.h"
#import "HRDatabase.h"
#import "HRMovie.h"
#import "HRMovieCell.h"
#import "HRMovieDetailViewController.h"
#import "HRImageCache.h"
#import "HRTheme.h"
#import <QuartzCore/QuartzCore.h>

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
        self.navigationItem.rightBarButtonItem = [HRTheme createGlossyBarButtonWithTitle:@"Очистить"
                                                                                  target:self
                                                                                  action:@selector(clearHistoryTapped)];
    }
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.rowHeight = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 150.0f : 96.0f;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    // Серая линия вместо красной, в едином стиле с главным каталогом
    self.tableView.separatorColor = [UIColor colorWithWhite:0.25f alpha:1.0f];
    [self.view addSubview:self.tableView];
    
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 160, self.view.bounds.size.width - 40, 60)];
    self.emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
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
        [[HRDatabase sharedDatabase] clearHistory];
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
            NSInteger s = [[parts objectAtIndex:0] integerValue];
            NSInteger e = [[parts objectAtIndex:1] integerValue];
            
            if (s > 0 && e > 0) {
                cell.subtitleLabel.text = [NSString stringWithFormat:@"Сезон %ld, Серия %ld", (long)s, (long)e];
                cell.badgeSeriesLabel.hidden = NO;
                cell.badgeSeriesLabel.text = [NSString stringWithFormat:@"E%ld", (long)e];
            } else {
                cell.badgeSeriesLabel.hidden = YES;
                if (movie.info && [movie.info length] > 0) {
                    cell.subtitleLabel.text = movie.info;
                }
            }
        }
    } else {
        cell.badgeSeriesLabel.hidden = YES;
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