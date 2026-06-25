//
//  JSONExceptionHandler.h
//  Mixpanel
//
//  Created to safely handle NSExceptions from JSONSerialization
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Safe wrapper around JSONSerialization that catches NSExceptions
@interface JSONExceptionHandler : NSObject

/// Safely deserialize JSON data, catching both NSError and NSException.
/// Returns nil if deserialization fails for any reason (invalid JSON, NSException, etc.)
/// @param data The JSON data to deserialize
/// @param error Optional error pointer. Set to NSError if Swift Error occurs, or synthetic NSError if NSException occurs.
/// @return Deserialized object or nil on failure
+ (id _Nullable)safeJSONObjectWithData:(NSData *)data
                                error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
