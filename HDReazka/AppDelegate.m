#import "AppDelegate.h"
#import "HRCatalogViewController.h"
#import "HRLocalListViewController.h"
#import "HRSettingsViewController.h"
#import "HRHTTPClient.h"
#import "HRDatabase.h"
#import "HRTheme.h"
#import "HRWelcomeViewController.h"
#import "HRCustomTabBar.h"
#import <stdio.h>

@interface AppDelegate () <HRCustomTabBarDelegate>

@property (nonatomic, strong) UITabBarController *rootTabBarController;
@property (nonatomic, strong) HRCustomTabBar *customTabBar;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // 1. Запись логов только если тумблер в настройках включен
    BOOL isDebugEnabled =
    [[NSUserDefaults standardUserDefaults] boolForKey:@"HR_DEBUG_MODE"];
    
    if (isDebugEnabled) {
        NSArray *docPaths =
        NSSearchPathForDirectoriesInDomains(
                                            NSDocumentDirectory,
                                            NSUserDomainMask,
                                            YES
                                            );
        
        if ([docPaths count] > 0) {
            NSString *logPath =
            [[docPaths objectAtIndex:0]
             stringByAppendingPathComponent:@"app_logs.txt"];
            
            freopen([logPath fileSystemRepresentation], "a+", stderr);
        }
    }
    
    // 2. Очистка глобальных переопределений User-Agent
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults removeObjectForKey:@"UserAgent"];
    [defaults removeObjectForKey:@"User-Agent"];
    [defaults synchronize];
    
    // 3. Инициализация локальной базы SQLite
    [HRDatabase sharedDatabase];
    
    // 4. Создание главного окна
    self.window =
    [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    self.window.backgroundColor = [UIColor blackColor];
    
    // 5. Стилизация UINavigationBar
    [[UINavigationBar appearance] setBarStyle:UIBarStyleBlackOpaque];
    
    [[UINavigationBar appearance]
     setTintColor:[UIColor colorWithRed:0.18
                                  green:0.18
                                   blue:0.18
                                  alpha:1.0]];
    
    // Вкладка 1: Главная (Каталог)
    HRCatalogViewController *catalogVC =
    [[HRCatalogViewController alloc] init];
    
    UINavigationController *navCatalog =
    [[UINavigationController alloc]
     initWithRootViewController:catalogVC];
    
    // Вкладка 2: Избранное
    HRLocalListViewController *favoritesVC =
    [[HRLocalListViewController alloc]
     initWithMode:HRLocalListModeFavorites];
    
    UINavigationController *navFavorites =
    [[UINavigationController alloc]
     initWithRootViewController:favoritesVC];
    
    // Вкладка 3: История
    HRLocalListViewController *historyVC =
    [[HRLocalListViewController alloc]
     initWithMode:HRLocalListModeHistory];
    
    UINavigationController *navHistory =
    [[UINavigationController alloc]
     initWithRootViewController:historyVC];
    
    // Вкладка 4: Настройки
    HRSettingsViewController *settingsVC =
    [[HRSettingsViewController alloc] init];
    
    UINavigationController *navSettings =
    [[UINavigationController alloc]
     initWithRootViewController:settingsVC];
    
    // 6. Настройка UITabBarController
    self.rootTabBarController = [[UITabBarController alloc] init];
    self.rootTabBarController.viewControllers = @[navCatalog, navFavorites, navHistory, navSettings];
    self.rootTabBarController.delegate = self;
    
    // Полностью скрываем стандартный системный бар
    self.rootTabBarController.tabBar.hidden = YES;
    
    // 7. Создание и прикрепление HRCustomTabBar с адаптивной высотой (64 pt на iPad, 49 pt на iPhone)
    BOOL isIPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    CGFloat barHeight = isIPad ? 64.0f : 49.0f;
    
    CGRect barFrame = CGRectMake(0.0f,
                                 self.window.bounds.size.height - barHeight,
                                 self.window.bounds.size.width,
                                 barHeight);
    
    self.customTabBar = [[HRCustomTabBar alloc] initWithFrame:barFrame];
    self.customTabBar.delegate = self;
    self.customTabBar.contentHeight = barHeight;
    
    // Заполняем вкладки названиями и программными векторными иконками из HRTheme
    [self.customTabBar setBarItemsWithTitles:@[@"Главная", @"Избранное", @"История", @"Настройки"]
                                      images:@[[HRTheme tabBarIconHome],
     [HRTheme tabBarIconFavorites],
     [HRTheme tabBarIconHistory],
     [HRTheme tabBarIconSettings]]
                              selectedImages:nil];
    
    // Встраиваем кастомный бар поверх содержимого контроллера
    [self.rootTabBarController.view addSubview:self.customTabBar];
    
    // 8. Установка корневого контроллера и показ окна
    self.window.rootViewController = self.rootTabBarController;
    [self.window makeKeyAndVisible];
    
    // 9. Приветствие при первом запуске
    NSUserDefaults *welcomeDefaults = [NSUserDefaults standardUserDefaults];
    
    if (![welcomeDefaults boolForKey:@"HR_WELCOME_DID_READ_V1"]) {
        
        HRWelcomeViewController *welcomeVC =
        [[HRWelcomeViewController alloc] init];
        
        UINavigationController *welcomeNav =
        [[UINavigationController alloc]
         initWithRootViewController:welcomeVC];
        
        welcomeNav.modalPresentationStyle =
        UIModalPresentationFullScreen;
        
        [self.rootTabBarController presentViewController:welcomeNav
                                                animated:NO
                                              completion:nil];
    }
    
    NSLog(@"[Navigation] Запущен HRCustomTabBar с высотой %.0f pt.", barHeight);
    
    return YES;
}

#pragma mark - HRCustomTabBarDelegate

- (void)customTabBar:(HRCustomTabBar *)tabBar didSelectItemAtIndex:(NSInteger)index
{
    if (index == self.rootTabBarController.selectedIndex) {
        NSArray *controllers = [self.rootTabBarController viewControllers];
        if (index < [controllers count]) {
            UINavigationController *navigationController =
            (UINavigationController *)[controllers objectAtIndex:index];
            if ([navigationController isKindOfClass:[UINavigationController class]]) {
                [navigationController popToRootViewControllerAnimated:YES];
                if (index == 0) {
                    UIViewController *rootController =
                    [navigationController.viewControllers count] > 0
                    ? [navigationController.viewControllers objectAtIndex:0]
                    : nil;
                    if ([rootController isKindOfClass:[HRCatalogViewController class]]) {
                        [(HRCatalogViewController *)rootController resetToHomeScreen];
                    }
                }
            }
        }
    }
    self.rootTabBarController.selectedIndex = index;
}

- (void)tabBarController:(UITabBarController *)tabBarController
 didSelectViewController:(UIViewController *)viewController
{
    // Синхронизация на случай программного изменения вкладки извне
    NSInteger selectedIdx = [tabBarController.viewControllers indexOfObject:viewController];
    if (selectedIdx != NSNotFound && self.customTabBar.selectedIndex != selectedIdx) {
        [self.customTabBar selectItemAtIndex:selectedIdx animated:YES];
    }
}

- (void)applicationWillResignActive:(UIApplication *)application
{
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

@end
