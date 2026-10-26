#import "HRWelcomeViewController.h"
#import <QuartzCore/QuartzCore.h>

static NSString * const HRWelcomeDidReadKey = @"HR_WELCOME_DID_READ_V1";

@interface HRWelcomeViewController ()
@property (nonatomic, retain) UILabel *brandMark;
@property (nonatomic, retain) UILabel *titleLabel;
@property (nonatomic, retain) UILabel *subtitleLabel;
@property (nonatomic, retain) UIView *accentLine;
@property (nonatomic, retain) UITextView *welcomeTextView;
@property (nonatomic, retain) UIButton *continueButton;
@property (nonatomic, retain) UILabel *hintLabel;
@end

@implementation HRWelcomeViewController

- (void)loadView
{
    UIView *rootView = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    rootView.backgroundColor = [UIColor colorWithRed:0.035 green:0.035 blue:0.04 alpha:1.0];
    self.view = rootView;
    
    UILabel *brand = [[UILabel alloc] initWithFrame:CGRectZero];
    brand.backgroundColor = [UIColor colorWithRed:0.78 green:0.08 blue:0.12 alpha:1.0];
    brand.text = @"▶";
    brand.textColor = [UIColor whiteColor];
    brand.font = [UIFont boldSystemFontOfSize:19.0];
    brand.textAlignment = NSTextAlignmentCenter;
    brand.layer.cornerRadius = 9.0;
    brand.layer.borderWidth = 1.0;
    brand.layer.borderColor = [[UIColor colorWithRed:1.0 green:0.30 blue:0.32 alpha:1.0] CGColor];
    brand.clipsToBounds = YES;
    [self.view addSubview:brand];
    self.brandMark = brand;
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectZero];
    title.backgroundColor = [UIColor clearColor];
    title.text = @"HDREZKA";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:22.0];
    [self.view addSubview:title];
    self.titleLabel = title;
    
    UILabel *subtitle = [[UILabel alloc] initWithFrame:CGRectZero];
    subtitle.backgroundColor = [UIColor clearColor];
    subtitle.text = @"ВОЗМОЖНОСТИ И НАСТРОЙКА";
    subtitle.textColor = [UIColor colorWithRed:0.96 green:0.24 blue:0.27 alpha:1.0];
    subtitle.font = [UIFont boldSystemFontOfSize:10.0];
    subtitle.adjustsFontSizeToFitWidth = YES;
    [self.view addSubview:subtitle];
    self.subtitleLabel = subtitle;
    
    UIView *line = [[UIView alloc] initWithFrame:CGRectZero];
    line.backgroundColor = [UIColor colorWithRed:0.78 green:0.08 blue:0.12 alpha:1.0];
    [self.view addSubview:line];
    self.accentLine = line;
    
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectZero];
    textView.backgroundColor = [UIColor colorWithRed:0.085 green:0.085 blue:0.095 alpha:1.0];
    textView.textColor = [UIColor colorWithWhite:0.90 alpha:1.0];
    textView.font = [UIFont systemFontOfSize:14.0];
    textView.editable = NO;
    textView.delegate = self;
    textView.scrollEnabled = YES;
    textView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    textView.dataDetectorTypes = UIDataDetectorTypeLink;
    textView.layer.cornerRadius = 8.0;
    textView.layer.borderWidth = 1.0;
    textView.layer.borderColor = [[UIColor colorWithWhite:0.20 alpha:1.0] CGColor];
    textView.clipsToBounds = YES;
    textView.contentInset = UIEdgeInsetsMake(12.0, 9.0, 12.0, 9.0);
    [self.view addSubview:textView];
    self.welcomeTextView = textView;
    
    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectZero];
    hint.backgroundColor = [UIColor clearColor];
    hint.text = @"ПРОКРУТИТЕ ТЕКСТ ДО КОНЦА";
    hint.textColor = [UIColor colorWithWhite:0.60 alpha:1.0];
    hint.font = [UIFont boldSystemFontOfSize:10.0];
    hint.textAlignment = NSTextAlignmentCenter;
    hint.numberOfLines = 2;
    [self.view addSubview:hint];
    self.hintLabel = hint;
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];
    button.layer.cornerRadius = 7.0;
    button.layer.borderWidth = 1.0;
    button.layer.borderColor = [[UIColor colorWithWhite:0.28 alpha:1.0] CGColor];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
    [button setTitle:@"ПРОЧИТАЛ, ПРОДОЛЖИТЬ" forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithWhite:0.52 alpha:1.0] forState:UIControlStateNormal];
    [button addTarget:self action:@selector(continuePressed:) forControlEvents:UIControlEventTouchUpInside];
    button.enabled = NO;
    [self.view addSubview:button];
    self.continueButton = button;
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"WelcomeText" ofType:@"txt"];
    NSString *text = nil;
    if (path != nil) {
        text = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    }
    if ([text length] == 0) {
        text = @"Не удалось загрузить WelcomeText.txt.\n\nДобавьте файл в ресурсы приложения через Xcode и убедитесь, что он включён в Target Membership.";
    }
    textView.attributedText = [self styledWelcomeText:text];
}

