#import "HRMovieCell.h"
#import "HRMovie.h"
#import <QuartzCore/QuartzCore.h>

@implementation HRMovieCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
        
        self.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.08 alpha:1.0];
        self.selectionStyle = UITableViewCellSelectionStyleGray;
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        // 1. Постер фильма
        self.posterImageView = [[UIImageView alloc] init];
        self.posterImageView.contentMode = UIViewContentModeScaleAspectFill;
        self.posterImageView.clipsToBounds = YES;
        self.posterImageView.layer.cornerRadius = isPad ? 6.0f : 4.0f;
        self.posterImageView.layer.borderColor = [[UIColor colorWithWhite:0.25f alpha:1.0f] CGColor];
        self.posterImageView.layer.borderWidth = 1.0f;
        self.posterImageView.backgroundColor = [UIColor colorWithWhite:0.18f alpha:1.0f];
        [self.contentView addSubview:self.posterImageView];
        
        // 2. Черный бейдж "HD"
        self.badgeHDLabel = [[UILabel alloc] init];
        self.badgeHDLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.85];
        self.badgeHDLabel.textColor = [UIColor whiteColor];
        self.badgeHDLabel.font = [UIFont boldSystemFontOfSize:(isPad ? 11.0f : 8.0f)];
        self.badgeHDLabel.textAlignment = NSTextAlignmentCenter;
        self.badgeHDLabel.text = @"HD";
        self.badgeHDLabel.layer.cornerRadius = isPad ? 3.0f : 2.0f;
        self.badgeHDLabel.layer.masksToBounds = YES;
        [self.posterImageView addSubview:self.badgeHDLabel];
        
        // 3. Заголовок
        self.titleLabel = [[UILabel alloc] init];
        self.titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.titleLabel.font = [UIFont boldSystemFontOfSize:(isPad ? 22.0f : 15.0f)];
        self.titleLabel.textColor = [UIColor whiteColor];
        self.titleLabel.backgroundColor = [UIColor clearColor];
        self.titleLabel.numberOfLines = isPad ? 2 : 1;
        [self.contentView addSubview:self.titleLabel];
        
        // 4. Сериал / Фильм + Рейтинг
        self.subtitleLabel = [[UILabel alloc] init];
        self.subtitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.subtitleLabel.font = [UIFont systemFontOfSize:(isPad ? 18.0f : 14.0f)];
        self.subtitleLabel.textColor = [UIColor colorWithRed:0.80 green:0.25 blue:0.25 alpha:1.0];
        self.subtitleLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:self.subtitleLabel];
        
        // 5. Год, страна, жанры (строка информации как в Фильмах и Сериалах)
        self.descriptionTextLabel = [[UILabel alloc] init];
        self.descriptionTextLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.descriptionTextLabel.font = [UIFont systemFontOfSize:(isPad ? 17.0f : 13.0f)];
        self.descriptionTextLabel.textColor = [UIColor colorWithWhite:0.65f alpha:1.0f];
        self.descriptionTextLabel.backgroundColor = [UIColor clearColor];
        self.descriptionTextLabel.numberOfLines = isPad ? 3 : 2;
        [self.contentView addSubview:self.descriptionTextLabel];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    BOOL isPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    CGFloat cellW = self.contentView.bounds.size.width;
    CGFloat padX = isPad ? 20.0f : 10.0f;
    CGFloat padY = isPad ? 12.0f : 8.0f;
    
    CGFloat posterW = isPad ? 88.0f : 56.0f;
    CGFloat posterH = isPad ? 126.0f : 80.0f;
    self.posterImageView.frame = CGRectMake(padX, padY, posterW, posterH);
    
    CGFloat hdBadgeW = isPad ? 26.0f : 18.0f;
    CGFloat badgeH = isPad ? 20.0f : 14.0f;
    CGFloat badgeY = posterH - badgeH - (isPad ? 4.0f : 2.0f);
    self.badgeHDLabel.frame = CGRectMake(posterW - hdBadgeW - 2.0f, badgeY, hdBadgeW, badgeH);
    
    CGFloat textX = padX + posterW + (isPad ? 16.0f : 10.0f);
    CGFloat textW = cellW - textX - (isPad ? 16.0f : 10.0f);
    
    if (isPad) {
        self.titleLabel.frame = CGRectMake(textX, padY, textW, 54.0f);
        self.subtitleLabel.frame = CGRectMake(textX, padY + 56.0f, textW, 22.0f);
        self.descriptionTextLabel.frame = CGRectMake(textX, padY + 80.0f, textW, 54.0f);
    } else {
        self.titleLabel.frame = CGRectMake(textX, padY, textW, 20.0f);
        self.subtitleLabel.frame = CGRectMake(textX, padY + 21.0f, textW, 18.0f);
        self.descriptionTextLabel.frame = CGRectMake(textX, padY + 41.0f, textW, 35.0f);
    }
}

- (NSString *)cleanInfoForDisplay:(NSString *)info
{
    if (![info isKindOfClass:[NSString class]] || [info length] == 0) {
        return @"";
    }
    
    NSMutableString *cleanInfo = [NSMutableString stringWithString:info];
    while (YES) {
        NSRange markerRange = [cleanInfo rangeOfString:@"[S:"];
        if (markerRange.location == NSNotFound) {
            break;
        }
        NSRange endRange = [cleanInfo rangeOfString:@"]" options:0
                                              range:NSMakeRange(markerRange.location, [cleanInfo length] - markerRange.location)];
        if (endRange.location == NSNotFound) {
            break;
        }
        NSString *marker = [cleanInfo substringWithRange:NSMakeRange(markerRange.location, endRange.location - markerRange.location + 1)];
        if ([marker rangeOfString:@"E:"].location != NSNotFound) {
            [cleanInfo deleteCharactersInRange:NSMakeRange(markerRange.location, endRange.location - markerRange.location + 1)];
        } else {
            break;
        }
    }
    return [cleanInfo stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)configureWithMovie:(HRMovie *)movie
{
    self.titleLabel.text = movie.title ?: @"";
    
    // "Сериал" без скобок
    if (movie.isSeries) {
        self.subtitleLabel.text = @"Сериал";
    } else {
        self.subtitleLabel.text = @"Фильм";
    }
    
    if ([movie.rating length] > 0 && [movie.rating rangeOfString:@"|"].location == NSNotFound) {
        self.subtitleLabel.text = [NSString stringWithFormat:@"★ %@ • %@", movie.rating, self.subtitleLabel.text];
    }
    
    // Выводим Год, Страну, Жанры
    self.descriptionTextLabel.text = [self cleanInfoForDisplay:movie.info];
}

@end