//
//  HRCustomTabBar.m
//  HDRezka
//

#import "HRCustomTabBar.h"
#import <QuartzCore/QuartzCore.h>

#pragma mark - Хелпер тонирования маски иконки для iOS 6+

static UIImage *HRTintedImageWithColor(UIImage *image, UIColor *color)
{
    if (!image || !color) return image;
    
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        UIGraphicsEndImageContext();
        return image;
    }
    
    CGRect rect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);
    
    // Отрисовываем исходное изображение
    [image drawInRect:rect];
    
    // Накладываем цвет поверх альфа-канала маски
    CGContextSetBlendMode(context, kCGBlendModeSourceIn);
    CGContextSetFillColorWithColor(context, color.CGColor);
    CGContextFillRect(context, rect);
    
    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return tintedImage ?: image;
}

#pragma mark - Элемент с двухуровневой маской (чистые скругленные углы без прямоугольных артефактов)

@interface _HRCustomTabBarItemControl : UIControl

// Внешний контейнер отвечает строго за неоновую тень наружу
@property (nonatomic, strong) UIView *activeShadowView;

// Внутренний контейнер строго с masksToBounds = YES, отсекающий углы прямоугольников
@property (nonatomic, strong) UIView *activeClippedContainer;

@property (nonatomic, strong) CAGradientLayer *activeGradient;
@property (nonatomic, strong) CAGradientLayer *activeGlossLayer;
@property (nonatomic, strong) CALayer *activeTopHighlight;
@property (nonatomic, strong) CALayer *activeBottomShadow;

@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIView *badgeContainer;
@property (nonatomic, strong) UILabel *badgeLabel;
@property (nonatomic, copy) NSString *badgeValue;

@property (nonatomic, strong) UIImage *normalImage;
@property (nonatomic, strong) UIImage *selectedImage;
@property (nonatomic, strong) UIImage *cachedTintedSelectedImage;

- (void)setBadgeValue:(NSString *)badgeValue animated:(BOOL)animated;

@end

