//
//  DiskCacheHelper.h
//  QCCore
//
//  Created by XuQian on 4/13/16.
//  Copyright © 2016 qcwl. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  多文件连续存储的回调block类型
 *  @param error 回调错误信息，存储成功时返回nil，失败时返回错误信息
 */
typedef void (^DiskCacheResponseBlock)(NSError * _Nullable error);

/**
 *  读取文件内容。
 *  @param key        对应关键字，不能为空
 *  @param identifier 对应分类，不能为空
 *  @return id        读取到的文件转化后的NSObject对象
 *  @return nil       读取文件失败
 */
FOUNDATION_EXTERN _Nullable id DiskCacheRead(NSString * _Nonnull key, NSString * _Nonnull identifier);

/**
 *  将任意实现了NSCoding协议的对象写入沙盒，不需要关注写入的位置，只需使用DiskCacheRead函数来读去即可。
 *  @param object        要写入沙盒的对象，不能为空
 *  @param key           对应关键字，不能为空
 *  @param identifier    对应分类，不能为空
 *  @param allowOverride 是否允许覆盖写入。如果设为NO，在本地有同一文件存在会导致存储失败
 *  @return YES          写入成功
 *  @return NO           写入失败
 */
FOUNDATION_EXTERN BOOL DiskCacheSaveToDisk(id _Nonnull object, NSString * _Nonnull key, NSString * _Nonnull identifier, BOOL allowOverride);

/**
 *  连续将多个对象存储到沙盒中，在并行线程中以串行FIFO方式进行存储。
 *  @param keyValues             要写入沙盒的对象字典，不能为空，不能为空字典
 *  @param identifier            对应分类，不能为空
 *  @param allowOverride         是否允许覆盖写入。如果设为NO，在本地有同一文件存在会导致存储失败，同时终止后续对象的写入操作
 *  @param completionBlock       操作结束的回调block，必定会响应回调，但可以为空
 */
FOUNDATION_EXTERN void DiskCacheMultiSaveToDisk(NSDictionary<NSString *, NSObject *> * _Nonnull keyValues, NSString * _Nonnull identifier, BOOL allowOverride, DiskCacheResponseBlock _Nullable completionBlock);

/**
 *  删除沙盒中的某个文件
 *  @param key        对应关键字，不能为空
 *  @param identifier 对应分类，不能为空
 *  @return YES       删除成功
 *  @return NO        删除失败
 */
FOUNDATION_EXTERN BOOL DiskCacheRemove(NSString * _Nonnull key, NSString * _Nonnull identifier);

/**
 *  删除沙盒中某个文件夹中所有内容
 *  @param identifier 对应分类，不能为空
 *  @return YES       删除成功
 *  @return NO        删除失败
 */
FOUNDATION_EXTERN BOOL DiskCacheClean(NSString * _Nonnull identifier);
