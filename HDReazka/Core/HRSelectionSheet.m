#import "HRSelectionSheet.h"
#import <QuartzCore/QuartzCore.h>

#pragma mark - Кастомная кнопка меню (HRActionSheetButton)

@interface HRActionSheetButton : UIButton
@property (nonatomic, assign) BOOL isCancelStyle;
@property (nonatomic, strong) CAGradientLayer *glossLayer;

+ (instancetype)buttonWithCancelStyle:(BOOL)isCancel;
@end

@implementation HRActionSheetButton

+ (instancetype)buttonWithCancelStyle:(BOOL)isCancel
{
    HRActionSheetButton *btn = [HRActionSheetButton buttonWithType:UIButtonTypeCustom];
    btn.isCancelStyle = isCancel;
    
    btn.layer.cornerRadius = 9.0f;
    btn.layer.masksToBounds = YES;
    btn.layer.borderWidth = 0.0f;
    
    btn.glossLayer = [CAGradientLayer layer];
    btn.glossLayer.frame = btn.bounds;
    [btn.layer insertSublayer:btn.glossLayer atIndex:0];
    
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    CGFloat fontSize = isPad ? 18.5f : 16.5f;
    
    if (isCancel) {
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:fontSize];
        [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [btn setTitleShadowColor:[UIColor blackColor] forState:UIControlStateNormal];
        btn.titleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
    } else {
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:fontSize];
        [btn setTitleColor:[UIColor colorWithRed:0.95f green:0.25f blue:0.25f alpha:1.0f] forState:UIControlStateNormal];
        [btn setTitleShadowColor:[UIColor blackColor] forState:UIControlStateNormal];
        btn.titleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
    }
    
    [btn updateGradientsForState:UIControlStateNormal];
    
    return btn;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    if (self.glossLayer) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.glossLayer.frame = self.bounds;
        [CATransaction commit];
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    [self updateGradientsForState:highlighted ? UIControlStateHighlighted : UIControlStateNormal];
}

- (void)updateGradientsForState:(UIControlState)state
{
    if (self.isCancelStyle) {
        if (state == UIControlStateHighlighted) {
            self.glossLayer.colors = @[
                                       (id)[UIColor colorWithWhite:0.10f alpha:1.0f].CGColor,
                                       (id)[UIColor colorWithWhite:0.05f alpha:1.0f].CGColor
                                       ];
        } else {
            self.glossLayer.locations = @[@(0.0f), @(0.50f), @(1.0f)];
            self.glossLayer.colors = @[
                                       (id)[UIColor colorWithWhite:0.35f alpha:1.0f].CGColor,
                                       (id)[UIColor colorWithWhite:0.18f alpha:1.0f].CGColor,
                                       (id)[UIColor colorWithWhite:0.10f alpha:1.0f].CGColor
                                       ];
        }
    } else {
        if (state == UIControlStateHighlighted) {
            self.glossLayer.colors = @[
                                       (id)[UIColor colorWithRed:0.100f green:0.100f blue:0.110f alpha:1.0f].CGColor,
                                       (id)[UIColor colorWithRed:0.070f green:0.070f blue:0.080f alpha:1.0f].CGColor
                                       ];
        } else {
            self.glossLayer.locations = @[@(0.0f), @(0.50f), @(1.0f)];
            self.glossLayer.colors = @[
                                       (id)[UIColor colorWithRed:0.200f green:0.200f blue:0.215f alpha:1.0f].CGColor,
                                       (id)[UIColor colorWithRed:0.150f green:0.150f blue:0.161f alpha:1.0f].CGColor,
                                       (id)[UIColor colorWithRed:0.100f green:0.100f blue:0.110f alpha:1.0f].CGColor
                                       ];
        }
    }
}

@end

#pragma mark - HRSelectionSheet (Всплывающее меню)

@interface HRSelectionSheet ()
@property (nonatomic, strong) UIView *overlayView;
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) HRActionSheetButton *cancelButton;

@property (nonatomic, strong, readwrite) NSArray *items;
@property (nonatomic, assign, readwrite) NSInteger actionTag;
@property (nonatomic, assign) BOOL isAnimatingOut;
@end

@implementation HRSelectionSheet

- (instancetype)initWithTitle:(NSString *)title items:(NSArray *)items delegate:(id<HRSelectionSheetDelegate>)delegate tag:(NSInteger)tag
{
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        _items = items ?: @[];
        _delegate = delegate;
        _actionTag = tag;
        _isAnimatingOut = NO;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        [self setupUI];
    }
    return self;
}

