//
//  ExceptionWrapper.h
//  Mixpanel
//
//  Created by Zihe Jia on 8/29/18.
//  Copyright © 2018 Mixpanel. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ExceptionWrapper : NSObject

+ (void)try:(void(^)(void))try catch:(void(^)(NSException *exception))catch finally:(void(^)(void))finally;

@end
