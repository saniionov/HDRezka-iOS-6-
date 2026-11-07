#import "HRDownloadsViewController.h"
#import "HRDownloadManager.h"
#import "HRDownloadTask.h"
#import "HRTheme.h"
#import "HRGestureMoviePlayerViewController.h"
#import <QuartzCore/QuartzCore.h>

@interface HRDownloadsViewController () <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) UIView *bottomCustomBar;

@end

@implementation HRDownloadsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Загрузки";
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    
    self.navigationItem.leftBarButtonItem = [HRTheme createGlossyBarButtonWithTitle:@"Удалить все"
                                                                             target:self
                                                                             action:@selector(deleteAllDownloadsTapped)];
    
    self.navigationItem.rightBarButtonItem = [HRTheme createGlossyBackButtonWithTitle:@"Изменить"
                                                                               target:self
                                                                               action:@selector(toggleEditMode)];
    
    [self setupCustomBottomBar];
    [self setupTableView];
    [self setupEmptyStateLabel];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(downloadProgressChanged:)
                                                 name:kHRDownloadProgressNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(downloadFinished:)
                                                 name:kHRDownloadFinishedNotification
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
    [self updateEmptyState];
}

- (void)dealloc
{
    _tableView.delegate = nil;
    _tableView.dataSource = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Кастомное переключение режима редактирования

- (void)toggleEditMode
{
    BOOL isEditing = !self.tableView.isEditing;
    [self setEditing:isEditing animated:YES];
    
    NSString *title = isEditing ? @"Готово" : @"Изменить";
    
    if (isEditing) {
        self.navigationItem.rightBarButtonItem = [HRTheme createGlossyBarButtonWithTitle:title target:self action:@selector(toggleEditMode)];
    } else {
        self.navigationItem.rightBarButtonItem = [HRTheme createGlossyBackButtonWithTitle:title target:self action:@selector(toggleEditMode)];
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
}

#pragma mark - Массовое управление

- (void)startAllTapped
{
    [[HRDownloadManager sharedManager] resumeAllTasks];
    [self.tableView reloadData];
}

- (void)pauseAllTapped
{
    [[HRDownloadManager sharedManager] pauseAllTasks];
    [self.tableView reloadData];
}

- (void)deleteAllDownloadsTapped
{
    NSArray *tasks = [HRDownloadManager sharedManager].tasks;
    if ([tasks count] == 0) return;
    
    for (HRDownloadTask *task in tasks) {
        if (task.status == HRDownloadStatusDownloading) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Есть активные загрузки"
                                                            message:@"Сначала остановите активные загрузки, затем можно будет удалить все файлы."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }
    }
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Удалить все загрузки?"
                                                    message:@"Все загруженные видео и записи загрузок будут удалены. Это действие нельзя отменить."
                                                   delegate:self
                                          cancelButtonTitle:@"Отмена"
                                          otherButtonTitles:@"Удалить все", nil];
    alert.tag = 7301;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (alertView.tag != 7301 || buttonIndex != 1) return;
    
    BOOL success = [[HRDownloadManager sharedManager] clearAllDownloads];
    [self.tableView reloadData];
    [self updateEmptyState];
    
    if (self.tableView.isEditing) {
        [self toggleEditMode];
    }
    
    if (!success) {
        UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Внимание"
                                                             message:@"Возможно, некоторые файлы не удалось удалить мгновенно из-за блокировки системы. Попробуйте перезапустить приложение."
                                                            delegate:nil
                                                   cancelButtonTitle:@"OK"
                                                   otherButtonTitles:nil];
        [errorAlert show];
    }
}

#pragma mark - UI Setup (Адаптивная панель для iPad и iPhone)

