#import <Foundation/Foundation.h>

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
    NSString *blockedURL = @"PUT THE URL HERE";
    if ([[request.URL absoluteString] isEqualToString:blockedURL]) {
        if (completionHandler) {
            NSError *error = [NSError errorWithDomain:@"BlockedURLDomain" code:403 userInfo:@{NSLocalizedDescriptionKey: @"Access denied"}];
            completionHandler(nil, nil, error);
        }
        return nil;
    }
    return %orig;
}

%end