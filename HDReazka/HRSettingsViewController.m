#import "HRSettingsViewController.h"
#import "HRHTTPClient.h"
#import "HRPublicAuthViewController.h"
#import "HRWelcomeViewController.h"
#import <QuartzCore/QuartzCore.h>

static NSString * const kHRPreferredQualityKey = @"HR_DEFAULT_QUALITY";

typedef NS_ENUM(NSInteger, HRSettingsSection) {
    HRSettingsSectionConnectionMode = 0, // Режим подключения
    HRSettingsSectionAuthDetails = 1,    // Домен, логин/пароль или кнопка
    HRSettingsSectionDefaultQuality = 2, // Качество видео по умолчанию
    HRSettingsSectionPlayback = 3,       // Воспроизведение и загрузки
    HRSettingsSectionAbout = 4,          // Справка / О приложении
    HRSettingsSectionReset = 5,          // Сброс данных
    HRSettingsSectionCount = 6
};

typedef NS_ENUM(NSInteger, HRGroupCellPosition) {
    HRGroupCellPositionSingle,
    HRGroupCellPositionTop,
    HRGroupCellPositionMiddle,
    HRGroupCellPositionBottom
};

#pragma mark - Кастомный фон для сгруппированных строк

@interface HRGroupedCellBackgroundView : UIView
@property (nonatomic, assign) HRGroupCellPosition position;
@property (nonatomic, assign) BOOL isSelectedBackground;
@end

@implementation HRGroupedCellBackgroundView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    }
    return self;
}

- (void)setPosition:(HRGroupCellPosition)position
{
    if (_position != position) {
        _position = position;
        [self setNeedsDisplay];
    }
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextClearRect(context, rect);
    
    CGRect bounds = self.bounds;
    if (bounds.size.width <= 0 || bounds.size.height <= 0) return;
    
    CGFloat radius = 9.0f;
    UIRectCorner corners = 0;
    
    switch (self.position) {
        case HRGroupCellPositionSingle:
            corners = UIRectCornerAllCorners;
            break;
        case HRGroupCellPositionTop:
            corners = UIRectCornerTopLeft | UIRectCornerTopRight;
            break;
        case HRGroupCellPositionBottom:
            corners = UIRectCornerBottomLeft | UIRectCornerBottomRight;
            break;
        case HRGroupCellPositionMiddle:
        default:
            corners = 0;
            break;
    }
    
    UIBezierPath *path = nil;
    if (corners != 0) {
        path = [UIBezierPath bezierPathWithRoundedRect:bounds byRoundingCorners:corners cornerRadii:CGSizeMake(radius, radius)];
    } else {
        path = [UIBezierPath bezierPathWithRect:bounds];
    }
    
    UIColor *fillColor = self.isSelectedBackground ?
    [UIColor colorWithRed:0.20f green:0.20f blue:0.20f alpha:1.0f] :
    [UIColor colorWithRed:0.14f green:0.14f blue:0.14f alpha:1.0f];
    
    [fillColor setFill];
    [path fill];
    
    if (self.position == HRGroupCellPositionTop || self.position == HRGroupCellPositionMiddle) {
        UIBezierPath *line = [UIBezierPath bezierPath];
        CGFloat lineY = bounds.size.height - 1.0f;
        [line moveToPoint:CGPointMake(16.0f, lineY)];
        [line addLineToPoint:CGPointMake(bounds.size.width, lineY)];
        line.lineWidth = 1.0f;
        [[UIColor colorWithWhite:0.40f alpha:1.0f] setStroke];
        [line stroke];
    }
}

@end

#pragma mark - Фирменная красная кнопка-плашка

@interface HRSettingsMenuButtonCell : UITableViewCell
@property (nonatomic, strong) UIView *customBgView;
@property (nonatomic, strong) UIView *customSelView;
@property (nonatomic, strong) CAGradientLayer *normalGlossLayer;
@property (nonatomic, strong) CAGradientLayer *selectedGlossLayer;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, assign) CGFloat topInset;
@property (nonatomic, assign) CGFloat bottomInset;
@end

@implementation HRSettingsMenuButtonCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.accessoryType = UITableViewCellAccessoryNone;
        
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.backgroundView = nil;
        self.selectedBackgroundView = nil;
        
        _topInset = 4.0f;
        _bottomInset = 4.0f;
        
        CGFloat screenScale = [UIScreen mainScreen].scale;
        
        _customBgView = [[UIView alloc] initWithFrame:self.bounds];
        _customBgView.layer.cornerRadius = 9.0f;
        _customBgView.layer.masksToBounds = YES;
        _customBgView.layer.borderWidth = 0.0f;
        _customBgView.backgroundColor = [UIColor clearColor];
        
        _normalGlossLayer = [CAGradientLayer layer];
        _normalGlossLayer.contentsScale = screenScale;
        _normalGlossLayer.locations = @[@(0.0f), @(1.0f)];
        _normalGlossLayer.colors = @[
                                     (id)[UIColor colorWithRed:0.55f green:0.08f blue:0.10f alpha:1.0f].CGColor,
                                     (id)[UIColor colorWithRed:0.38f green:0.04f blue:0.06f alpha:1.0f].CGColor
                                     ];
        [_customBgView.layer insertSublayer:_normalGlossLayer atIndex:0];
        
        _customSelView = [[UIView alloc] initWithFrame:self.bounds];
        _customSelView.layer.cornerRadius = 9.0f;
        _customSelView.layer.masksToBounds = YES;
        _customSelView.layer.borderWidth = 0.0f;
        _customSelView.backgroundColor = [UIColor clearColor];
        
        _selectedGlossLayer = [CAGradientLayer layer];
        _selectedGlossLayer.contentsScale = screenScale;
        _selectedGlossLayer.locations = @[@(0.0f), @(1.0f)];
        _selectedGlossLayer.colors = @[
                                       (id)[UIColor colorWithRed:0.28f green:0.03f blue:0.04f alpha:1.0f].CGColor,
                                       (id)[UIColor colorWithRed:0.22f green:0.02f blue:0.03f alpha:1.0f].CGColor
                                       ];
        [_customSelView.layer insertSublayer:_selectedGlossLayer atIndex:0];
        
        [self addSubview:_customBgView];
        [self addSubview:_customSelView];
        _customSelView.hidden = YES;
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [UIFont boldSystemFontOfSize:15.0f];
        _titleLabel.textAlignment = NSTextAlignmentCenter;
        _titleLabel.textColor = [UIColor whiteColor];
        _titleLabel.shadowColor = [UIColor clearColor];
        _titleLabel.shadowOffset = CGSizeZero;
        [_customBgView addSubview:_titleLabel];
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated
{
    [super setHighlighted:highlighted animated:animated];
    self.customSelView.hidden = !highlighted;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];
    self.customSelView.hidden = !selected;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    CGFloat totalW = self.bounds.size.width;
    
    CGFloat btnW = isPad ? 300.0f : floorf(totalW * 0.68f);
    if (btnW > totalW - 28.0f) {
        btnW = totalW - 28.0f;
    }
    CGFloat btnX = floorf((totalW - btnW) / 2.0f);
    
    CGFloat btnY = self.topInset;
    CGFloat btnH = self.bounds.size.height - self.topInset - self.bottomInset;
    if (btnH < 36.0f) {
        btnH = 36.0f;
    }
    
    CGRect btnFrame = CGRectMake(btnX, btnY, btnW, btnH);
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.customBgView.frame = btnFrame;
    self.customSelView.frame = btnFrame;
    self.normalGlossLayer.frame = self.customBgView.bounds;
    self.selectedGlossLayer.frame = self.customSelView.bounds;
    [CATransaction commit];
    
    self.titleLabel.frame = self.customBgView.bounds;
}

@end

#pragma mark - Кастомная плашка для пунктов с переключателями

@interface HRSettingsSwitchCell : UITableViewCell
@property (nonatomic, strong) UIView *customBgView;
@property (nonatomic, strong) CAGradientLayer *glossLayer;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UISwitch *switchControl;
@end