- (void)setupCustomBottomBar
{
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    CGFloat tabBarH = isPad ? 64.0f : 49.0f;
    if (self.tabBarController && !self.tabBarController.tabBar.hidden) {
        tabBarH = self.tabBarController.tabBar.bounds.size.height;
        if (tabBarH < 49.0f) {
            tabBarH = isPad ? 64.0f : 49.0f;
        }
    }
    
    CGFloat barH = isPad ? 64.0f : 54.0f;
    CGFloat barY = self.view.bounds.size.height - tabBarH - barH;
    
    self.bottomCustomBar = [[UIView alloc] initWithFrame:CGRectMake(0, barY, self.view.bounds.size.width, barH)];
    self.bottomCustomBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.bottomCustomBar.backgroundColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.10 alpha:1.0];
    
    self.bottomCustomBar.layer.shadowColor = [UIColor blackColor].CGColor;
    self.bottomCustomBar.layer.shadowOffset = CGSizeMake(0, -2);
    self.bottomCustomBar.layer.shadowOpacity = 0.6f;
    self.bottomCustomBar.layer.shadowRadius = 4.0f;
    
    UIView *topLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 3.0f)];
    topLine.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    topLine.backgroundColor = [UIColor colorWithRed:0.78 green:0.08 blue:0.12 alpha:1.0];
    
    topLine.layer.shadowColor = [UIColor colorWithRed:0.78 green:0.08 blue:0.12 alpha:1.0].CGColor;
    topLine.layer.shadowOffset = CGSizeMake(0, 1);
    topLine.layer.shadowOpacity = 0.8f;
    topLine.layer.shadowRadius = 2.0f;
    [self.bottomCustomBar addSubview:topLine];
    
    CGFloat btnW = isPad ? 170.0f : 140.0f;
    CGFloat btnH = isPad ? 40.0f : 34.0f;
    CGFloat btnY = floorf((barH - btnH) / 2.0f) + 1.0f;
    CGFloat spacing = isPad ? 24.0f : 16.0f;
    CGFloat totalW = (btnW * 2) + spacing;
    CGFloat startX = (self.view.bounds.size.width - totalW) / 2.0f;
    
    // Кнопка Старт
    UIButton *btnStart = [UIButton buttonWithType:UIButtonTypeCustom];
    btnStart.frame = CGRectMake(startX, btnY, btnW, btnH);
    btnStart.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    
    CAGradientLayer *startGrad = [CAGradientLayer layer];
    startGrad.frame = btnStart.bounds;
    startGrad.colors = @[(id)[UIColor colorWithRed:0.85 green:0.15 blue:0.18 alpha:1.0].CGColor,
                         (id)[UIColor colorWithRed:0.65 green:0.05 blue:0.08 alpha:1.0].CGColor];
    startGrad.cornerRadius = 6.0f;
    [btnStart.layer insertSublayer:startGrad atIndex:0];
    
    btnStart.layer.cornerRadius = 6.0f;
    btnStart.layer.borderWidth = 1.0f;
    btnStart.layer.borderColor = [UIColor colorWithRed:0.40 green:0.00 blue:0.00 alpha:1.0].CGColor;
    btnStart.layer.masksToBounds = YES;
    
    btnStart.titleLabel.font = [UIFont boldSystemFontOfSize:(isPad ? 15.0f : 13.0f)];
    [btnStart setTitle:@"Загрузить все" forState:UIControlStateNormal];
    [btnStart setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [btnStart setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:0.5] forState:UIControlStateNormal];
    btnStart.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [btnStart addTarget:self action:@selector(startAllTapped) forControlEvents:UIControlEventTouchUpInside];
    
    // Кнопка Пауза
    UIButton *btnPause = [UIButton buttonWithType:UIButtonTypeCustom];
    btnPause.frame = CGRectMake(startX + btnW + spacing, btnY, btnW, btnH);
    btnPause.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    
    CAGradientLayer *pauseGrad = [CAGradientLayer layer];
    pauseGrad.frame = btnPause.bounds;
    pauseGrad.colors = @[(id)[UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0].CGColor,
                         (id)[UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0].CGColor];
    pauseGrad.cornerRadius = 6.0f;
    [btnPause.layer insertSublayer:pauseGrad atIndex:0];
    
    btnPause.layer.cornerRadius = 6.0f;
    btnPause.layer.borderWidth = 1.0f;
    btnPause.layer.borderColor = [UIColor colorWithWhite:0.05 alpha:1.0].CGColor;
    btnPause.layer.masksToBounds = YES;
    
    btnPause.titleLabel.font = [UIFont boldSystemFontOfSize:(isPad ? 15.0f : 13.0f)];
    [btnPause setTitle:@"Остановить все" forState:UIControlStateNormal];
    [btnPause setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [btnPause setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:0.8] forState:UIControlStateNormal];
    btnPause.titleLabel.shadowOffset = CGSizeMake(0, -1);
    [btnPause addTarget:self action:@selector(pauseAllTapped) forControlEvents:UIControlEventTouchUpInside];
    
    [self.bottomCustomBar addSubview:btnStart];
    [self.bottomCustomBar addSubview:btnPause];
    [self.view addSubview:self.bottomCustomBar];
}

