#import <Foundation/Foundation.h>

#define kHRPublicUserAgent @"Mozilla/5.0 (iPhone; CPU iPhone OS 6_1_3 like Mac OS X) AppleWebKit/536.26 (KHTML, like Gecko) Version/6.0 Mobile/10B326 Safari/8536.25"

typedef NS_ENUM(NSInteger, HRAuthMode) {
    HRAuthModePersonal = 0,
    HRAuthModePublic   = 1
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

- (void)GET:(NSString *)path
 parameters:(NSDictionary *)parameters
 completion:(HRHTTPClientCompletionBlock)completion;

- (void)POST:(NSString *)path
  parameters:(NSDictionary *)parameters
  completion:(HRHTTPClientCompletionBlock)completion;

- (void)cancelAllRequests;

@end