@implementation HRSettingsSwitchCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.accessoryType = UITableViewCellAccessoryNone;
        
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.backgroundView = nil;
        self.selectedBackgroundView = nil;
        
        CGFloat screenScale = [UIScreen mainScreen].scale;
        
        _customBgView = [[UIView alloc] initWithFrame:self.bounds];
        _customBgView.layer.cornerRadius = 9.0f;
        _customBgView.layer.masksToBounds = YES;
        _customBgView.layer.borderWidth = 0.0f;
        _customBgView.backgroundColor = [UIColor clearColor];
        
        _glossLayer = [CAGradientLayer layer];
        _glossLayer.contentsScale = screenScale;
        _glossLayer.locations = @[@(0.0f), @(1.0f)];
        _glossLayer.colors = @[
                               (id)[UIColor colorWithRed:0.180f green:0.180f blue:0.190f alpha:1.0f].CGColor,
                               (id)[UIColor colorWithRed:0.150f green:0.150f blue:0.161f alpha:1.0f].CGColor
                               ];
        [_customBgView.layer insertSublayer:_glossLayer atIndex:0];
        
        [self addSubview:_customBgView];
        
        _titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.font = [UIFont boldSystemFontOfSize:16.0f];
        _titleLabel.textColor = [UIColor colorWithWhite:0.95f alpha:1.0f];
        [_customBgView addSubview:_titleLabel];
    }
    return self;
}

- (void)attachSwitch:(UISwitch *)sw title:(NSString *)title
{
    self.titleLabel.text = title;
    
    if (self.switchControl && self.switchControl != sw) {
        [self.switchControl removeFromSuperview];
    }
    self.switchControl = sw;
    
    if (sw && sw.superview != self.customBgView) {
        [sw removeFromSuperview];
        [self.customBgView addSubview:sw];
    }
    [self setNeedsLayout];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    CGFloat totalW = self.bounds.size.width;
    
    CGFloat sideMargin = isPad ? 30.0f : 10.0f;
    CGFloat verticalMargin = 3.0f;
    
    CGRect frame = CGRectMake(sideMargin,
                              verticalMargin,
                              totalW - (sideMargin * 2.0f),
                              self.bounds.size.height - (verticalMargin * 2.0f));
    
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.customBgView.frame = frame;
    self.glossLayer.frame = self.customBgView.bounds;
    [CATransaction commit];
    
    CGFloat w = frame.size.width;
    CGFloat h = frame.size.height;
    CGFloat innerPad = isPad ? 16.0f : 12.0f;
    
    if (self.switchControl) {
        CGSize swSize = self.switchControl.bounds.size;
        CGFloat swX = w - innerPad - swSize.width;
        CGFloat swY = floorf((h - swSize.height) / 2.0f);
        self.switchControl.frame = CGRectMake(swX, swY, swSize.width, swSize.height);
        
        self.titleLabel.frame = CGRectMake(innerPad, 0.0f, swX - innerPad - 8.0f, h);
    } else {
        self.titleLabel.frame = CGRectMake(innerPad, 0.0f, w - (innerPad * 2.0f), h);
    }
}

@end

#pragma mark - Контроллер настроек

@interface HRSettingsViewController () <UITextFieldDelegate, UIAlertViewDelegate>

@property (nonatomic, strong) UISwitch *modeSwitch;
@property (nonatomic, strong) UISwitch *autoPlaySwitch;
@property (nonatomic, strong) UISwitch *backgroundDownloadSwitch;
@property (nonatomic, strong) UITextField *domainField;
@property (nonatomic, strong) UITextField *loginField;
@property (nonatomic, strong) UITextField *passwordField;
@property (nonatomic, strong) UITextField *publicDomainField;
@property (nonatomic, strong) NSArray *qualities;
@property (nonatomic, copy) NSString *selectedQuality;

- (UIImage *)drawRedCheckmark;

@end

