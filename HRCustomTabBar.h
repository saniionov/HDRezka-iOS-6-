//
//  HRCustomTabBar.h
//  HDRezka
//

#import <UIKit/UIKit.h>

@class HRCustomTabBar;

@protocol HRCustomTabBarDelegate <NSObject>
@optional
- (BOOL)customTabBar:(HRCustomTabBar *)tabBar shouldSelectItemAtIndex:(NSInteger)index;
- (void)customTabBar:(HRCustomTabBar *)tabBar didSelectItemAtIndex:(NSInteger)index;
@end

@interface HRCustomTabBar : UIView

@property (nonatomic, weak) id<HRCustomTabBarDelegate> delegate;
@property (nonatomic, assign) NSInteger selectedIndex;
@property (nonatomic, assign) CGFloat contentHeight;

- (void)setBarItemsWithTitles:(NSArray *)titles
                       images:(NSArray *)images
               selectedImages:(NSArray *)selectedImages;

- (void)setBadgeValue:(NSString *)badgeValue forIndex:(NSInteger)index animated:(BOOL)animated;
- (NSString *)badgeValueForIndex:(NSInteger)index;
- (void)selectItemAtIndex:(NSInteger)index animated:(BOOL)animated;
- (void)setBarHidden:(BOOL)hidden animated:(BOOL)animated;

@end