#import "HRSettingsViewController.h"
#import "HRHTTPClient.h"
#import "HRImageCache.h"
#import "HRDatabase.h"
#import "HRDownloadManager.h"
#import "HRPublicAuthViewController.h" // <-- Подключаем новый модуль
#import <QuartzCore/QuartzCore.h>

static NSString * const kHRPreferredQualityKey = @"HR_DEFAULT_QUALITY";

@interface HRSettingsViewController () <UITextFieldDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) UISwitch *modeSwitch;
@property (nonatomic, strong) UITextField *domainField;
@property (nonatomic, strong) UITextField *loginField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UITextField *publicDomainField;
@property (nonatomic, strong) NSArray *qualities;
@property (nonatomic, copy) NSString *selectedQuality;

@end

@implementation HRSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Настройки";
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    
    self.qualities = @[@"360p", @"480p", @"720p", @"1080p"];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.selectedQuality = [defaults stringForKey:kHRPreferredQualityKey] ?: @"720p";
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.20f alpha:1.0f];
    
    UIView *bgView = [[UIView alloc] initWithFrame:self.tableView.bounds];
    bgView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    self.tableView.backgroundView = bgView;
    [self.view addSubview:self.tableView];
    
    CGFloat fieldWidth = self.view.bounds.size.width - 130;
    
    self.domainField = [[UITextField alloc] initWithFrame:CGRectMake(110, 10, fieldWidth, 26)];
    self.domainField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.domainField.placeholder = @"https://rezka.fi";
    self.domainField.text = [defaults stringForKey:@"HR_MIRROR_DOMAIN"] ?: @"https://rezka.fi";
    self.domainField.textColor = [UIColor whiteColor];
    self.domainField.delegate = self;
    self.domainField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.domainField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    
    self.loginField = [[UITextField alloc] initWithFrame:CGRectMake(110, 10, fieldWidth, 26)];
    self.loginField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.loginField.placeholder = @"Email / Логин";
    self.loginField.text = [defaults stringForKey:@"HR_AUTH_LOGIN"];
    self.loginField.textColor = [UIColor whiteColor];
    self.loginField.delegate = self;
    self.loginField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.loginField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    
    self.passwordField = [[UITextField alloc] initWithFrame:CGRectMake(110, 10, fieldWidth, 26)];
    self.passwordField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.passwordField.placeholder = @"Пароль";
    self.passwordField.text = [defaults stringForKey:@"HR_AUTH_PASSWORD"];
    self.passwordField.textColor = [UIColor whiteColor];
    self.passwordField.secureTextEntry = YES;
    self.passwordField.delegate = self;
    
    self.publicDomainField = [[UITextField alloc] initWithFrame:CGRectMake(110, 10, fieldWidth, 26)];
    self.publicDomainField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.publicDomainField.placeholder = @"https://rezka.ag";
    self.publicDomainField.text = ([HRHTTPClient sharedClient].authMode == HRAuthModePublic && [HRHTTPClient sharedClient].baseURLString) ? [HRHTTPClient sharedClient].baseURLString : @"https://rezka.ag";
    self.publicDomainField.textColor = [UIColor whiteColor];
    self.publicDomainField.delegate = self;
    self.publicDomainField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.publicDomainField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    
    // Переключатель режима: ВКЛ — персональный аккаунт, ВЫКЛ — публичный доступ.
    self.modeSwitch = [[UISwitch alloc] init];
    self.modeSwitch.on = ([HRHTTPClient sharedClient].authMode != HRAuthModePublic);
    self.modeSwitch.onTintColor = [UIColor colorWithRed:0.62 green:0.08 blue:0.08 alpha:1.0];
    [self.modeSwitch addTarget:self action:@selector(modeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)modeSwitchChanged:(UISwitch *)sender
{
    [self.view endEditing:YES];
    if (sender.on) {
        NSString *url = [self.domainField.text length] > 0 ? self.domainField.text : @"https://rezka.fi";
        [[HRHTTPClient sharedClient] switchToMode:HRAuthModePersonal newBaseURL:url];
    } else {
        NSString *url = [self.publicDomainField.text length] > 0 ? self.publicDomainField.text : @"https://rezka.ag";
        [[HRHTTPClient sharedClient] switchToMode:HRAuthModePublic newBaseURL:url];
    }
    [self.tableView reloadData];
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return 1;
    if (section == 1) {
        return self.modeSwitch.on ? 4 : 2;
    }
    if (section == 2) return [self.qualities count];
    if (section == 3) return 2;
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UILabel *headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 6, tableView.bounds.size.width - 30, 22)];
    headerLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    headerLabel.textColor = [UIColor colorWithWhite:0.75f alpha:1.0f];
    headerLabel.backgroundColor = [UIColor clearColor];
    
    switch (section) {
        case 0: headerLabel.text = @"Режим подключения"; break;
        case 1: headerLabel.text = self.modeSwitch.on ? @"Сервер и учетная запись" : @"Публичный доступ без аккаунта"; break;
        case 2: headerLabel.text = @"Качество видео по умолчанию"; break;
        case 3: headerLabel.text = @"Сброс данных"; break;
        default: return nil;
    }
    
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 30)];
    [headerView addSubview:headerLabel];
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 32.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellID = @"DarkSettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellID];
    }
    
    for (UIView *v in cell.contentView.subviews) {
        if (v == self.modeSwitch || v == self.domainField || v == self.loginField || v == self.passwordField || v == self.publicDomainField) {
            [v removeFromSuperview];
        }
    }
    
    cell.textLabel.text = nil;
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    cell.detailTextLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor colorWithRed:0.14 green:0.14 blue:0.14 alpha:1.0];
    
    if (indexPath.section == 0) {
        cell.textLabel.text = @"Персональный аккаунт";
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16.0f];
        self.modeSwitch.frame = CGRectMake(cell.contentView.bounds.size.width - self.modeSwitch.bounds.size.width - 12, 7, self.modeSwitch.bounds.size.width, self.modeSwitch.bounds.size.height);
        self.modeSwitch.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [cell.contentView addSubview:self.modeSwitch];
    }
    else if (indexPath.section == 1) {
        if (self.modeSwitch.on) {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Зеркало:";
                [cell.contentView addSubview:self.domainField];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Email:";
                [cell.contentView addSubview:self.loginField];
            } else if (indexPath.row == 2) {
                cell.textLabel.text = @"Пароль:";
                [cell.contentView addSubview:self.passwordField];
            } else if (indexPath.row == 3) {
                cell.textLabel.text = @"Войти / Авторизоваться";
                cell.textLabel.textColor = [UIColor colorWithRed:0.20 green:0.80 blue:0.20 alpha:1.0];
                cell.textLabel.textAlignment = NSTextAlignmentCenter;
                cell.selectionStyle = UITableViewCellSelectionStyleGray;
            }
        } else {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Домен:";
                [cell.contentView addSubview:self.publicDomainField];
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Авторизация";
                cell.textLabel.textColor = [UIColor colorWithRed:0.85 green:0.20 blue:0.20 alpha:1.0];
                cell.textLabel.textAlignment = NSTextAlignmentCenter;
                cell.selectionStyle = UITableViewCellSelectionStyleGray;
            }
        }
    }
    else if (indexPath.section == 2) {
        NSString *q = [self.qualities objectAtIndex:indexPath.row];
        cell.textLabel.text = q;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        if ([q isEqualToString:self.selectedQuality]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        }
    }
    else if (indexPath.section == 3) {
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.selectionStyle = UITableViewCellSelectionStyleGray;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16.0f];
        
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Сбросить авторизацию";
            cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.65 blue:0.20 alpha:1.0];
        } else {
            cell.textLabel.text = @"Полный сброс приложения";
            cell.textLabel.textColor = [UIColor colorWithRed:0.95 green:0.20 blue:0.20 alpha:1.0];
        }
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.view endEditing:YES];
    
    if (indexPath.section == 1) {
        if (self.modeSwitch.on && indexPath.row == 3) {
            [self performLogin];
        } else if (!self.modeSwitch.on && indexPath.row == 1) {
            [self launchPublicAuthModule];
        }
    }
    else if (indexPath.section == 2) {
        self.selectedQuality = [self.qualities objectAtIndex:indexPath.row];
        [[NSUserDefaults standardUserDefaults] setObject:self.selectedQuality forKey:kHRPreferredQualityKey];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self.tableView reloadData];
    }
    else if (indexPath.section == 3) {
        if (indexPath.row == 0) {
            [self promptAuthReset];
        } else if (indexPath.row == 1) {
            [self promptFullReset];
        }
    }
}

