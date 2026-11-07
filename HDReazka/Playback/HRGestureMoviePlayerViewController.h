#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

@class HRGestureMoviePlayerViewController;

@protocol HRGestureMoviePlayerDelegate <NSObject>
@optional
- (void)moviePlayerDidRequestNextTrack:(HRGestureMoviePlayerViewController *)player;
- (void)moviePlayerDidRequestPreviousTrack:(HRGestureMoviePlayerViewController *)player;
@end

@interface HRGestureMoviePlayerViewController : UIViewController

@property (nonatomic, strong, readonly) MPMoviePlayerController *moviePlayer;
@property (nonatomic, copy) NSString *movieTitle;
@property (nonatomic, weak) id<HRGestureMoviePlayerDelegate> delegate;

// Инициализация
- (instancetype)initWithContentURL:(NSURL *)url;

// Загрузка нового видео без пересоздания контроллера (для переключения серий)
- (void)playNewVideoWithURL:(NSURL *)url title:(NSString *)title;

// Управление спиннером снаружи (на время запроса API для следующей серии)
- (void)showLoadingIndicator;
- (void)hideLoadingIndicator;

@end