@implementation _HRCustomTabBarItemControl

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        
        BOOL isIPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
        CGFloat cornerR = isIPad ? 12.0f : 8.0f;
        
        // 1. Внешний контейнер для неоновой тени (masksToBounds = NO)
        _activeShadowView = [[UIView alloc] initWithFrame:CGRectZero];
        _activeShadowView.userInteractionEnabled = NO;
        _activeShadowView.backgroundColor = [UIColor clearColor];
        _activeShadowView.layer.masksToBounds = NO;
        _activeShadowView.layer.cornerRadius = cornerR;
        _activeShadowView.hidden = YES;
        
        _activeShadowView.layer.shadowColor =
        [UIColor colorWithRed:0.95f
                        green:0.04f
                         blue:0.08f
                        alpha:1.0f].CGColor;
        
        _activeShadowView.layer.shadowOffset = CGSizeMake(0.0f, 1.0f);
        _activeShadowView.layer.shadowOpacity = isIPad ? 0.60f : 0.55f;
        _activeShadowView.layer.shadowRadius = isIPad ? 12.0f : 8.0f;
        
        // 2. Внутренний контейнер с жестким отсечением углов (masksToBounds = YES)
        // Это полностью исключает проступание прямоугольных углов слоев наружу!
        _activeClippedContainer = [[UIView alloc] initWithFrame:CGRectZero];
        _activeClippedContainer.userInteractionEnabled = NO;
        _activeClippedContainer.backgroundColor = [UIColor clearColor];
        _activeClippedContainer.layer.masksToBounds = YES;
        _activeClippedContainer.layer.cornerRadius = cornerR;
        
        _activeClippedContainer.layer.borderWidth = 0.5f;
        _activeClippedContainer.layer.borderColor =
        [UIColor colorWithRed:0.65f green:0.08f blue:0.12f alpha:0.45f].CGColor;
        
        // 6-точечный шелковый градиент
        _activeGradient = [CAGradientLayer layer];
        _activeGradient.cornerRadius = cornerR;
        _activeGradient.masksToBounds = YES;
        
        _activeGradient.colors = @[
                                   (id)[UIColor colorWithRed:0.24f
                                                       green:0.015f
                                                        blue:0.026f
                                                       alpha:0.82f].CGColor,
                                   
                                   (id)[UIColor colorWithRed:0.46f
                                                       green:0.025f
                                                        blue:0.048f
                                                       alpha:0.84f].CGColor,
                                   
                                   (id)[UIColor colorWithRed:0.62f
                                                       green:0.032f
                                                        blue:0.060f
                                                       alpha:0.86f].CGColor,
                                   
                                   (id)[UIColor colorWithRed:0.34f
                                                       green:0.016f
                                                        blue:0.032f
                                                       alpha:0.80f].CGColor,
                                   
                                   (id)[UIColor colorWithRed:0.11f
                                                       green:0.007f
                                                        blue:0.013f
                                                       alpha:0.76f].CGColor,
                                   
                                   (id)[UIColor colorWithRed:0.02f
                                                       green:0.003f
                                                        blue:0.006f
                                                       alpha:0.72f].CGColor
                                   ];
        
        _activeGradient.locations = @[
                                      @(0.0f),
                                      @(0.16f),
                                      @(0.36f),
                                      @(0.58f),
                                      @(0.80f),
                                      @(1.0f)
                                      ];
        
        [_activeClippedContainer.layer addSublayer:_activeGradient];
        
        // Глянец (Gloss)
        _activeGlossLayer = [CAGradientLayer layer];
        _activeGlossLayer.cornerRadius = cornerR;
        _activeGlossLayer.masksToBounds = YES;
        
        _activeGlossLayer.colors = @[
                                     (id)[UIColor colorWithWhite:1.0f alpha:0.26f].CGColor,
                                     (id)[UIColor colorWithWhite:1.0f alpha:0.04f].CGColor
                                     ];
        
        [_activeClippedContainer.layer addSublayer:_activeGlossLayer];
        
        // Световая верхняя кромка
        _activeTopHighlight = [CALayer layer];
        _activeTopHighlight.backgroundColor =
        [UIColor colorWithWhite:1.0f alpha:0.32f].CGColor;
        
        [_activeClippedContainer.layer addSublayer:_activeTopHighlight];
        
        // Нижняя тень-фаска
        _activeBottomShadow = [CALayer layer];
        _activeBottomShadow.backgroundColor =
        [UIColor colorWithWhite:0.0f alpha:0.40f].CGColor;
        
        [_activeClippedContainer.layer addSublayer:_activeBottomShadow];
        
        // Вкладываем обрезанный контейнер внутрь контейнера тени
        [_activeShadowView addSubview:_activeClippedContainer];
        [self addSubview:_activeShadowView];
        
        // 3. Иконка
        _iconImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _iconImageView.contentMode = UIViewContentModeScaleAspectFit;
        _iconImageView.userInteractionEnabled = NO;
        
        [self addSubview:_iconImageView];
        
        // 4. Текст вкладки
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.font = [UIFont boldSystemFontOfSize:isIPad ? 15.0f : 11.5f];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.shadowOffset = CGSizeMake(0.0f, -1.0f);
        _titleLabel.shadowColor =
        [UIColor colorWithWhite:0.0f alpha:0.95f];
        _titleLabel.userInteractionEnabled = NO;
        
        [self addSubview:_titleLabel];
        
        // 5. Бейдж
        _badgeContainer = [[UIView alloc] initWithFrame:CGRectZero];
        
        _badgeContainer.backgroundColor =
        [UIColor colorWithRed:0.85f
                        green:0.04f
                         blue:0.06f
                        alpha:1.0f];
        
        _badgeContainer.layer.borderColor =
        [UIColor colorWithWhite:0.85f alpha:0.6f].CGColor;
        
        _badgeContainer.layer.borderWidth = 0.5f;
        _badgeContainer.layer.masksToBounds = YES;
        _badgeContainer.hidden = YES;
        _badgeContainer.userInteractionEnabled = NO;
        
        _badgeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _badgeLabel.font = [UIFont boldSystemFontOfSize:isIPad ? 12.0f : 10.0f];
        _badgeLabel.textColor = [UIColor whiteColor];
        _badgeLabel.textAlignment = NSTextAlignmentCenter;
        _badgeLabel.backgroundColor = [UIColor clearColor];
        _badgeLabel.userInteractionEnabled = NO;
        
        [_badgeContainer addSubview:_badgeLabel];
        [self addSubview:_badgeContainer];
    }
    
    return self;
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    BOOL isIPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    
    CGFloat bgW = isIPad ? 160.0f : ((w > 120.0f) ? 96.0f : MAX(0.0f, w - 10.0f));
    CGFloat bgX = (w - bgW) / 2.0f;
    CGFloat bgH = isIPad ? MAX(0.0f, h - 6.0f) : MAX(0.0f, h - 4.0f);
    CGFloat bgY = isIPad ? 3.0f : 2.0f;
    CGFloat cornerR = isIPad ? 12.0f : 8.0f;
    
    self.activeShadowView.frame = CGRectMake(bgX, bgY, bgW, bgH);
    self.activeClippedContainer.frame = self.activeShadowView.bounds;
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    self.activeGradient.frame = self.activeClippedContainer.bounds;
    self.activeGlossLayer.frame = CGRectMake(0.0f, 0.0f, bgW, bgH * 0.50f);
    
    // Прямоугольные вспомогательные полоски сдвинуты внутрь от боковых скруглений (зазор cornerR),
    // благодаря чему они физически не попадают в зону дуги скругления
    CGFloat insetX = cornerR;
    self.activeTopHighlight.frame = CGRectMake(insetX, 0.0f, bgW - (insetX * 2.0f), 1.0f);
    self.activeBottomShadow.frame = CGRectMake(insetX, bgH - 1.0f, bgW - (insetX * 2.0f), 1.0f);
    
    self.activeShadowView.layer.shadowPath =
    [UIBezierPath bezierPathWithRoundedRect:self.activeShadowView.bounds
                               cornerRadius:cornerR].CGPath;
    
    [CATransaction commit];
    
    // Значок: 34x34 pt на iPad (на iPhone 25x25 pt)
    CGFloat iconSide = isIPad ? 34.0f : 25.0f;
    CGFloat iconY = isIPad ? 5.0f : 3.5f;
    
    self.iconImageView.frame =
    CGRectMake((w - iconSide) / 2.0f,
               iconY,
               iconSide,
               iconSide);
    
    // Текст подписи
    CGFloat labelH = isIPad ? 18.0f : 14.0f;
    CGFloat bottomOffset = isIPad ? 4.0f : 3.0f;
    
    self.titleLabel.frame =
    CGRectMake(1.0f,
               h - labelH - bottomOffset,
               w - 2.0f,
               labelH);
    
    // Бейдж
    if (!self.badgeContainer.hidden &&
        [self.badgeValue length] > 0) {
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        
        CGSize bSize =
        [self.badgeValue sizeWithFont:self.badgeLabel.font];
        
#pragma clang diagnostic pop
        
        CGFloat bH = isIPad ? 19.0f : 16.0f;
        CGFloat bW = MAX(bH, bSize.width + 8.0f);
        CGFloat bX = (w / 2.0f) + (iconSide / 2.0f) - 2.0f;
        CGFloat bY = isIPad ? 3.0f : 2.0f;
        
        self.badgeContainer.frame =
        CGRectMake(bX, bY, bW, bH);
        
        self.badgeContainer.layer.cornerRadius = bH / 2.0f;
        self.badgeLabel.frame = self.badgeContainer.bounds;
    }
}