- (void)showAlertTitle:(NSString *)title message:(NSString *)msg
{
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:title message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [a show];
}

#pragma mark - Авторизация (Персональный режим)

- (void)performLogin
{
    NSString *login = [self.loginField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *password = self.passwordField.text;
    NSString *domain = [self.domainField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (login.length == 0 || password.length == 0) {
        [self showAlertTitle:@"Внимание" message:@"Пожалуйста, введите Email и Пароль."];
        return;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:login forKey:@"HR_AUTH_LOGIN"];
    [defaults setObject:password forKey:@"HR_AUTH_PASSWORD"];
    if (domain.length > 0) {
        [defaults setObject:domain forKey:@"HR_MIRROR_DOMAIN"];
        [[HRHTTPClient sharedClient] switchToMode:HRAuthModePersonal newBaseURL:domain];
    }
    [defaults synchronize];
    
    NSDictionary *params = @{
                             @"login_name": login,
                             @"login_password": password,
                             @"login_not_save": @"0"
                             };
    
    [[HRHTTPClient sharedClient] POST:@"/ajax/login/" parameters:params completion:^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) {
                [self showAlertTitle:@"Ошибка сети" message:error.localizedDescription ?: @"Не удалось связаться с сервером."];
                return;
            }
            
            NSError *jsonErr = nil;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
            BOOL ok = [[json objectForKey:@"success"] boolValue];
            
            if (ok) {
                [self showAlertTitle:@"Успех" message:@"Авторизация прошла успешно. Приложение использует персональное зеркало."];
            } else {
                [self showAlertTitle:@"Ошибка" message:@"Неверный логин или пароль. Попробуйте еще раз."];
            }
        });
    }];
}

