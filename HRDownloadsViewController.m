#import "HRDownloadsViewController.h"
#import "HRDownloadManager.h"
#import "HRDownloadTask.h"
#import <MediaPlayer/MediaPlayer.h>

@interface HRDownloadsViewController () <UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UILabel *emptyLabel;

@end

@implementation HRDownloadsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Загрузки";
    self.view.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    
    // Кнопка редактирования списка в навбаре
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Удалить все"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(deleteAllDownloadsTapped)];
    
    [self setupTableView];
    [self setupEmptyStateLabel];
    
    // Подписка на уведомления о прогрессе и завершении закачек
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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)deleteAllDownloadsTapped
{
    NSArray *tasks = [HRDownloadManager sharedManager].tasks;
    if ([tasks count] == 0) {
        return;
    }
    
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
    if (alertView.tag != 7301 || buttonIndex != 1) {
        return;
    }
    
    BOOL success = [[HRDownloadManager sharedManager] clearAllDownloads];
    [self.tableView reloadData];
    [self updateEmptyState];
    
    if (!success) {
        UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Не удалось удалить загрузки"
                                                             message:@"Не все файлы удалось удалить. Попробуйте ещё раз."
                                                            delegate:nil
                                                   cancelButtonTitle:@"OK"
                                                   otherButtonTitles:nil];
        [errorAlert show];
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    [super setEditing:editing animated:animated];
    [self.tableView setEditing:editing animated:animated];
}

#pragma mark - UI Setup

- (void)setupTableView
{
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.20f alpha:1.0f];
    self.tableView.rowHeight = 64.0f;
    
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
}

#pragma mark - Notifications

- (void)downloadProgressChanged:(NSNotification *)note
{
    HRDownloadTask *task = (HRDownloadTask *)note.object;
    NSArray *tasks = [HRDownloadManager sharedManager].tasks;
    NSUInteger row = [tasks indexOfObject:task];
    
    if (row != NSNotFound) {
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
        
        // Название
        UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 6, cell.contentView.bounds.size.width - 24, 20)];
        titleLabel.tag = 100;
        titleLabel.font = [UIFont boldSystemFontOfSize:14.0f];
        titleLabel.textColor = [UIColor whiteColor];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:titleLabel];
        
        // Прогресс-бар
        UIProgressView *pv = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        pv.frame = CGRectMake(12, 32, cell.contentView.bounds.size.width - 24, 9);
        pv.tag = 101;
        pv.progressTintColor = [UIColor colorWithRed:0.85 green:0.20 blue:0.20 alpha:1.0];
        pv.trackTintColor = [UIColor colorWithWhite:0.25f alpha:1.0f];
        pv.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:pv];
        
        // Статус / размер
        UILabel *statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 44, cell.contentView.bounds.size.width - 24, 16)];
        statusLabel.tag = 102;
        statusLabel.font = [UIFont systemFontOfSize:11.0f];
        statusLabel.textColor = [UIColor colorWithWhite:0.6f alpha:1.0f];
        statusLabel.backgroundColor = [UIColor clearColor];
        statusLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        [cell.contentView addSubview:statusLabel];
    }
    
    HRDownloadTask *task = [[[HRDownloadManager sharedManager] tasks] objectAtIndex:indexPath.row];
    
    UILabel *titleLabel = (UILabel *)[cell.contentView viewWithTag:100];
    UIProgressView *pv = (UIProgressView *)[cell.contentView viewWithTag:101];
    UILabel *statusLabel = (UILabel *)[cell.contentView viewWithTag:102];
    
    titleLabel.text = [NSString stringWithFormat:@"%@ — %@", task.title, task.subtitle];
    pv.progress = task.progress;
    statusLabel.text = [self statusStringForTask:task];
    
    if (task.status == HRDownloadStatusFinished) {
        pv.hidden = YES;
        statusLabel.textColor = [UIColor colorWithRed:0.20 green:0.80 blue:0.20 alpha:1.0];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        pv.hidden = NO;
        statusLabel.textColor = [UIColor colorWithWhite:0.6f alpha:1.0f];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    HRDownloadTask *task = [[[HRDownloadManager sharedManager] tasks] objectAtIndex:indexPath.row];
    
    if (task.status == HRDownloadStatusFinished) {
        // Запуск офлайн-просмотра скачанного MP4 файла
        NSURL *fileURL = [NSURL fileURLWithPath:task.localFilePath];
        MPMoviePlayerViewController *playerVC = [[MPMoviePlayerViewController alloc] initWithContentURL:fileURL];
        [playerVC.moviePlayer prepareToPlay];
        [self presentMoviePlayerViewControllerAnimated:playerVC];
    }
    else if (task.status == HRDownloadStatusDownloading) {
        [[HRDownloadManager sharedManager] pauseTask:task];
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
    else if (task.status == HRDownloadStatusPaused || task.status == HRDownloadStatusFailed) {
        [[HRDownloadManager sharedManager] resumeTask:task];
        [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
    }
}

// Удаление задачи и локального файла свайпом
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        HRDownloadTask *task = [[[HRDownloadManager sharedManager] tasks] objectAtIndex:indexPath.row];
        [[HRDownloadManager sharedManager] cancelTask:task];
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        [self updateEmptyState];
    }
}

@end