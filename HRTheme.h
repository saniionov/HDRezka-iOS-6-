#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface HRTheme : NSObject

// Красная скевоморфная кнопка навигации («Обновить»)
+ (UIBarButtonItem *)createGlossyBarButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action;

// Тёмно-графитовая скевоморфная кнопка возврата («❮ Назад»)
+ (UIBarButtonItem *)createGlossyBackButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action;

// Кнопка меню (бургер) из макета
+ (UIBarButtonItem *)createGlossyMenuButtonWithTarget:(id)target action:(SEL)action;

// Кастомный заголовок с логотипом "HD Rezka"
+ (UIView *)createLogoTitleView;

// Программные иконки для UITabBar
+ (UIImage *)tabBarIconHome;
+ (UIImage *)tabBarIconFavorites;
+ (UIImage *)tabBarIconHistory;
+ (UIImage *)tabBarIconSettings;

@end