#import "HRDownloadTask.h"

@implementation HRDownloadTask

- (id)init
{
    self = [super init];
    if (self) {
        _status = HRDownloadStatusWaiting;
        _progress = 0.0f;
    }
    return self;
}

@end