#pragma mark - Запуск выделенного модуля авторизации (Публичный режим)

- (void)launchPublicAuthModule
{
    NSString *publicUrl = [self.publicDomainField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (publicUrl.length == 0) publicUrl = @"https://rezka.ag";
    
    [[HRHTTPClient sharedClient] switchToMode:HRAuthModePublic newBaseURL:publicUrl];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    HRPublicAuthViewController *authVC = [[HRPublicAuthViewController alloc] init];
    authVC.targetURLString = publicUrl;
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:authVC];
    nav.navigationBar.barStyle = UIBarStyleBlack;
    
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Сброс только авторизации

- (void)promptAuthReset
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Сброс авторизации"
                                                    message:@"Будут удалены сохранённые логин, пароль и cookies HDRezka. История, избранное, загрузки, зеркало и остальные настройки останутся. Продолжить?"
                                                   delegate:self
                                          cancelButtonTitle:@"Отмена"
                                          otherButtonTitles:@"Сбросить", nil];
    alert.tag = 998;
    [alert show];
}

- (void)executeAuthReset
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults removeObjectForKey:@"HR_AUTH_LOGIN"];
    [defaults removeObjectForKey:@"HR_AUTH_PASSWORD"];
    [defaults synchronize];
    
    // Удаляем cookies только доменов HDRezka, не трогая cookies других сайтов.
    [[HRHTTPClient sharedClient] purgeRezkaCookies];
    
    self.loginField.text = @"";
    self.passwordField.text = @"";
    [self.tableView reloadData];
    
    [self showAlertTitle:@"Авторизация сброшена"
                 message:@"Сохранённые данные входа и сессия HDRezka удалены. При следующем входе введите логин и пароль заново." ];
}

