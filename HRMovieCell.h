#import <UIKit/UIKit.h>

@class HRMovie;

@interface HRMovieCell : UITableViewCell

@property (nonatomic, strong) UIImageView *posterImageView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *descriptionTextLabel;

// Бейджи на постере
@property (nonatomic, strong) UILabel *badgeSeriesLabel;
@property (nonatomic, strong) UILabel *badgeHDLabel;

- (void)configureWithMovie:(HRMovie *)movie;

@end