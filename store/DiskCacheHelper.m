//
//  DiskCacheHelper.m
//  QCCore
//
//  Created by XuQian on 4/13/16.
//  Copyright © 2016 qcwl. All rights reserved.
//

#import "DiskCacheHelper.h"
#import "QCCodingUtilities.h"

static inline NSString * DiskCachePath(NSString *identifier)
{
    NSString *path = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject ?: nil;
    if (!path) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return [path stringByAppendingPathComponent:identifier];
}

static inline NSData * DiskCachePackageToData(id object)
{
    if (object && [object conformsToProtocol:@protocol(NSCoding)]) {
        return [NSKeyedArchiver archivedDataWithRootObject:object];
    }
    return nil;
}

id DiskCacheRead(NSString *key, NSString *identifier)
{
    NSString *diskPath = DiskCachePath(identifier);
    NSString *path = [diskPath stringByAppendingPathComponent:QCMd5Encoding(key)];
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:diskPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:diskPath withIntermediateDirectories:YES attributes:nil error:&error];
//        @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"Path Not Exist" userInfo:error?@{@"error":error}:nil];
        return nil;
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) {
//        @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"Read File Error" userInfo:nil];
        return nil;
    }
    id object = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (!object) {
//        @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"Unarchiver Data Error" userInfo:nil];
        return nil;
    }
    return object;
}

BOOL DiskCacheSaveToDisk(id object, NSString *key, NSString *identifier, BOOL allowOverride)
{
    if (!object) {
//        @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"NULL Object" userInfo:nil];
        return NO;
    }
    if (!key) {
//        @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"NULL Key" userInfo:nil];
        return NO;
    }
    if (!identifier) {
//        @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"NULL Identifier" userInfo:nil];
        return NO;
    }
    
    NSString *diskPath = DiskCachePath(identifier);
    NSString *path = [diskPath stringByAppendingPathComponent:QCMd5Encoding(key)];
    
    NSError *error = nil;
    if (![[NSFileManager defaultManager] fileExistsAtPath:diskPath]) {
        if (![[NSFileManager defaultManager] createDirectoryAtPath:diskPath withIntermediateDirectories:YES attributes:nil error:&error]) {
//            @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"Create Directory Failed" userInfo:error?@{@"error":error}:nil];
            return NO;
        }
    }
    
    NSData *data = DiskCachePackageToData(object);
    if (!data) {
//        @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"Create File Failed" userInfo:@{@"error":error}];
        return NO;
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        if (allowOverride) {
            if (![data writeToFile:path atomically:YES]) {
//                @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"Create File Failed" userInfo:@{@"error":error}];
                return NO;
            }else {
                return YES;
            }
        }else {
//            @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"File Existed" userInfo:nil];
            return NO;
        }
    }else {
        if (![[NSFileManager defaultManager] createFileAtPath:path contents:data attributes:nil]) {
//            @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"Create File Failed" userInfo:@{@"error":error}];
            return NO;
        }else {
            return YES;
        }
    }
}

void DiskCacheMultiSaveToDisk(NSDictionary<NSString *, NSObject *> *keyValues, NSString *identifier, BOOL allowOverride, DiskCacheResponseBlock completionBlock)
{
    if (keyValues.count == 0) {
        completionBlock ? completionBlock([NSError errorWithDomain:@"DiskCacheError" code:-1 userInfo:@{@"reason":@"No Value To Save"}]) : nil;
        return;
    }
    dispatch_group_t group = dispatch_group_create();
    dispatch_queue_t queue = dispatch_queue_create("__disk_cache_queue", DISPATCH_QUEUE_SERIAL);
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(1);
    
    __block NSError *error = nil;
    for (NSString *key in keyValues.allKeys) {
        dispatch_group_async(group, queue, ^{
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
            
            @autoreleasepool {
                @try {
                    if (!DiskCacheSaveToDisk(keyValues[key], key, identifier, allowOverride)) {
                        error = [NSError errorWithDomain:@"DiskCacheError" code:-1 userInfo:@{@"reason":[NSString stringWithFormat:@"Save Value For Key \"%@\" Failed", key]}];
                        if (completionBlock) dispatch_async(dispatch_get_main_queue(), ^{
                            completionBlock(error);
                        });
                        return;
                    }
                } @catch (NSException *exception) {
                    error = exception.userInfo ? exception.userInfo[@"error"] ?: nil : nil;
                    if (completionBlock) dispatch_async(dispatch_get_main_queue(), ^{
                        completionBlock(error);
                    });
                    return;
                }
            }
            dispatch_semaphore_signal(semaphore);
        });
    }
    dispatch_group_notify(group, queue, ^{
        if (completionBlock) dispatch_async(dispatch_get_main_queue(), ^{
            completionBlock(error);
        });
    });
}

BOOL DiskCacheRemove(NSString * key, NSString * identifier)
{
    if (!key) {
//        @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"NULL Key" userInfo:nil];
        return NO;
    }
    if (!identifier) {
//        @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"NULL Identifier" userInfo:nil];
        return NO;
    }
    
    NSString *diskPath = DiskCachePath(identifier);
    NSString *path = [diskPath stringByAppendingPathComponent:QCMd5Encoding(key)];
    
    NSError *error = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:diskPath]) {
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
        if (!success || error) {
//            @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"Remove File Failed" userInfo:error?@{@"error":error}:nil];
            return NO;
        }
    }
    return YES;
}

BOOL DiskCacheClean(NSString * identifier)
{
    if (!identifier) {
//        @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"NULL Identifier" userInfo:nil];
        return NO;
    }
    
    NSString *diskPath = DiskCachePath(identifier);
    
    NSError *error = nil;
    if ([[NSFileManager defaultManager] fileExistsAtPath:diskPath]) {
        BOOL success = [[NSFileManager defaultManager] removeItemAtPath:diskPath error:&error];
        if (!success || error) {
//            @throw [NSException exceptionWithName:@"DiskCacheError" reason:@"Remove Directory Failed" userInfo:error?@{@"error":error}:nil];
            return NO;
        }
    }
    return YES;
}
