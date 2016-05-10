//
//  QueryPredicate.m
//  QCCore
//
//  Created by XuQian on 4/18/16.
//  Copyright © 2016 qcwl. All rights reserved.
//

#import "QueryFeatures.h"

@implementation QueryPredicate
{
    @public
    NSString *_attrA;
    NSString *_attrB;
    NSPredicateOperatorType _opt;
}

- (NSString *)expression
{
    return [self description];
}

- (NSString *)attributeA
{
    return _attrA;
}

- (NSString *)attributeB
{
    return _attrB;
}

- (NSPredicateOperatorType)opt
{
    return _opt;
}

- (NSString *)description
{
    NSString *optString;
    switch (_opt) {
        case NSLessThanPredicateOperatorType: optString = @"<"; break;
        case NSLessThanOrEqualToPredicateOperatorType: optString = @"<="; break;
        case NSGreaterThanPredicateOperatorType: optString = @">"; break;
        case NSGreaterThanOrEqualToPredicateOperatorType: optString = @">="; break;
        case NSEqualToPredicateOperatorType: optString = @"="; break;
        case NSNotEqualToPredicateOperatorType: optString = @"<>"; break;
        case NSMatchesPredicateOperatorType: optString = @"MATCHES"; break;
        case NSLikePredicateOperatorType: optString = @"LIKE"; break;
        case NSBeginsWithPredicateOperatorType: optString = @"BEGINS"; break;
        case NSEndsWithPredicateOperatorType: optString = @"ENDS"; break;
        case NSInPredicateOperatorType: optString = @"IN"; break;
        case NSContainsPredicateOperatorType: optString = @"CONTAINS"; break;
        case NSBetweenPredicateOperatorType: optString = @"BETWEEN"; break;
        default: optString = @""; break;
    }
    return [NSString stringWithFormat:@"%@ %@ %@", _attrA, optString, _attrB];
}

@end

QueryPredicate * QueryPredicateMake(NSString *attrA, NSPredicateOperatorType opt, NSString *attrB)
{
    QueryPredicate *obj = [[QueryPredicate alloc] init];
    obj->_attrA = attrA;
    obj->_attrB = attrB;
    obj->_opt = opt;
    return obj;
}

@implementation QuerySort
{
    @public
    NSString *_attribute;
    NSComparisonResult _order;
}

- (NSString *)attribute
{
    return _attribute;
}

- (NSComparisonResult)order
{
    return _order;
}

- (NSString *)expression
{
    return [self description];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@%@", _attribute, _order==NSOrderedDescending?@" DESC":@""];
}

@end

QuerySort * QuerySortMake(NSString * attribute, NSComparisonResult order)
{
    QuerySort *sort = [[QuerySort alloc] init];
    sort->_attribute = attribute;
    sort->_order = order;
    return sort;
}

