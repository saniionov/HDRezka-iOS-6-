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
    grad.borderColor = [UIColor colorWithRed:0.85 green:0.25 blue:0.25 alpha:0.8].CGColor;
    grad.borderWidth = 1.0f;
    [btn.layer insertSublayer:grad atIndex:0];
    btn.layer.cornerRadius = 4.0f;
    btn.layer.masksToBounds = YES;
    
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
    grad.borderColor = [UIColor colorWithWhite:0.35 alpha:0.8].CGColor;
    grad.borderWidth = 1.0f;
    [btn.layer insertSublayer:grad atIndex:0];
    btn.layer.cornerRadius = 4.0f;
    btn.layer.masksToBounds = YES;
    
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
    grad.borderColor = [UIColor colorWithRed:0.55 green:0.15 blue:0.15 alpha:0.9].CGColor; // Тонкий красный кант
    grad.borderWidth = 1.0f;
    [btn.layer insertSublayer:grad atIndex:0];
    btn.layer.cornerRadius = 4.0f;
    btn.layer.masksToBounds = YES;
    
    [btn addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return [[UIBarButtonItem alloc] initWithCustomView:btn];
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
        CGFloat r = (i % 2 == 0) ? rOut : rIn;
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
    
    UIBezierPath *outerCircle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(5, 5, 20, 20)];
    UIBezierPath *innerCircle = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(7.5, 7.5, 15, 15)];
    [outerCircle appendPath:innerCircle];
    outerCircle.usesEvenOddFillRule = YES;
    
    [[UIColor whiteColor] setFill];
    [outerCircle fill];
    
    UIBezierPath *arrows = [UIBezierPath bezierPath];
    [arrows moveToPoint:CGPointMake(14, 9)];
    [arrows addLineToPoint:CGPointMake(16, 9)];
    [arrows addLineToPoint:CGPointMake(16, 14)];
    [arrows addLineToPoint:CGPointMake(20, 14)];
    [arrows addLineToPoint:CGPointMake(20, 16)];
    [arrows addLineToPoint:CGPointMake(14, 16)];
    [arrows closePath];
    [arrows fill];
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

+ (UIImage *)tabBarIconSettings
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 0.0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
    CGContextSetLineWidth(ctx, 2.5);
    
    CGContextStrokeEllipseInRect(ctx, CGRectMake(7, 7, 16, 16));
    
    for (int i = 0; i < 6; i++) {
        CGFloat angle = i * M_PI / 3.0;
        CGContextMoveToPoint(ctx, 15 + 8 * cos(angle), 15 + 8 * sin(angle));
        CGContextAddLineToPoint(ctx, 15 + 13 * cos(angle), 15 + 13 * sin(angle));
    }
    CGContextStrokePath(ctx);
    
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@end