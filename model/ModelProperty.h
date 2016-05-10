//
//  ModelProperty.h
//  QCCore
//
//  Created by XuQian on 2/4/16.
//  Copyright © 2016 qcwl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

extern NSDictionary * const PrimitivesNames();
extern NSArray * const AllowedClasses();

@interface ModelProperty : NSObject

@property (nonatomic, assign) Class type;
@property (nonatomic, strong) NSString *primitive;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, assign) BOOL isMutable;
@property (nonatomic, strong) NSString *protocol;

- (id)initWithProperty:(objc_property_t)property;

+ (BOOL)validPrimitivesValue:(NSString *)type;

@end