@implementation HRSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Настройки";
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.07 blue:0.07 alpha:1.0];
    
    self.qualities = @[@"360p", @"480p", @"720p", @"1080p"];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.selectedQuality = [defaults stringForKey:kHRPreferredQualityKey] ?: @"720p";
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorColor = [UIColor clearColor];
    
    UIView *bgView = [[UIView alloc] initWithFrame:self.tableView.bounds];
    bgView.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
    self.tableView.backgroundView = bgView;
    [self.view addSubview:self.tableView];
    
    CGFloat fieldWidth = self.view.bounds.size.width - 130;
    
    NSString *savedPersonalDomain = [defaults stringForKey:kHRPersonalBaseURLKey];
    if (!savedPersonalDomain || [savedPersonalDomain length] == 0) {
        savedPersonalDomain = [defaults stringForKey:@"HR_MIRROR_DOMAIN"] ?: @"https://rezka.fi";
    }
    
    self.domainField = [[UITextField alloc] initWithFrame:CGRectMake(110, 10, fieldWidth, 26)];
    self.domainField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.domainField.placeholder = @"https://rezka.fi";
    self.domainField.text = savedPersonalDomain;
    self.domainField.textColor = [UIColor whiteColor];
    self.domainField.delegate = self;
    self.domainField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.domainField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    
    self.loginField = [[UITextField alloc] initWithFrame:CGRectMake(110, 10, fieldWidth, 26)];
    self.loginField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.loginField.placeholder = @"Email / Логин";
    self.loginField.text = [defaults stringForKey:@"HR_AUTH_LOGIN"];
    self.loginField.textColor = [UIColor whiteColor];
    self.loginField.delegate = self;
    self.loginField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.loginField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    
    self.passwordField = [[UITextField alloc] initWithFrame:CGRectMake(110, 10, fieldWidth, 26)];
    self.passwordField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.passwordField.placeholder = @"Пароль";
    self.passwordField.text = [defaults stringForKey:@"HR_AUTH_PASSWORD"];
    self.passwordField.textColor = [UIColor whiteColor];
    self.passwordField.secureTextEntry = YES;
    self.passwordField.delegate = self;
    
    NSString *savedPublicDomain = [defaults stringForKey:kHRPublicBaseURLKey];
    if (!savedPublicDomain || [savedPublicDomain length] == 0) {
        savedPublicDomain = ([HRHTTPClient sharedClient].authMode == HRAuthModePublic && [HRHTTPClient sharedClient].baseURLString)
        ? [HRHTTPClient sharedClient].baseURLString
        : @"https://rezka.ag";
    }
    
    self.publicDomainField = [[UITextField alloc] initWithFrame:CGRectMake(110, 10, fieldWidth, 26)];
    self.publicDomainField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.publicDomainField.placeholder = @"https://rezka.ag";
    self.publicDomainField.text = savedPublicDomain;
    self.publicDomainField.textColor = [UIColor whiteColor];
    self.publicDomainField.delegate = self;
    self.publicDomainField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.publicDomainField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    
    // Переключатель режима
    self.modeSwitch = [[UISwitch alloc] init];
    self.modeSwitch.on = ([HRHTTPClient sharedClient].authMode != HRAuthModePublic);
    self.modeSwitch.onTintColor = [UIColor colorWithRed:0.62 green:0.08 blue:0.08 alpha:1.0];
    [self.modeSwitch addTarget:self action:@selector(modeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    // Переключатель автовоспроизведения
    self.autoPlaySwitch = [[UISwitch alloc] init];
    self.autoPlaySwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"HR_AUTOPLAY_NEXT_EPISODE"];
    self.autoPlaySwitch.onTintColor = [UIColor colorWithRed:0.62 green:0.08 blue:0.08 alpha:1.0];
    [self.autoPlaySwitch addTarget:self action:@selector(autoPlaySwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    // Переключатель фоновой загрузки (по умолчанию выключен)
    self.backgroundDownloadSwitch = [[UISwitch alloc] init];
    self.backgroundDownloadSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"HR_BACKGROUND_AUDIO_ENABLED"];
    self.backgroundDownloadSwitch.onTintColor = [UIColor colorWithRed:0.62 green:0.08 blue:0.08 alpha:1.0];
    [self.backgroundDownloadSwitch addTarget:self action:@selector(backgroundDownloadSwitchChanged:) forControlEvents:UIControlEventValueChanged];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)modeSwitchChanged:(UISwitch *)sender
{
    [self.view endEditing:YES];
    if (sender.on) {
        NSString *url = [self.domainField.text length] > 0 ? self.domainField.text : @"https://rezka.fi";
        [[HRHTTPClient sharedClient] switchToMode:HRAuthModePersonal newBaseURL:url];
        self.domainField.text = [HRHTTPClient sharedClient].baseURLString;
    } else {
        NSString *url = [self.publicDomainField.text length] > 0 ? self.publicDomainField.text : @"https://rezka.ag";
        [[HRHTTPClient sharedClient] switchToMode:HRAuthModePublic newBaseURL:url];
        self.publicDomainField.text = [HRHTTPClient sharedClient].baseURLString;
    }
    [self.tableView reloadData];
}

- (void)autoPlaySwitchChanged:(UISwitch *)sender
{
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"HR_AUTOPLAY_NEXT_EPISODE"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)backgroundDownloadSwitchChanged:(UISwitch *)sender
{
    NSLog(@"[Settings] Тумблер фоновой загрузки переключен в: %@", sender.isOn ? @"ВКЛ" : @"ВЫКЛ");
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"HR_BACKGROUND_AUDIO_ENABLED"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"HRBackgroundAudioSettingChanged" object:@(sender.isOn)];
}

