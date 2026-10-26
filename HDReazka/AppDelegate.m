
#import "AppDelegate.h"
#import "HRCatalogViewController.h"
#import "HRLocalListViewController.h"
#import "HRSettingsViewController.h"
#import "HRHTTPClient.h"
#import "HRDatabase.h"
#import "HRTheme.h"
#import "HRWelcomeViewController.h"
#import <stdio.h>

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
    
    navCatalog.tabBarItem =
    [[UITabBarItem alloc] initWithTitle:@"Главная"
                                  image:[HRTheme tabBarIconHome]
                                    tag:0];
    
    // Вкладка 2: Избранное
    HRLocalListViewController *favoritesVC =
    [[HRLocalListViewController alloc]
     initWithMode:HRLocalListModeFavorites];
    
    UINavigationController *navFavorites =
    [[UINavigationController alloc]
     initWithRootViewController:favoritesVC];
    
    navFavorites.tabBarItem =
    [[UITabBarItem alloc] initWithTitle:@"Избранное"
                                  image:[HRTheme tabBarIconFavorites]
                                    tag:1];
    
    // Вкладка 3: История
    HRLocalListViewController *historyVC =
    [[HRLocalListViewController alloc]
     initWithMode:HRLocalListModeHistory];
    
    UINavigationController *navHistory =
    [[UINavigationController alloc]
     initWithRootViewController:historyVC];
    
    navHistory.tabBarItem =
    [[UITabBarItem alloc] initWithTitle:@"История"
                                  image:[HRTheme tabBarIconHistory]
                                    tag:2];
    
    // Вкладка 4: Настройки
    HRSettingsViewController *settingsVC =
    [[HRSettingsViewController alloc] init];
    
    UINavigationController *navSettings =
    [[UINavigationController alloc]
     initWithRootViewController:settingsVC];
    
    navSettings.tabBarItem =
    [[UITabBarItem alloc] initWithTitle:@"Настройки"
                                  image:[HRTheme tabBarIconSettings]
                                    tag:3];
    
    // 6. Настройка UITabBarController
    UITabBarController *tabBarController =
    [[UITabBarController alloc] init];
    
    tabBarController.viewControllers =
    @[navCatalog, navFavorites, navHistory, navSettings];
    
    tabBarController.delegate = self;
    
    // Тёмный стиль UITabBar для iOS 6
    tabBarController.tabBar.tintColor =
    [UIColor colorWithRed:0.10
                    green:0.10
                     blue:0.10
                    alpha:1.0];
    
    if ([tabBarController.tabBar
         respondsToSelector:@selector(setSelectedImageTintColor:)]) {
        
        tabBarController.tabBar.selectedImageTintColor =
        [UIColor colorWithRed:0.85
                        green:0.20
                         blue:0.20
                        alpha:1.0];
    }
    
    // 7. Установка корневого контроллера и показ окна
    self.window.rootViewController = tabBarController;
    
    [self.window makeKeyAndVisible];
    
    // 8. Приветствие при первом запуске
    NSUserDefaults *welcomeDefaults =
    [NSUserDefaults standardUserDefaults];
    
    if (![welcomeDefaults boolForKey:@"HR_WELCOME_DID_READ_V1"]) {
        
        HRWelcomeViewController *welcomeVC =
        [[HRWelcomeViewController alloc] init];
        
        UINavigationController *welcomeNav =
        [[UINavigationController alloc]
         initWithRootViewController:welcomeVC];
        
        welcomeNav.modalPresentationStyle =
        UIModalPresentationFullScreen;
        
        [tabBarController presentViewController:welcomeNav
                                       animated:NO
                                     completion:nil];
    }
    
    NSLog(@"[Navigation] Запущен таб-бар в тёмном стиле и красной подсветкой.");
    
    return YES;
}

- (void)tabBarController:(UITabBarController *)tabBarController
 didSelectViewController:(UIViewController *)viewController
{
    // Нажатие вкладки «Главная» возвращает каталог в исходное состояние.
    if (viewController ==
        [[tabBarController viewControllers] objectAtIndex:0]) {
        
        UINavigationController *navigationController =
        (UINavigationController *)viewController;
        
        [navigationController popToRootViewControllerAnimated:NO];
        
        UIViewController *rootController =
        [navigationController.viewControllers count] > 0
        ? [navigationController.viewControllers objectAtIndex:0]
        : nil;
        
        if ([rootController isKindOfClass:[HRCatalogViewController class]]) {
            [(HRCatalogViewController *)rootController resetToHomeScreen];
        }
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