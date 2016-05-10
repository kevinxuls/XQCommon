//
//  BaseModel.h
//  QCCore
//
//  Created by XuQian on 2/3/16.
//  Copyright © 2016 qcwl. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 希望属性自动mapping成Model类型，可以写一个与Model类同名的protocol，继承BaseModelProtocol即可
 */
@protocol BaseModelProtocol
- (nullable id)initWithDictionary:(nonnull NSDictionary *)dictionary;
@end

/**
 BaseModel作为模型转换工具的基础类，可以自动mapping数据到对应的属性上
 */
@interface BaseModel : NSObject <BaseModelProtocol, NSCopying, NSSecureCoding>

@property (nonatomic, readonly, nonnull) NSDictionary *originalDictionary;

/**
 根据JSON对象自动生成对应的Model。如果需要生成空对象，请使用init函数
 @param dictionary Model的数据源，JSON格式的字典容器
 @return Model对象
 */
- (nullable id)initWithDictionary:(nonnull NSDictionary *)dictionary NS_DESIGNATED_INITIALIZER;

/**
 根据JSONData对象自动生成对应的Model。
 @param data Model的数据源，JSON格式二进制数据
 @return Model对象
 */
- (nullable id)initWithData:(nonnull NSData *)data NS_DESIGNATED_INITIALIZER;

/**
 根据JSONString对象自动生成对应的Model。
 @param dictionary Model的数据源，JSON格式字符串
 @return Model对象
 */
- (nullable id)initWithJSONString:(nonnull NSString *)json NS_DESIGNATED_INITIALIZER;

/**
 重写customKeyMapper函数可自定义关键字映射，对应方式为:
 
 <originalKey : destinationKey>

 只需要传入需要映射的关键字即可.
 @return 自定义映射表，默认为空字典
 */
- (nonnull NSDictionary<NSString *, NSString *> *)customKeyMapper;

/**
 重写ignoreNullClass函数可决定Model在转译成Container时，是否自动忽略值为null的属性。
 @return 默认为YES
 */
- (BOOL)ignoreNullClass;

@end

/**
 BaseModel的快速转译扩展，可快速将Container转译成Model
 */
@interface BaseModel (ModelTranslation)

/**
 快速将数组中所有的Container转译成一个Model数组
 @param array 数组中存放对象必须是JSON类型的容器
 @return 含Model对象的数组
 */
+ (nullable NSMutableArray<BaseModel *> *)translateToModelFromDictionaries:(nonnull NSArray *)array;

/// @deprecated 使用 translateToModelFromDictionaries: 代替
+ (nullable NSMutableArray<BaseModel *> *)arrayOfModelsFromDictionaries:(nonnull NSArray *)array DEPRECATED_MSG_ATTRIBUTE("use translateToModelFromDictionaries: instead");

@end

/**
 BaseModel的快速转译扩展，可快速将Model转译成Container
 */
@interface BaseModel (ContainerTranslation)

/// 快速将Model转成Container，Container只包含设置property的字段，不包含originalDictionary中的所有字段
@property (nonatomic, readonly, nonnull) NSDictionary *toDictionary;

/// 快速将Model转成JSONString，JSONString只包含设置property的字段，不包含originalDictionary中的所有字段
@property (nonatomic, readonly, nonnull) NSString *JSONString;

/**
 快速将数组中所有Model转译成一个包涵的Container数组
 @param array 数组中存放对象必须是Model类型
 @return 含JSON类型容器的数组
 */
+ (nullable NSMutableArray *)translateToDictionaryFromModels:(nullable NSArray<BaseModel *> *)array;

@end
