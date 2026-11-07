#import "HRTheme.h"
#import <QuartzCore/QuartzCore.h>

@implementation HRTheme

+ (UIBarButtonItem *)createGlossyBarButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0f];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [btn setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:0.6] forState:UIControlStateNormal];
    btn.titleLabel.shadowOffset = CGSizeMake(0, -1);
    
    CGSize textSize = [title sizeWithFont:btn.titleLabel.font];
    CGFloat btnW = MAX(textSize.width + 20.0f, 54.0f);
    btn.frame = CGRectMake(0, 0, btnW, 30.0f);
    
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame = btn.bounds;
    grad.colors = @[
                    (id)[UIColor colorWithRed:0.75 green:0.12 blue:0.12 alpha:1.0].CGColor,
                    (id)[UIColor colorWithRed:0.48 green:0.05 blue:0.05 alpha:1.0].CGColor
                    ];
    grad.cornerRadius = 4.0f;
    grad.borderWidth = 0.0f;
    grad.borderColor = [UIColor clearColor].CGColor;
    [btn.layer insertSublayer:grad atIndex:0];
    
    btn.layer.cornerRadius = 4.0f;
    btn.layer.masksToBounds = YES;
    btn.layer.borderWidth = 0.0f;
    btn.layer.borderColor = [UIColor clearColor].CGColor;
    
    [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return [[UIBarButtonItem alloc] initWithCustomView:btn];
}

+ (UIBarButtonItem *)createGlossyBackButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0f];
    [btn setTitle:title forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [btn setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:0.6] forState:UIControlStateNormal];
    btn.titleLabel.shadowOffset = CGSizeMake(0, -1);
    
    CGSize textSize = [title sizeWithFont:btn.titleLabel.font];
    CGFloat btnW = MAX(textSize.width + 18.0f, 62.0f);
    btn.frame = CGRectMake(0, 0, btnW, 30.0f);
    
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame = btn.bounds;
    grad.colors = @[
                    (id)[UIColor colorWithRed:0.26 green:0.26 blue:0.26 alpha:1.0].CGColor,
                    (id)[UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0].CGColor
                    ];
    grad.cornerRadius = 4.0f;
    grad.borderWidth = 0.0f;
    grad.borderColor = [UIColor clearColor].CGColor;
    [btn.layer insertSublayer:grad atIndex:0];
    
    btn.layer.cornerRadius = 4.0f;
    btn.layer.masksToBounds = YES;
    btn.layer.borderWidth = 0.0f;
    btn.layer.borderColor = [UIColor clearColor].CGColor;
    
    [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return [[UIBarButtonItem alloc] initWithCustomView:btn];
}

