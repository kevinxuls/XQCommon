//
//  ModelProperty.m
//  QCCore
//
//  Created by XuQian on 2/4/16.
//  Copyright © 2016 qcwl. All rights reserved.
//

#import "ModelProperty.h"
#import "BaseModel.h"

static NSArray * __AllowedClasses;
static NSDictionary *__PrimitivesNames;

static inline BOOL isValid(Class type)
{
    for (Class class in AllowedClasses()) {
        if (type == class || [type isSubclassOfClass:[BaseModel class]]) {
            return YES;
        }
    }
    return NO;
}

NSDictionary * const PrimitivesNames()
{
    return __PrimitivesNames;
}

NSArray * const AllowedClasses()
{
    return __AllowedClasses;
}

@implementation ModelProperty

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        __PrimitivesNames = @{@"f":@"float",
                              @"i":@"int",
                              @"d":@"double",
                              @"l":@"long",
                              @"c":@"BOOL",
                              @"s":@"short",
                              @"q":@"long",
                              @"I":@"NSInteger",
                              @"Q":@"NSUInteger",
                              @"B":@"BOOL"};
        
        __AllowedClasses = @[[NSString class], [NSArray class], [NSDictionary class], [NSNumber class], [NSMutableArray class], [NSMutableDictionary class], [BaseModel class]];
        
    });
}

+ (BOOL)validPrimitivesValue:(NSString *)type
{
    if (PrimitivesNames()[type]) {
        return YES;
    }
    return NO;
}

- (id)initWithProperty:(objc_property_t)property
{
    self = [super init];
    if (!self) return nil;
    
    const char *propertyName = property_getName(property);
    _name = @(propertyName);
    
    const char *attributes = property_getAttributes(property);
    NSString *propertyAttributes = @(attributes);
    
    NSArray *array = [propertyAttributes componentsSeparatedByString:@","];
    if (array.count > 0) {
        
        NSString *type = array.firstObject;
        
        NSScanner *scanner = [NSScanner scannerWithString:type];
        [scanner scanUpToString:@"T" intoString: nil];
        [scanner scanString:@"T" intoString:nil];
        NSString *propertyType = nil;
        if ([scanner scanString:@"@\"" intoString: &propertyType]) {
            [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"\"<"]
                                    intoString:&propertyType];
            
            _type = NSClassFromString(propertyType);
            if (!isValid(_type)) return nil;
            _isMutable = ([propertyType rangeOfString:@"Mutable"].location != NSNotFound);
            
            while ([scanner scanString:@"<" intoString:NULL]) {
                
                NSString* protocolName = nil;
                
                [scanner scanUpToString:@">" intoString: &protocolName];
                
                _protocol = protocolName;
                
                [scanner scanString:@">" intoString:NULL];
            }
            
        }else {
            [scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@","]
                                    intoString:&propertyType];
            if (propertyType && PrimitivesNames()[propertyType]) {
                _primitive = propertyType;
            }else {
                return nil;
            }
        }
    }else {
        return nil;
    }
    return self;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@, %@, %@",self.name, self.type, self.protocol];
}

@end