#pragma mark - Selection & Tinting

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
    self.activeShadowView.hidden = !selected;
    
    if (selected) {
        if (self.selectedImage) {
            self.iconImageView.image = self.selectedImage;
        } else if (self.normalImage) {
            if (!self.cachedTintedSelectedImage) {
                UIColor *activeIconRed = [UIColor colorWithRed:1.0f green:0.15f blue:0.22f alpha:1.0f];
                self.cachedTintedSelectedImage = HRTintedImageWithColor(self.normalImage, activeIconRed);
            }
            self.iconImageView.image = self.cachedTintedSelectedImage;
        }
        self.titleLabel.textColor = [UIColor whiteColor];
    } else {
        self.iconImageView.image = self.normalImage;
        self.titleLabel.textColor = [UIColor colorWithWhite:0.68f alpha:1.0f];
    }
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    
    self.alpha = highlighted ? 0.70f : 1.0f;
    
    self.transform = highlighted
    ? CGAffineTransformMakeScale(0.96f, 0.96f)
    : CGAffineTransformIdentity;
}

#pragma mark - Badge

- (void)setBadgeValue:(NSString *)badgeValue
             animated:(BOOL)animated
{
    _badgeValue = [badgeValue copy];
    
    BOOL show = (_badgeValue && [_badgeValue length] > 0);
    
    self.badgeLabel.text = _badgeValue;
    [self setNeedsLayout];
    
    if (animated && show && self.badgeContainer.hidden) {
        
        self.badgeContainer.hidden = NO;
        
        self.badgeContainer.transform =
        CGAffineTransformMakeScale(0.1f, 0.1f);
        
        [UIView animateWithDuration:0.2f
                         animations:^{
                             self.badgeContainer.transform =
                             CGAffineTransformIdentity;
                         }];
        
    } else {
        
        self.badgeContainer.hidden = !show;
    }
}