- (NSAttributedString *)styledWelcomeText:(NSString *)text
{
    NSMutableAttributedString *result = [[NSMutableAttributedString alloc] initWithString:text];
    NSRange all = NSMakeRange(0, [result length]);
    [result addAttribute:NSFontAttributeName value:[UIFont systemFontOfSize:14.0] range:all];
    [result addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithWhite:0.90 alpha:1.0] range:all];
    
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineSpacing = 3.0;
    paragraph.paragraphSpacing = 5.0;
    [result addAttribute:NSParagraphStyleAttributeName value:paragraph range:all];
    
    NSUInteger cursor = 0;
    while (cursor < [result length]) {
        NSRange lineRange = [[result string] lineRangeForRange:NSMakeRange(cursor, 0)];
        NSString *line = [[[result string] substringWithRange:lineRange] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        BOOL section = [line hasPrefix:@"1. "] || [line hasPrefix:@"2. "];
        BOOL heading = ([line isEqualToString:@"ПРОСМОТР И ЗАГРУЗКИ"] ||
                        [line isEqualToString:@"ИНДИКАЦИЯ ЗАГРУЗОК"] ||
                        [line isEqualToString:@"УПРАВЛЕНИЕ ВОСПРОИЗВЕДЕНИЕМ"] ||
                        [line isEqualToString:@"НАСТРОЙКИ И ВОССТАНОВЛЕНИЕ"] ||
                        [line isEqualToString:@"КЛАССИЧЕСКАЯ АВТОРИЗАЦИЯ"] ||
                        [line isEqualToString:@"ПУБЛИЧНАЯ АВТОРИЗАЦИЯ"] ||
                        [line isEqualToString:@"ОБЯЗАТЕЛЬНАЯ НАСТРОЙКА АНТИБОТ-ЗАЩИТЫ"] ||
                        [line isEqualToString:@"ПЕРЕД ИСПОЛЬЗОВАНИЕМ ПУБЛИЧНОЙ АВТОРИЗАЦИИ"] ||
                        [line hasPrefix:@"ВНИМАНИЕ!"]);
        if (section || heading) {
            [result addAttribute:NSFontAttributeName value:[UIFont boldSystemFontOfSize:(section ? 16.0 : 12.0)] range:lineRange];
            [result addAttribute:NSForegroundColorAttributeName value:[UIColor colorWithRed:0.96 green:0.24 blue:0.27 alpha:1.0] range:lineRange];
        }
        cursor = NSMaxRange(lineRange);
    }
    return result;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"О приложении";
    self.navigationItem.hidesBackButton = YES;
    self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    CGFloat margin = 13.0;
    CGFloat headerHeight = 76.0;
    CGFloat footerHeight = 78.0;
    CGFloat markSize = 42.0;
    
    self.brandMark.frame = CGRectMake(margin, 12.0, markSize, markSize);
    self.titleLabel.frame = CGRectMake(margin + markSize + 10.0, 13.0, width - margin * 2.0 - markSize - 10.0, 27.0);
    self.subtitleLabel.frame = CGRectMake(margin + markSize + 11.0, 40.0, width - margin * 2.0 - markSize - 11.0, 17.0);
    self.accentLine.frame = CGRectMake(margin, headerHeight - 1.0, width - margin * 2.0, 2.0);
    
    CGFloat textY = headerHeight + 10.0;
    CGFloat textHeight = height - headerHeight - footerHeight - 16.0;
    if (textHeight < 150.0) textHeight = 150.0;
    self.welcomeTextView.frame = CGRectMake(margin, textY, width - margin * 2.0, textHeight);
    self.hintLabel.frame = CGRectMake(margin, height - 73.0, width - margin * 2.0, 20.0);
    self.continueButton.frame = CGRectMake(margin, height - 47.0, width - margin * 2.0, 38.0);
    [self updateContinueAvailability];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self updateContinueAvailability];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView == self.welcomeTextView) [self updateContinueAvailability];
}

- (void)updateContinueAvailability
{
    if (self.continueButton == nil || self.welcomeTextView == nil) return;
    CGFloat contentHeight = self.welcomeTextView.contentSize.height;
    CGFloat visibleHeight = self.welcomeTextView.bounds.size.height;
    CGFloat visibleBottom = self.welcomeTextView.contentOffset.y + visibleHeight;
    BOOL reachedEnd = (visibleHeight > 0.0 && (contentHeight <= visibleHeight + 1.0 || visibleBottom >= contentHeight - 8.0));
    self.continueButton.enabled = reachedEnd;
    
    if (reachedEnd) {
        self.continueButton.backgroundColor = [UIColor colorWithRed:0.78 green:0.08 blue:0.12 alpha:1.0];
        self.continueButton.layer.borderColor = [[UIColor colorWithRed:1.0 green:0.30 blue:0.32 alpha:1.0] CGColor];
        [self.continueButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        self.hintLabel.text = @"ТЕКСТ ПРОЧИТАН — МОЖНО ПРОДОЛЖИТЬ";
        self.hintLabel.textColor = [UIColor colorWithRed:0.96 green:0.24 blue:0.27 alpha:1.0];
    } else {
        self.continueButton.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1.0];
        self.continueButton.layer.borderColor = [[UIColor colorWithWhite:0.28 alpha:1.0] CGColor];
        [self.continueButton setTitleColor:[UIColor colorWithWhite:0.52 alpha:1.0] forState:UIControlStateNormal];
        self.hintLabel.text = @"ПРОКРУТИТЕ ТЕКСТ ДО КОНЦА";
        self.hintLabel.textColor = [UIColor colorWithWhite:0.60 alpha:1.0];
    }
}

- (void)continuePressed:(id)sender
{
    [self updateContinueAvailability];
    if (!self.continueButton.enabled) return;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:YES forKey:HRWelcomeDidReadKey];
    [defaults synchronize];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)orientation
{
    return orientation == UIInterfaceOrientationPortrait;
}


@end
