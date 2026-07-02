//
//  JSONExceptionHandler.h
//  MixpanelObjC
//
//  Safe wrapper around JSONSerialization that catches NSExceptions
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Safely deserialize JSON data, catching both NSError and NSException.
/// @param data The JSON data to deserialize
/// @param error Optional error pointer (set if Swift Error or NSException occurs)
/// @return Deserialized object, or nil if deserialization fails
id _Nullable JSONExceptionHandler_safeDeserialize(NSData *data, NSError *_Nullable *_Nullable error);

NS_ASSUME_NONNULL_END
