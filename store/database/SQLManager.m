//
//  SQLManager.m
//  WACommon
//
//  Created by kevinxuls on 7/7/15.
//  Copyright (c) 2015 kevinxu. All rights reserved.
//

#import "SQLManager.h"

static dispatch_queue_t _operationQueue;

@implementation SQLManager

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _operationQueue = dispatch_queue_create("sql_db_operation_queue", DISPATCH_QUEUE_SERIAL);
    });
}

+ (void)excuteUpdate:(BOOL (^)(void))operation completionBlock:(void (^)(BOOL success))block
{
    if (!operation) return;
    
    dispatch_async(_operationQueue, ^{
        BOOL status = operation();
        if (block) dispatch_async(dispatch_get_main_queue(), ^{
            block(status);
        });
    });
}

+ (void)excuteQuery:(NSArray * (^)(void))operation completionBlock:(void (^)(NSArray *results))block
{
    if (!operation) return;
    
    dispatch_async(_operationQueue, ^{
        NSArray *results = operation();
        if (block) dispatch_async(dispatch_get_main_queue(), ^{
            block(results);
        });
    });
}

@end