#pragma mark - Полный сброс приложения

- (void)promptFullReset
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Внимание"
                                                    message:@"Это удалит всю историю, избранное, скачанные файлы, авторизацию и настройки. Приложение вернётся к заводскому состоянию. Продолжить?"
                                                   delegate:self
                                          cancelButtonTitle:@"Отмена"
                                          otherButtonTitles:@"Сбросить", nil];
    alert.tag = 999;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == alertView.cancelButtonIndex) {
        return;
    }
    
    if (alertView.tag == 998) {
        [self executeAuthReset];
    } else if (alertView.tag == 999) {
        [self executeFullReset];
    }
}

- (void)executeFullReset
{
    // Сначала закрываем SQLite: удаление файла при открытом соединении
    // может оставить текущий singleton работающим со старым файлом.
    HRDatabase *database = [HRDatabase sharedDatabase];
    if (![database closeDatabase]) {
        [self showAlertTitle:@"Сброс не выполнен"
                     message:@"Не удалось безопасно закрыть базу данных. Повторите попытку после перезапуска приложения."];
        return;
    }
    
    // Останавливаем активные загрузки и закрываем файлы до удаления каталога.
    // Если каталог не удалось очистить, переоткрываем прежнюю базу и прекращаем сброс.
    if (![[HRDownloadManager sharedManager] clearAllDownloads]) {
        [database setupDatabase];
        [self showAlertTitle:@"Сброс не выполнен"
                     message:@"Не удалось безопасно очистить загрузки. База данных оставлена без изменений; попробуйте ещё раз."];
        return;  
    }  
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);  
    NSString *docDir = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;  
    NSString *dbPath = [docDir stringByAppendingPathComponent:@"hdrezka_storage.sqlite"];  
    
    // Не продолжаем частичный сброс, если существующую базу не удалось удалить.  
    NSError *dbError = nil;  
    NSFileManager *fileManager = [NSFileManager defaultManager];  
    if ([fileManager fileExistsAtPath:dbPath] &&  
        ![fileManager removeItemAtPath:dbPath error:&dbError]) {  
        [database setupDatabase]; // Возвращаем доступ к прежней базе.  
        [self showAlertTitle:@"Сброс не выполнен"  
                     message:@"Не удалось удалить файл базы данных. Загрузки уже остановлены и очищены; остальные настройки и авторизация сохранены."];  
        return;  
    }  
    
    // Открываем новую пустую базу и создаём таблицы до продолжения работы.  
    [database setupDatabase];  
    
    NSString *appDomain = [[NSBundle mainBundle] bundleIdentifier];  
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];  
    [defaults removePersistentDomainForName:appDomain];  
    [defaults synchronize];  
    
    NSHTTPCookieStorage *storage = [NSHTTPCookieStorage sharedHTTPCookieStorage];  
    for (NSHTTPCookie *cookie in [storage cookies]) {  
        [storage deleteCookie:cookie];  
    }  
    
    [[HRImageCache sharedCache] clearCache];  
    
    [self showAlertTitle:@"Сброс завершён" message:@"Приложение полностью очищено. Рекомендуется перезапустить приложение (закрыть в многозадачности)."];  
    
    self.selectedQuality = @"720p";  
    self.domainField.text = @"https://rezka.fi";  
    self.loginField.text = @"";  
    self.passwordField.text = @"";  
    self.publicDomainField.text = @"https://rezka.ag";  
    self.modeSwitch.on = YES;  
    
    [self.tableView reloadData];  
}  

- (BOOL)textFieldShouldReturn:(UITextField *)textField  
{  
    [textField resignFirstResponder];  
    return YES;  
}  

@end  
