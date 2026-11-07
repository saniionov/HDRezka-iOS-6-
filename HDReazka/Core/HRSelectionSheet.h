#import <UIKit/UIKit.h>

@class HRSelectionSheet;

@protocol HRSelectionSheetDelegate <NSObject>
- (void)selectionSheet:(HRSelectionSheet *)sheet didSelectIndex:(NSInteger)index withTag:(NSInteger)tag;
@end

@interface HRSelectionSheet : UIView

// Строго возвращены оригинальные свойства, чтобы не ломать логику приложения
@property (nonatomic, strong, readonly) NSArray *items;
@property (nonatomic, assign, readonly) NSInteger actionTag;
@property (nonatomic, weak) id<HRSelectionSheetDelegate> delegate;

- (instancetype)initWithTitle:(NSString *)title
                        items:(NSArray *)items
                     delegate:(id<HRSelectionSheetDelegate>)delegate
                          tag:(NSInteger)tag;

- (void)showInView:(UIView *)view;
- (void)dismiss;

@end