+ (UIBarButtonItem *)createGlossyMenuButtonWithTarget:(id)target action:(SEL)action
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, 34, 30);
    [btn setTitle:@"☰" forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [btn setTitleShadowColor:[UIColor colorWithWhite:0.0 alpha:0.7] forState:UIControlStateNormal];
    btn.titleLabel.shadowOffset = CGSizeMake(0, -1);
    
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame = btn.bounds;
    grad.colors = @[
                    (id)[UIColor colorWithRed:0.25 green:0.25 blue:0.25 alpha:1.0].CGColor,
                    (id)[UIColor colorWithRed:0.12 green:0.12 blue:0.12 alpha:1.0].CGColor
                    ];
    grad.cornerRadius = 4.0f;
    grad.borderWidth = 0.0f;
    grad.borderColor = [UIColor clearColor].CGColor;
    [btn.layer insertSublayer:grad atIndex:0];
    
    btn.layer.cornerRadius = 4.0f;
    btn.layer.masksToBounds = YES;
    btn.layer.borderWidth = 0.0f;
    btn.layer.borderColor = [UIColor clearColor].CGColor;
    
    [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return [[UIBarButtonItem alloc] initWithCustomView:btn];
}

+ (UIBarButtonItem *)createRefreshIconBarButtonWithTarget:(id)target action:(SEL)action
{
    UIButton *refreshButton = [UIButton buttonWithType:UIButtonTypeCustom];
    refreshButton.frame = CGRectMake(0.0f, 0.0f, 34.0f, 30.0f);
    refreshButton.backgroundColor = [UIColor colorWithRed:0.10f green:0.10f blue:0.10f alpha:1.0f];
    refreshButton.layer.cornerRadius = 5.0f;
    refreshButton.layer.borderWidth = 0.0f;
    refreshButton.layer.borderColor = [UIColor clearColor].CGColor;
    refreshButton.titleLabel.font = [UIFont boldSystemFontOfSize:23.0f];
    [refreshButton setTitle:@"↻" forState:UIControlStateNormal];
    [refreshButton setTitleColor:[UIColor colorWithRed:0.95f green:0.18f blue:0.22f alpha:1.0f] forState:UIControlStateNormal];
    [refreshButton addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return [[UIBarButtonItem alloc] initWithCustomView:refreshButton];
}

+ (UIImage *)createDownloadBarButtonIconWithColor:(UIColor *)iconColor
{
    CGSize canvasSize = CGSizeMake(30.0f, 26.0f);
    UIGraphicsBeginImageContextWithOptions(canvasSize, NO, 0.0f);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (!ctx) return nil;
    
    UIColor *fillColor = iconColor ?: [UIColor whiteColor];
    [fillColor setFill];
    [fillColor setStroke];
    
    // Тень под иконкой для объема
    CGContextSetShadowWithColor(ctx, CGSizeMake(0.0f, -1.0f), 1.0f, [UIColor colorWithWhite:0.0f alpha:0.7f].CGColor);
    
    // 1. Стрелка загрузки
    UIBezierPath *arrowPath = [UIBezierPath bezierPath];
    [arrowPath moveToPoint:CGPointMake(15.0f, 17.0f)];
    [arrowPath addLineToPoint:CGPointMake(8.0f, 10.0f)];
    [arrowPath addLineToPoint:CGPointMake(12.0f, 10.0f)];
    [arrowPath addLineToPoint:CGPointMake(12.0f, 2.0f)];
    [arrowPath addLineToPoint:CGPointMake(18.0f, 2.0f)];
    [arrowPath addLineToPoint:CGPointMake(18.0f, 10.0f)];
    [arrowPath addLineToPoint:CGPointMake(22.0f, 10.0f)];
    [arrowPath closePath];
    arrowPath.lineJoinStyle = kCGLineJoinRound;
    arrowPath.lineCapStyle = kCGLineCapRound;
    [arrowPath fill];
    
    // 2. Лоток под стрелкой
    UIBezierPath *trayPath = [UIBezierPath bezierPath];
    [trayPath moveToPoint:CGPointMake(3.0f, 13.0f)];
    [trayPath addLineToPoint:CGPointMake(3.0f, 21.0f)];
    [trayPath addLineToPoint:CGPointMake(27.0f, 21.0f)];
    [trayPath addLineToPoint:CGPointMake(27.0f, 13.0f)];
    trayPath.lineWidth = 2.5f;
    trayPath.lineCapStyle = kCGLineCapRound;
    trayPath.lineJoinStyle = kCGLineJoinRound;
    [trayPath stroke];
    
    UIImage *icon = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return icon;
}

+ (UIButton *)createDownloadNavButtonWithTarget:(id)target action:(SEL)action
{
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0.0f, 0.0f, 48.0f, 32.0f);
    btn.layer.cornerRadius = 8.0f;
    btn.layer.masksToBounds = YES;
    btn.layer.borderWidth = 0.0f;
    btn.layer.borderColor = [UIColor clearColor].CGColor;
    
    btn.imageView.contentMode = UIViewContentModeCenter;
    btn.adjustsImageWhenHighlighted = YES;
    
    // 1. Скевоморфный объемный градиент кнопки
    CAGradientLayer *gradLayer = [CAGradientLayer layer];
    gradLayer.frame = btn.bounds;
    gradLayer.cornerRadius = 8.0f;
    gradLayer.masksToBounds = YES;
    gradLayer.colors = @[
                         (id)[UIColor colorWithRed:0.24f green:0.24f blue:0.24f alpha:1.0f].CGColor,
                         (id)[UIColor colorWithRed:0.10f green:0.10f blue:0.10f alpha:1.0f].CGColor
                         ];
    [btn.layer insertSublayer:gradLayer atIndex:0];
    
    // 2. Стеклянный верхний глянец (Gloss)
    CAGradientLayer *glossLayer = [CAGradientLayer layer];
    glossLayer.frame = CGRectMake(0.0f, 0.0f, 48.0f, 16.0f);
    glossLayer.cornerRadius = 8.0f;
    glossLayer.masksToBounds = YES;
    glossLayer.colors = @[
                          (id)[UIColor colorWithWhite:1.0f alpha:0.25f].CGColor,
                          (id)[UIColor colorWithWhite:1.0f alpha:0.02f].CGColor
                          ];
    [btn.layer insertSublayer:glossLayer atIndex:1];
    
    [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

+ (UIView *)createLogoTitleView
{
    UIView *titleContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 110, 30)];
    titleContainer.backgroundColor = [UIColor clearColor];
    
    UILabel *hdBadge = [[UILabel alloc] initWithFrame:CGRectMake(4, 5, 28, 20)];
    hdBadge.backgroundColor = [UIColor colorWithRed:0.75 green:0.12 blue:0.12 alpha:1.0];
    hdBadge.textColor = [UIColor whiteColor];
    hdBadge.font = [UIFont boldSystemFontOfSize:13.0f];
    hdBadge.textAlignment = NSTextAlignmentCenter;
    hdBadge.text = @"HD";
    hdBadge.layer.cornerRadius = 3.0f;
    hdBadge.layer.masksToBounds = YES;
    [titleContainer addSubview:hdBadge];
    
    UILabel *rezkaLabel = [[UILabel alloc] initWithFrame:CGRectMake(36, 4, 70, 22)];
    rezkaLabel.textColor = [UIColor whiteColor];
    rezkaLabel.font = [UIFont boldSystemFontOfSize:17.0f];
    rezkaLabel.backgroundColor = [UIColor clearColor];
    rezkaLabel.text = @"Rezka";
    [titleContainer addSubview:rezkaLabel];
    
    return titleContainer;
}

+ (UIImage *)tabBarIconHome
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    
    CGContextMoveToPoint(ctx, 15, 4);
    CGContextAddLineToPoint(ctx, 3, 14);
    CGContextAddLineToPoint(ctx, 6, 14);
    CGContextAddLineToPoint(ctx, 6, 26);
    CGContextAddLineToPoint(ctx, 24, 26);
    CGContextAddLineToPoint(ctx, 24, 14);
    CGContextAddLineToPoint(ctx, 27, 14);
    CGContextClosePath(ctx);
    CGContextFillPath(ctx);
    
    CGContextSetFillColorWithColor(ctx, [UIColor clearColor].CGColor);
    CGContextSetBlendMode(ctx, kCGBlendModeClear);
    CGContextFillRect(ctx, CGRectMake(12, 17, 6, 9));
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)tabBarIconFavorites
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetFillColorWithColor(ctx, [UIColor whiteColor].CGColor);
    
    CGFloat cx = 15, cy = 15, rOut = 11, rIn = 5.0;
    CGContextMoveToPoint(ctx, cx, cy - rOut);
    for (int i = 1; i < 10; i++) {
        CGFloat r = (i % 2 == 1) ? rIn : rOut;
        CGFloat angle = -M_PI_2 + i * M_PI / 5.0;
        CGContextAddLineToPoint(ctx, cx + r * cos(angle), cy + r * sin(angle));
    }
    CGContextClosePath(ctx);
    CGContextFillPath(ctx);
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)tabBarIconHistory
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(ctx, 2.5);
    
    CGContextStrokeEllipseInRect(ctx, CGRectMake(4, 4, 22, 22));
    CGContextMoveToPoint(ctx, 15, 8);
    CGContextAddLineToPoint(ctx, 15, 15);
    CGContextAddLineToPoint(ctx, 19, 15);
    CGContextStrokePath(ctx);
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)tabBarIconSettings
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(ctx, 2.0);
    
    CGContextStrokeEllipseInRect(ctx, CGRectMake(8, 8, 14, 14));
    
    for (int i = 0; i < 8; i++) {
        CGFloat angle = i * M_PI / 4.0;
        CGFloat x1 = 15 + 8 * cos(angle);
        CGFloat y1 = 15 + 8 * sin(angle);
        CGFloat x2 = 15 + 12 * cos(angle);
        CGFloat y2 = 15 + 12 * sin(angle);
        CGContextMoveToPoint(ctx, x1, y1);
        CGContextAddLineToPoint(ctx, x2, y2);
    }
    CGContextStrokePath(ctx);
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end