- (void)setupUI
{
    self.overlayView = [[UIView alloc] initWithFrame:CGRectZero];
    self.overlayView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.90f];
    self.overlayView.alpha = 0.0f;
    [self addSubview:self.overlayView];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
    [self.overlayView addGestureRecognizer:tap];
    
    // Большая рамка для подменю
    self.containerView = [[UIView alloc] initWithFrame:CGRectZero];
    self.containerView.backgroundColor = [UIColor colorWithWhite:0.08f alpha:0.95f];
    self.containerView.layer.cornerRadius = 12.0f;
    self.containerView.layer.borderColor = [UIColor colorWithWhite:0.25f alpha:1.0f].CGColor;
    self.containerView.layer.borderWidth = 2.0f;
    self.containerView.clipsToBounds = YES;
    [self addSubview:self.containerView];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
    self.scrollView.backgroundColor = [UIColor clearColor];
    self.scrollView.showsVerticalScrollIndicator = NO;
    self.scrollView.alwaysBounceVertical = YES;
    [self.containerView addSubview:self.scrollView];
    
    for (NSInteger i = 0; i < self.items.count; i++) {
        HRActionSheetButton *btn = [HRActionSheetButton buttonWithCancelStyle:NO];
        [btn setTitle:self.items[i] forState:UIControlStateNormal];
        btn.tag = i;
        [btn addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.scrollView addSubview:btn];
    }
    
    self.cancelButton = [HRActionSheetButton buttonWithCancelStyle:YES];
    [self.cancelButton setTitle:@"Отмена" forState:UIControlStateNormal];
    self.cancelButton.tag = -1;
    [self.cancelButton addTarget:self action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.containerView addSubview:self.cancelButton];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (self.isAnimatingOut) return;
    
    self.overlayView.frame = self.bounds;
    
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    CGFloat sideMargin = 10.0f;
    CGFloat btnHeight = isPad ? 52.0f : 46.0f;
    CGFloat spacing = isPad ? 10.0f : 8.0f;
    CGFloat cancelSpacing = isPad ? 18.0f : 15.0f;
    CGFloat innerPadding = isPad ? 12.0f : 8.0f;
    
    CGFloat sheetWidth = self.bounds.size.width - (sideMargin * 2.0f);
    if (isPad && sheetWidth > 500.0f) {
        sheetWidth = 500.0f;
    }
    CGFloat contentWidth = sheetWidth - (innerPadding * 2.0f);
    
    CGFloat itemsContentH = (self.items.count * btnHeight) + (self.items.count > 0 ? (self.items.count - 1) * spacing : 0);
    
    CGFloat maxScrollH = self.bounds.size.height - (btnHeight + cancelSpacing + sideMargin + 40.0f + innerPadding * 2.0f);
    if (maxScrollH < btnHeight) maxScrollH = btnHeight;
    
    CGFloat scrollH = MIN(itemsContentH, maxScrollH);
    
    self.scrollView.frame = CGRectMake(innerPadding, innerPadding, contentWidth, scrollH);
    self.scrollView.contentSize = CGSizeMake(contentWidth, itemsContentH);
    
    CGFloat currentY = 0.0f;
    for (UIView *sub in self.scrollView.subviews) {
        if ([sub isKindOfClass:[HRActionSheetButton class]]) {
            sub.frame = CGRectMake(0.0f, currentY, contentWidth, btnHeight);
            currentY += btnHeight + spacing;
        }
    }
    
    CGFloat cancelY = scrollH + innerPadding + cancelSpacing;
    self.cancelButton.frame = CGRectMake(innerPadding, cancelY, contentWidth, btnHeight);
    
    CGFloat containerH = cancelY + btnHeight + innerPadding;
    
    CGFloat containerX = floorf((self.bounds.size.width - sheetWidth) / 2.0f);
    self.containerView.frame = CGRectMake(containerX, self.bounds.size.height - containerH - sideMargin, sheetWidth, containerH);
}

- (void)showInView:(UIView *)view
{
    if (!view) return;
    
    self.frame = view.bounds;
    [view addSubview:self];
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
    
    CGRect startFrame = self.containerView.frame;
    startFrame.origin.y = self.bounds.size.height;
    self.containerView.frame = startFrame;
    
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.overlayView.alpha = 1.0f;
        CGRect endFrame = self.containerView.frame;
        endFrame.origin.y = self.bounds.size.height - endFrame.size.height - 10.0f;
        self.containerView.frame = endFrame;
    } completion:nil];
}

- (void)dismiss
{
    [self dismissWithClickedButtonIndex:-1];
}

- (void)dismissWithClickedButtonIndex:(NSInteger)index
{
    self.isAnimatingOut = YES;
    [UIView animateWithDuration:0.3f delay:0.0f options:UIViewAnimationOptionCurveEaseIn animations:^{
        self.overlayView.alpha = 0.0f;
        CGRect frame = self.containerView.frame;
        frame.origin.y = self.bounds.size.height;
        self.containerView.frame = frame;
    } completion:^(BOOL finished) {
        if (index != -1 && self.delegate && [self.delegate respondsToSelector:@selector(selectionSheet:didSelectIndex:withTag:)]) {
            [self.delegate selectionSheet:self didSelectIndex:index withTag:self.actionTag];
        }
        [self removeFromSuperview];
    }];
}

- (void)buttonTapped:(UIButton *)sender
{
    [self dismissWithClickedButtonIndex:sender.tag];
}

@end