//
//  JSONExceptionHandler.m
//  MixpanelObjC
//

#import "JSONExceptionHandler.h"

id _Nullable JSONExceptionHandler_safeDeserialize(NSData *data, NSError *_Nullable *_Nullable error) {
    @try {
        // Call Foundation's JSONSerialization - can throw NSException
        return [NSJSONSerialization JSONObjectWithData:data
                                               options:0
                                                 error:error];
    } @catch (NSException *exception) {
        // Convert NSException to NSError for Swift consumption
        if (error != NULL) {
            NSDictionary *userInfo = @{
                NSLocalizedDescriptionKey: exception.reason ?: @"NSException during JSON deserialization",
                NSLocalizedFailureReasonErrorKey: exception.name,
            };
            *error = [NSError errorWithDomain:@"com.mixpanel.JSONExceptionHandler"
                                         code:-1
                                     userInfo:userInfo];
        }
        return nil;
    }
}
