//
//  JSONExceptionHandler.m
//  Mixpanel
//
//  Created to safely handle NSExceptions from JSONSerialization
//

#import "JSONExceptionHandler.h"

@implementation JSONExceptionHandler

+ (id _Nullable)safeJSONObjectWithData:(NSData *)data
                                error:(NSError *_Nullable *_Nullable)error {
    @try {
        return [NSJSONSerialization JSONObjectWithData:data
                                               options:0
                                                 error:error];
    } @catch (NSException *exception) {
        // Convert NSException to NSError for Swift consumption
        // This catches exceptions like NSMallocException that would otherwise crash the app
        if (error != NULL) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: exception.reason ?: @"Unknown NSException during JSON deserialization",
                @"ExceptionName": exception.name,
                @"ExceptionReason": exception.reason ?: @"",
            };
            *error = [NSError errorWithDomain:@"com.mixpanel.JSONExceptionHandler"
                                         code:-1
                                     userInfo:userInfo];
        }
        return nil;
    }
}

@end
