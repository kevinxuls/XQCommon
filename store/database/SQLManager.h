//
//  SQLManager.h
//  WACommon
//
//  Created by kevinxuls on 7/7/15.
//  Copyright (c) 2015 kevinxu. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SQLContext.h"

@interface SQLManager : NSObject

- (id)init NS_UNAVAILABLE;

+ (void)excuteUpdate:(BOOL (^)(void))operation completionBlock:(void (^)(BOOL success))block;
+ (void)excuteQuery:(NSArray * (^)(void))operation completionBlock:(void (^)(NSArray *results))block;

@end
