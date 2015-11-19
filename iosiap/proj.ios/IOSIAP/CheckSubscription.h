//
//  CheckSubscription.m
//  PluginIAP
//
//  Created by Yuan Chen on 15/11/19.
//  Copyright © 2015年 cocos2dx. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface CheckSubscription : NSObject

+(void) checkWithAppReceipt:(NSString*) productID
                currentTime:(NSDate*) currentTime
                    success:(void (^)()) successBlock
                       fail:(void (^)()) failBlock;

+ (void)checkWithTransactionReceipt:(NSString*) productID
                        currentTime:(NSDate*) currentTime
                            success:(void (^)()) successBlock
                               fail:(void (^)()) failBlock;
@end