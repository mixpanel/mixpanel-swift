//
//  ExceptionWrapper.m
//  Mixpanel
//
//  Created by Zihe Jia on 8/29/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//

#import "ExceptionWrapper.h"

@implementation ExceptionWrapper

+ (void)try:(void(^)(void))try catch:(void(^)(NSException *exception))catch finally:(void(^)(void))finally {
    @try {
        try ? try() : nil;
    }
    @catch (NSException *exception) {
        catch ? catch(exception) : nil;
    }
    @finally {
        finally ? finally() : nil;
    }
}

@end