- (void)setupTableView
{
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    CGFloat tabBarH = isPad ? 64.0f : 49.0f;
    if (self.tabBarController && !self.tabBarController.tabBar.hidden) {
        tabBarH = self.tabBarController.tabBar.bounds.size.height;
        if (tabBarH < 49.0f) {
            tabBarH = isPad ? 64.0f : 49.0f;
        }
    }
    CGFloat barH = isPad ? 64.0f : 54.0f;
    
    CGRect tableFrame = self.view.bounds;
    tableFrame.size.height -= (tabBarH + barH);
    
    self.tableView = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.20f alpha:1.0f];
    self.tableView.rowHeight = isPad ? 76.0f : 64.0f;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    [self.view addSubview:self.tableView];
}

- (void)setupEmptyStateLabel
{
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 150, self.view.bounds.size.width - 40, 60)];
    self.emptyLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.textColor = [UIColor colorWithWhite:0.5f alpha:1.0f];
    self.emptyLabel.font = [UIFont systemFontOfSize:15.0f];
    self.emptyLabel.numberOfLines = 2;
    self.emptyLabel.text = @"Нет активных или скачанных файлов.\nСкачивайте серии из карточки фильма.";
    [self.view addSubview:self.emptyLabel];
}

- (void)updateEmptyState
{
    BOOL isEmpty = ([[HRDownloadManager sharedManager].tasks count] == 0);
    self.emptyLabel.hidden = !isEmpty;
    self.tableView.hidden = isEmpty;
    self.bottomCustomBar.hidden = isEmpty;
}

#pragma mark - Notifications

- (void)downloadProgressChanged:(NSNotification *)note
{
    HRDownloadTask *task = (HRDownloadTask *)note.object;
    if (!task) return;
    
    NSArray *tasks = [HRDownloadManager sharedManager].tasks;
    NSUInteger row = [tasks indexOfObject:task];
    
    if (row != NSNotFound) {
        if ([self.tableView numberOfRowsInSection:0] != [tasks count]) {
            [self.tableView reloadData];
            [self updateEmptyState];
            return;
        }
        
        NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:0];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:ip];
        if (cell) {
            UIProgressView *pv = (UIProgressView *)[cell.contentView viewWithTag:101];
            UILabel *statusLbl = (UILabel *)[cell.contentView viewWithTag:102];
            
            if (pv) pv.progress = task.progress;
            if (statusLbl) {
                statusLbl.text = [self statusStringForTask:task];
            }
        }
    }
}

- (void)downloadFinished:(NSNotification *)note
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.tableView reloadData];
        [self updateEmptyState];
    });
}

- (NSString *)statusStringForTask:(HRDownloadTask *)task
{
    if (task.status == HRDownloadStatusFinished) {
        return @"Завершено (готов к просмотру)";
    } else if (task.status == HRDownloadStatusPaused) {
        return [NSString stringWithFormat:@"Пауза (%.0f%%)", task.progress * 100.0f];
    } else if (task.status == HRDownloadStatusFailed) {
        return @"Ошибка загрузки";
    } else if (task.status == HRDownloadStatusWaiting) {
        return @"В очереди...";
    } else if (task.status == HRDownloadStatusDownloading) {
        double mbDownloaded = (double)task.downloadedBytes / (1024.0 * 1024.0);
        double mbTotal = (double)task.totalBytes / (1024.0 * 1024.0);
        
        if (mbTotal > 0.0) {
            return [NSString stringWithFormat:@"%.0f%% (%.1f / %.1f МБ)", task.progress * 100.0f, mbDownloaded, mbTotal];
        } else {
            return [NSString stringWithFormat:@"Загрузка... (%.1f МБ)", mbDownloaded];
        }
    }
    return @"Ожидание...";
}