#pragma mark - Красная галочка

- (UIImage *)drawRedCheckmark
{
    CGSize size = CGSizeMake(16.0f, 14.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    UIBezierPath *path = [UIBezierPath bezierPath];
    [path moveToPoint:CGPointMake(2.0f, 7.0f)];
    [path addLineToPoint:CGPointMake(6.5f, 12.0f)];
    [path addLineToPoint:CGPointMake(14.5f, 2.0f)];
    path.lineWidth = 2.5f;
    path.lineCapStyle = kCGLineCapRound;
    path.lineJoinStyle = kCGLineJoinRound;
    [[UIColor colorWithRed:0.95f green:0.25f blue:0.25f alpha:1.0f] setStroke];
    [path stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - Table View Data Source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return HRSettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch ((HRSettingsSection)section) {
        case HRSettingsSectionConnectionMode:
            return 1;
        case HRSettingsSectionAuthDetails:
            return self.modeSwitch.on ? 4 : 2;
        case HRSettingsSectionDefaultQuality:
            return [self.qualities count];
        case HRSettingsSectionPlayback:
            return 2;
        case HRSettingsSectionAbout:
            return 1;
        case HRSettingsSectionReset:
            return 2;
        default:
            return 0;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UILabel *headerLabel = [[UILabel alloc] initWithFrame:CGRectMake(15, 8, tableView.bounds.size.width - 30, 24)];
    headerLabel.font = [UIFont boldSystemFontOfSize:(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 16.0f : 15.0f];
    headerLabel.textColor = [UIColor colorWithWhite:0.85f alpha:1.0f];
    headerLabel.backgroundColor = [UIColor clearColor];
    
    switch ((HRSettingsSection)section) {
        case HRSettingsSectionConnectionMode:
            headerLabel.text = @"Режим подключения";
            break;
        case HRSettingsSectionAuthDetails:
            headerLabel.text = self.modeSwitch.on ? @"Сервер и учетная запись" : @"Публичный доступ без аккаунта";
            break;
        case HRSettingsSectionDefaultQuality:
            headerLabel.text = @"Качество видео по умолчанию";
            break;
        case HRSettingsSectionPlayback:
            headerLabel.text = @"Воспроизведение и загрузки";
            break;
        case HRSettingsSectionAbout:
            headerLabel.text = @"О приложении";
            break;
        case HRSettingsSectionReset:
            headerLabel.text = @"Сброс данных";
            break;
        default:
            return nil;
    }
    
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 36)];
    [headerView addSubview:headerLabel];
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 36.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == HRSettingsSectionConnectionMode || indexPath.section == HRSettingsSectionPlayback) {
        return 48.0f;
    } else if (indexPath.section == HRSettingsSectionAuthDetails) {
        if ((self.modeSwitch.on && indexPath.row == 3) || (!self.modeSwitch.on && indexPath.row == 1)) {
            return 56.0f;
        }
    } else if (indexPath.section == HRSettingsSectionReset || indexPath.section == HRSettingsSectionAbout) {
        return 48.0f;
    }
    return 44.0f;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [UIColor clearColor];
    if ([cell isKindOfClass:[HRSettingsMenuButtonCell class]] || [cell isKindOfClass:[HRSettingsSwitchCell class]]) {
        cell.backgroundView = nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // 1. Пункты с переключателями
    if (indexPath.section == HRSettingsSectionConnectionMode || indexPath.section == HRSettingsSectionPlayback) {
        static NSString *switchCellID = @"HRSettingsSwitchCellID";
        HRSettingsSwitchCell *sCell = [tableView dequeueReusableCellWithIdentifier:switchCellID];
        if (!sCell) {
            sCell = [[HRSettingsSwitchCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:switchCellID];
        }
        
        if (indexPath.section == HRSettingsSectionConnectionMode) {
            [sCell attachSwitch:self.modeSwitch title:@"Персональный аккаунт"];
        } else {
            if (indexPath.row == 0) {
                [sCell attachSwitch:self.autoPlaySwitch title:@"Автопереключение серий"];
            } else if (indexPath.row == 1) {
                [sCell attachSwitch:self.backgroundDownloadSwitch title:@"Загрузка в фоне"];
            }
        }
        return sCell;
    }
    
    // 2. Красные кнопки действий
    BOOL isAuthButton = (indexPath.section == HRSettingsSectionAuthDetails &&
                         ((self.modeSwitch.on && indexPath.row == 3) || (!self.modeSwitch.on && indexPath.row == 1)));
    BOOL isResetButton = (indexPath.section == HRSettingsSectionReset);
    BOOL isAboutButton = (indexPath.section == HRSettingsSectionAbout);
    
    if (isAuthButton || isResetButton || isAboutButton) {
        static NSString *btnCellID = @"HRSettingsMenuButtonCellID";
        HRSettingsMenuButtonCell *btnCell = [tableView dequeueReusableCellWithIdentifier:btnCellID];
        if (!btnCell) {
            btnCell = [[HRSettingsMenuButtonCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:btnCellID];
        }
        
        btnCell.titleLabel.textColor = [UIColor whiteColor];
        
        if (indexPath.section == HRSettingsSectionAuthDetails) {
            btnCell.topInset = 10.0f;
            btnCell.bottomInset = 4.0f;
            btnCell.titleLabel.text = self.modeSwitch.on ? @"Войти / Авторизоваться" : @"Авторизация";
        } else if (indexPath.section == HRSettingsSectionAbout) {
            btnCell.topInset = 4.0f;
            btnCell.bottomInset = 4.0f;
            btnCell.titleLabel.text = @"Справка и возможности";
        } else {
            btnCell.topInset = 4.0f;
            btnCell.bottomInset = 4.0f;
            if (indexPath.row == 0) {
                btnCell.titleLabel.text = @"Сбросить авторизацию";
            } else {
                btnCell.titleLabel.text = @"Полный сброс приложения";
            }
        }
        return btnCell;
    }
    
    // 3. Стандартные строки полей ввода и выбора качества
    static NSString *cellID = @"DarkSettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellID];
        
        HRGroupedCellBackgroundView *bgView = [[HRGroupedCellBackgroundView alloc] initWithFrame:cell.bounds];
        cell.backgroundView = bgView;
        
        HRGroupedCellBackgroundView *selBgView = [[HRGroupedCellBackgroundView alloc] initWithFrame:cell.bounds];
        selBgView.isSelectedBackground = YES;
        cell.selectedBackgroundView = selBgView;
    }
    
    for (UIView *v in cell.contentView.subviews) {
        if (v == self.domainField || v == self.loginField || v == self.passwordField || v == self.publicDomainField) {
            [v removeFromSuperview];
        }
    }
    
    cell.textLabel.text = nil;
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    cell.detailTextLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = [UIColor clearColor];
    
    HRGroupCellPosition pos = HRGroupCellPositionMiddle;
    
    switch ((HRSettingsSection)indexPath.section) {
        case HRSettingsSectionAuthDetails: {
            if (self.modeSwitch.on) {
                if (indexPath.row == 0) {
                    pos = HRGroupCellPositionTop;
                    cell.textLabel.text = @"Зеркало:";
                    [cell.contentView addSubview:self.domainField];
                } else if (indexPath.row == 1) {
                    pos = HRGroupCellPositionMiddle;
                    cell.textLabel.text = @"Email:";
                    [cell.contentView addSubview:self.loginField];
                } else if (indexPath.row == 2) {
                    pos = HRGroupCellPositionBottom;
                    cell.textLabel.text = @"Пароль:";
                    [cell.contentView addSubview:self.passwordField];
                }
            } else {
                if (indexPath.row == 0) {
                    pos = HRGroupCellPositionSingle;
                    cell.textLabel.text = @"Домен:";
                    [cell.contentView addSubview:self.publicDomainField];
                }
            }
            break;
        }
        case HRSettingsSectionDefaultQuality: {
            NSString *q = [self.qualities objectAtIndex:indexPath.row];
            cell.textLabel.text = q;
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
            
            if (indexPath.row == 0) {
                pos = HRGroupCellPositionTop;
            } else if (indexPath.row == [self.qualities count] - 1) {
                pos = HRGroupCellPositionBottom;
            } else {
                pos = HRGroupCellPositionMiddle;
            }
            
            if ([q isEqualToString:self.selectedQuality]) {
                cell.textLabel.textColor = [UIColor colorWithRed:0.95f green:0.25f blue:0.25f alpha:1.0f];
                UIImageView *checkView = [[UIImageView alloc] initWithImage:[self drawRedCheckmark]];
                cell.accessoryView = checkView;
                cell.accessoryType = UITableViewCellAccessoryNone;
            } else {
                cell.textLabel.textColor = [UIColor whiteColor];
                cell.accessoryView = nil;
                cell.accessoryType = UITableViewCellAccessoryNone;
            }
            break;
        }
        default:
            break;
    }
    
    if ([cell.backgroundView isKindOfClass:[HRGroupedCellBackgroundView class]]) {
        [(HRGroupedCellBackgroundView *)cell.backgroundView setPosition:pos];
    }
    if ([cell.selectedBackgroundView isKindOfClass:[HRGroupedCellBackgroundView class]]) {
        [(HRGroupedCellBackgroundView *)cell.selectedBackgroundView setPosition:pos];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.view endEditing:YES];
    
    switch ((HRSettingsSection)indexPath.section) {
        case HRSettingsSectionAuthDetails: {
            if (self.modeSwitch.on && indexPath.row == 3) {
                [self performLogin];
            } else if (!self.modeSwitch.on && indexPath.row == 1) {
                [self launchPublicAuthModule];
            }
            break;
        }
        case HRSettingsSectionDefaultQuality: {
            self.selectedQuality = [self.qualities objectAtIndex:indexPath.row];
            [[NSUserDefaults standardUserDefaults] setObject:self.selectedQuality forKey:kHRPreferredQualityKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.tableView reloadData];
            break;
        }
        case HRSettingsSectionAbout: {
            [self showWelcomeScreen];
            break;
        }
        case HRSettingsSectionReset: {
            if (indexPath.row == 0) {
                [self promptAuthReset];
            } else if (indexPath.row == 1) {
                [self promptFullReset];
            }
            break;
        }
        default:
            break;
    }
}

- (void)showWelcomeScreen
{
    HRWelcomeViewController *welcomeVC = [[HRWelcomeViewController alloc] init];
    welcomeVC.textFileName = @"FAQText";
    welcomeVC.displayTitle = @"СПРАВКА";
    welcomeVC.displaySubtitle = @"ОТВЕТЫ НА ВОПРОСЫ И ВОЗМОЖНОСТИ";
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:welcomeVC];
    nav.modalPresentationStyle = UIModalPresentationFullScreen;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)showAlertTitle:(NSString *)title message:(NSString *)msg
{
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:title message:msg delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [a show];
}

#pragma mark - Авторизация (Персональный режим)

- (void)performLogin
{
    NSString *login = [self.loginField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *password = self.passwordField.text;
    NSString *domain = [self.domainField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (login.length == 0 || password.length == 0) {
        [self showAlertTitle:@"Внимание" message:@"Пожалуйста, введите Email и Пароль."];
        return;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:login forKey:@"HR_AUTH_LOGIN"];
    [defaults setObject:password forKey:@"HR_AUTH_PASSWORD"];
    if (domain.length > 0) {
        [[HRHTTPClient sharedClient] switchToMode:HRAuthModePersonal newBaseURL:domain];
        self.domainField.text = [HRHTTPClient sharedClient].baseURLString;
    }
    [defaults synchronize];
    
    [[HRHTTPClient sharedClient] loginWithUsername:login
                                          password:password
                                        completion:^(BOOL success, NSError *error) {
                                            if (error) {
                                                [self showAlertTitle:@"Ошибка сети" message:error.localizedDescription ?: @"Не удалось связаться с сервером."];
                                                return;
                                            }
                                            
                                            if (success) {
                                                [[NSNotificationCenter defaultCenter] postNotificationName:@"HRNeedReloadCatalogNotification" object:nil];
                                                [self showAlertTitle:@"Успех" message:@"Авторизация прошла успешно. Приложение использует персональное зеркало."];
                                            } else {
                                                [self showAlertTitle:@"Ошибка" message:@"Неверный логин или пароль. Попробуйте еще раз."];
                                            }
                                        }];
}

#pragma mark - Запуск выделенного модуля авторизации (Публичный режим)

- (void)launchPublicAuthModule
{
    NSString *publicUrl = [self.publicDomainField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (publicUrl.length == 0) publicUrl = @"https://rezka.ag";
    
    [[HRHTTPClient sharedClient] switchToMode:HRAuthModePublic newBaseURL:publicUrl];
    self.publicDomainField.text = [HRHTTPClient sharedClient].baseURLString;
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    HRPublicAuthViewController *authVC = [[HRPublicAuthViewController alloc] init];
    authVC.targetURLString = [HRHTTPClient sharedClient].baseURLString;
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:authVC];
    nav.navigationBar.barStyle = UIBarStyleBlack;
    
    [self presentViewController:nav animated:YES completion:nil];
}

#pragma mark - Сброс авторизации и полный сброс приложения

- (void)promptAuthReset
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Сброс авторизации"
                                                    message:@"Будут удалены сохранённые логин, пароль и cookies HDRezka. История, избранное, загрузки, зеркало и остальные настройки останутся. Продолжить?"
                                                   delegate:self
                                          cancelButtonTitle:@"Отмена"
                                          otherButtonTitles:@"Сбросить", nil];
    alert.tag = 998;
    [alert show];
}

- (void)promptFullReset
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Внимание"
                                                    message:@"Это удалит всю историю, избранное, скачанные файлы, авторизацию и настройки. Приложение вернётся к заводскому состоянию. Продолжить?"
                                                   delegate:self
                                          cancelButtonTitle:@"Отмена"
                                          otherButtonTitles:@"Сбросить", nil];
    alert.tag = 999;
    [alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == alertView.cancelButtonIndex) {
        return;
    }
    
    if (alertView.tag == 998) {
        [[HRHTTPClient sharedClient] performAuthReset];
        self.loginField.text = @"";
        self.passwordField.text = @"";
        [self.tableView reloadData];
        
        [self showAlertTitle:@"Авторизация сброшена"
                     message:@"Сохранённые данные входа и сессия HDRezka удалены. При следующем входе введите логин и пароль заново."];
    } else if (alertView.tag == 999) {
        NSString *errorMsg = nil;
        if (![[HRHTTPClient sharedClient] performFullApplicationResetWithErrorMessage:&errorMsg]) {
            [self showAlertTitle:@"Сброс не выполнен" message:errorMsg ?: @"Произошла ошибка при сбросе данных."];
            return;
        }
        
        self.selectedQuality = @"720p";
        self.domainField.text = @"https://rezka.fi";
        self.loginField.text = @"";
        self.passwordField.text = @"";
        self.publicDomainField.text = @"https://rezka.ag";
        self.modeSwitch.on = YES;
        self.autoPlaySwitch.on = NO;
        self.backgroundDownloadSwitch.on = NO;
        [self.tableView reloadData];
        
        [self showAlertTitle:@"Сброс завершён"
                     message:@"Приложение полностью очищено. Рекомендуется перезапустить приложение (закрыть в многозадачности)."];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

@end