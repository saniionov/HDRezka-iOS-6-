#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface HRTheme : NSObject

// Красная скевоморфная кнопка навигации («Обновить»)
+ (UIBarButtonItem *)createGlossyBarButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action;

// Тёмно-графитовая скевоморфная кнопка возврата («Назад»)
+ (UIBarButtonItem *)createGlossyBackButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action;

// Кнопка меню (бургер)
+ (UIBarButtonItem *)createGlossyMenuButtonWithTarget:(id)target action:(SEL)action;

// Кнопка обновления карточки фильма («↻»)
+ (UIBarButtonItem *)createRefreshIconBarButtonWithTarget:(id)target action:(SEL)action;

// Векторная иконка загрузок и кнопка для навигационной панели каталога
+ (UIImage *)createDownloadBarButtonIconWithColor:(UIColor *)iconColor;
+ (UIButton *)createDownloadNavButtonWithTarget:(id)target action:(SEL)action;

// Кастомный заголовок с логотипом "HD Rezka"
+ (UIView *)createLogoTitleView;

// Программные иконки для UITabBar
+ (UIImage *)tabBarIconHome;
+ (UIImage *)tabBarIconFavorites;
+ (UIImage *)tabBarIconHistory;
+ (UIImage *)tabBarIconSettings;

@end