#pragma mark - Table View Data Source & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[HRDownloadManager sharedManager].tasks count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellID = @"DownloadTaskCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID];
        cell.backgroundColor = [UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0];
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 6, cell.contentView.bounds.size.width - 24, 20)];
        titleLabel.tag = 100;
        titleLabel.font = [UIFont boldSystemFontOfSize:14.0f];
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:titleLabel];
        
        UIProgressView *pv = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        pv.frame = CGRectMake(12, 32, cell.contentView.bounds.size.width - 24, 9);
        pv.tag = 101;
        pv.progressTintColor = [UIColor colorWithRed:0.78 green:0.08 blue:0.12 alpha:1.0];
        pv.trackTintColor = [UIColor colorWithWhite:0.25f alpha:1.0f];
        pv.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:pv];
        
        UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 42, cell.contentView.bounds.size.width - 24, 16)];
        statusLabel.tag = 102;
        statusLabel.font = [UIFont systemFontOfSize:11.0f];
        statusLabel.textColor = [UIColor colorWithWhite:0.65f alpha:1.0f];
        statusLabel.backgroundColor = [UIColor clearColor];
        statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:statusLabel];
    }
    
    NSArray *tasks = [HRDownloadManager sharedManager].tasks;
    if (indexPath.row < [tasks count]) {
        HRDownloadTask *task = [tasks objectAtIndex:indexPath.row];
        
        UILabel *titleLbl = (UILabel *)[cell.contentView viewWithTag:100];
        UIProgressView *pv = (UIProgressView *)[cell.contentView viewWithTag:101];
        UILabel *statusLbl = (UILabel *)[cell.contentView viewWithTag:102];
        
        titleLbl.text = [NSString stringWithFormat:@"%@ / %@", task.title ?: @"Без названия", task.subtitle ?: @"Серия"];
        pv.progress = task.progress;
        statusLbl.text = [self statusStringForTask:task];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSArray *tasks = [HRDownloadManager sharedManager].tasks;
    if (indexPath.row >= [tasks count]) return;
    
    HRDownloadTask *task = [tasks objectAtIndex:indexPath.row];
    
    if (task.status == HRDownloadStatusFinished) {
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:task.localFilePath error:nil];
        long long size = [[attrs objectForKey:NSFileSize] longLongValue];
        
        if (![[NSFileManager defaultManager] fileExistsAtPath:task.localFilePath] || size == 0) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Файл не найден"
                                                            message:@"Локальный файл отсутствует или пуст. Попробуйте скачать его заново."
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
            [alert show];
            return;
        }
        
        NSURL *fileURL = [NSURL fileURLWithPath:task.localFilePath];
        HRGestureMoviePlayerViewController *playerVC = [[HRGestureMoviePlayerViewController alloc] initWithContentURL:fileURL];
        playerVC.movieTitle = [NSString stringWithFormat:@"%@ (%@)", task.title ?: @"Локальный файл", task.subtitle ?: @""];
        [self presentViewController:playerVC animated:YES completion:nil];
        
    } else if (task.status == HRDownloadStatusDownloading || task.status == HRDownloadStatusWaiting) {
        [[HRDownloadManager sharedManager] pauseTask:task];
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    } else if (task.status == HRDownloadStatusPaused || task.status == HRDownloadStatusFailed) {
        [[HRDownloadManager sharedManager] resumeTask:task];
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSArray *tasks = [HRDownloadManager sharedManager].tasks;
        if (indexPath.row < [tasks count]) {
            HRDownloadTask *task = [tasks objectAtIndex:indexPath.row];
            [[HRDownloadManager sharedManager] cancelTask:task];
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [self updateEmptyState];
        }
    }
}

@end
