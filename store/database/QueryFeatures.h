//
//  QueryPredicate.h
//  QCCore
//
//  Created by XuQian on 4/18/16.
//  Copyright © 2016 qcwl. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface QueryPredicate : NSObject

@property (nonnull, nonatomic, readonly) NSString *expression;
@property (nonnull, nonatomic, readonly) NSString *attributeA;
@property (nonnull, nonatomic, readonly) NSString *attributeB;
@property (nonatomic, readonly) NSPredicateOperatorType opt;

@end

FOUNDATION_EXTERN QueryPredicate * _Nonnull QueryPredicateMake(NSString * _Nullable attrA, NSPredicateOperatorType opt, NSString * _Nullable attrB);

@interface QuerySort : NSObject

@property (nonnull, nonatomic, readonly) NSString *expression;
@property (nonnull, nonatomic, readonly) NSString *attribute;
@property (nonatomic, readonly) NSComparisonResult order;

@end

FOUNDATION_EXTERN QuerySort * _Nonnull QuerySortMake(NSString * _Nonnull attribute, NSComparisonResult order);