@end

#pragma mark - Основной HRCustomTabBar

@interface HRCustomTabBar ()

@property (nonatomic, strong) CAGradientLayer *backgroundGradient;
@property (nonatomic, strong) CALayer *topSeparatorLine;
@property (nonatomic, strong) NSMutableArray *itemViews;

@end

@implementation HRCustomTabBar

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        
        BOOL isIPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
        _contentHeight = isIPad ? 64.0f : 49.0f;
        _selectedIndex = 0;
        _itemViews = [NSMutableArray array];
        
        self.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleTopMargin;
        
        self.backgroundColor =
        [UIColor colorWithRed:0.075f
                        green:0.075f
                         blue:0.080f
                        alpha:1.0f];
        
        _backgroundGradient = [CAGradientLayer layer];
        
        _backgroundGradient.colors = @[
                                       (id)[UIColor colorWithRed:0.135f
                                                           green:0.135f
                                                            blue:0.140f
                                                           alpha:1.0f].CGColor,
                                       
                                       (id)[UIColor colorWithRed:0.085f
                                                           green:0.085f
                                                            blue:0.090f
                                                           alpha:1.0f].CGColor,
                                       
                                       (id)[UIColor colorWithRed:0.045f
                                                           green:0.045f
                                                            blue:0.048f
                                                           alpha:1.0f].CGColor
                                       ];
        
        _backgroundGradient.locations = @[
                                          @(0.0f),
                                          @(0.50f),
                                          @(1.0f)
                                          ];
        
        [self.layer addSublayer:_backgroundGradient];
        
        _topSeparatorLine = [CALayer layer];
        
        _topSeparatorLine.backgroundColor =
        [UIColor colorWithWhite:0.24f alpha:1.0f].CGColor;
        
        [self.layer addSublayer:_topSeparatorLine];
    }
    
    return self;
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    self.backgroundGradient.frame = self.bounds;
    
    self.topSeparatorLine.frame =
    CGRectMake(0.0f, 0.0f, w, 1.0f);
    
    [CATransaction commit];
    
    NSInteger count = [self.itemViews count];
    
    if (count == 0) {
        return;
    }
    
    CGFloat itemW = w / (CGFloat)count;
    
    for (NSInteger i = 0; i < count; i++) {
        
        _HRCustomTabBarItemControl *item = self.itemViews[i];
        
        item.frame = CGRectMake(
                                i * itemW,
                                1.0f,
                                itemW,
                                h - 1.0f
                                );
    }
}

