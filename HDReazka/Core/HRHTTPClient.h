#import <Foundation/Foundation.h>

#define kHRPublicUserAgent @"Mozilla/5.0 (iPhone; CPU iPhone OS 6_1_3 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10B326 Safari/8536.25"

extern NSString * const kHRPersonalBaseURLKey;
extern NSString * const kHRPublicBaseURLKey;

typedef NS_ENUM(NSInteger, HRAuthMode) {
    HRAuthModePersonal = 0,
    HRAuthModePublic = 1
};

typedef void (^HRHTTPClientCompletionBlock)(NSData *data, NSHTTPURLResponse *response, NSError *error);

@interface HRHTTPClient : NSObject

@property (nonatomic, assign) HRAuthMode authMode;
@property (nonatomic, copy) NSString *baseURLString;
@property (nonatomic, copy) NSString *customUserAgent;

+ (instancetype)sharedClient;

- (void)switchToMode:(HRAuthMode)mode newBaseURL:(NSString *)newBaseURL;
- (void)updatePublicUserAgent:(NSString *)userAgent;
- (void)purgeRezkaCookies;

// Единая проверка сессионных cookies и авторизация
- (BOOL)hasSessionCookies;
- (void)loginWithUsername:(NSString *)username
                 password:(NSString *)password
               completion:(void (^)(BOOL success, NSError *error))completion;

// Сервисные методы сброса данных
- (void)performAuthReset;
- (BOOL)performFullApplicationResetWithErrorMessage:(NSString **)outErrorMessage;

- (void)GET:(NSString *)path
 parameters:(NSDictionary *)parameters
 completion:(HRHTTPClientCompletionBlock)completion;

- (void)POST:(NSString *)path
  parameters:(NSDictionary *)parameters
  completion:(HRHTTPClientCompletionBlock)completion;

- (void)cancelAllRequests;

@end