#pragma mark - Items

- (void)setBarItemsWithTitles:(NSArray *)titles
                       images:(NSArray *)images
               selectedImages:(NSArray *)selectedImages
{
    for (_HRCustomTabBarItemControl *ctrl in self.itemViews) {
        [ctrl removeFromSuperview];
    }
    
    [self.itemViews removeAllObjects];
    
    NSInteger count = [titles count];
    
    for (NSInteger i = 0; i < count; i++) {
        
        _HRCustomTabBarItemControl *item =
        [[_HRCustomTabBarItemControl alloc]
         initWithFrame:CGRectZero];
        
        item.tag = i;
        
        item.titleLabel.text =
        (i < [titles count]) ? titles[i] : @"";
        
        item.normalImage =
        (i < [images count]) ? images[i] : nil;
        
        item.selectedImage =
        (i < [selectedImages count]) ? selectedImages[i] : nil;
        
        [item addTarget:self
                 action:@selector(itemControlTapped:)
       forControlEvents:UIControlEventTouchUpInside];
        
        [self addSubview:item];
        [self.itemViews addObject:item];
    }
    
    if (self.selectedIndex >= count) {
        _selectedIndex = (count > 0) ? 0 : -1;
    }
    
    [self updateSelectionStateAnimated:NO];
    
    [self setNeedsLayout];
}

#pragma mark - Actions

- (void)itemControlTapped:(_HRCustomTabBarItemControl *)sender
{
    NSInteger targetIndex = sender.tag;
    
    if ([self.delegate respondsToSelector:
         @selector(customTabBar:shouldSelectItemAtIndex:)]) {
        
        if (![self.delegate customTabBar:self
                 shouldSelectItemAtIndex:targetIndex]) {
            return;
        }
    }
    
    [self selectItemAtIndex:targetIndex animated:YES];
    
    if ([self.delegate respondsToSelector:
         @selector(customTabBar:didSelectItemAtIndex:)]) {
        
        [self.delegate customTabBar:self
               didSelectItemAtIndex:targetIndex];
    }
}

- (void)setSelectedIndex:(NSInteger)selectedIndex
{
    [self selectItemAtIndex:selectedIndex animated:NO];
}

- (void)selectItemAtIndex:(NSInteger)index
                 animated:(BOOL)animated
{
    if (index < 0 || index >= [self.itemViews count]) {
        return;
    }
    
    _selectedIndex = index;
    
    [self updateSelectionStateAnimated:animated];
}

- (void)updateSelectionStateAnimated:(BOOL)animated
{
    for (NSInteger i = 0; i < [self.itemViews count]; i++) {
        
        _HRCustomTabBarItemControl *item = self.itemViews[i];
        
        [item setSelected:(i == _selectedIndex)];
    }
}

#pragma mark - Badge API

- (void)setBadgeValue:(NSString *)badgeValue
             forIndex:(NSInteger)index
             animated:(BOOL)animated
{
    if (index >= 0 && index < [self.itemViews count]) {
        
        _HRCustomTabBarItemControl *item = self.itemViews[index];
        
        [item setBadgeValue:badgeValue animated:animated];
    }
}

- (NSString *)badgeValueForIndex:(NSInteger)index
{
    if (index >= 0 && index < [self.itemViews count]) {
        
        _HRCustomTabBarItemControl *item = self.itemViews[index];
        
        return item.badgeValue;
    }
    
    return nil;
}

#pragma mark - Visibility

- (void)setBarHidden:(BOOL)hidden animated:(BOOL)animated
{
    CGFloat offset = hidden ? self.bounds.size.height : 0.0f;
    
    void (^animBlock)(void) = ^{
        self.transform =
        CGAffineTransformMakeTranslation(0.0f, offset);
    };
    
    if (animated) {
        
        [UIView animateWithDuration:0.25f
                              delay:0.0f
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:animBlock
                         completion:nil];
        
    } else {
        
        animBlock();
    }
}

@end
