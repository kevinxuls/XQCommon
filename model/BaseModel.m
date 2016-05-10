//
//  BaseModel.m
//  QCCore
//
//  Created by XuQian on 2/3/16.
//  Copyright © 2016 qcwl. All rights reserved.
//

#import "BaseModel.h"
#import <objc/runtime.h>
#import "ModelProperty.h"

@interface NSArray (Model)

@end

@interface NSDictionary (Model)

@end

typedef NSString* (^JSONStringToModelStringMapperBlock)(NSString* keyName);
static JSONStringToModelStringMapperBlock toModelBlock = nil;

typedef NSString* (^ModelStringToJSONStringMapperBlock)(NSString* keyName);
static ModelStringToJSONStringMapperBlock toJSONBlock = nil;

static const char * kClassPropertiesKey;

@implementation BaseModel
{
    NSMutableDictionary *_dic;
    NSString *_description;
}

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        toModelBlock = ^ NSString* (NSString* keyName) {
            if ([keyName rangeOfString:@"_"].location==NSNotFound) return keyName;
            NSString* camelCase = [keyName capitalizedString];
            camelCase = [camelCase stringByReplacingOccurrencesOfString:@"_" withString:@""];
            camelCase = [camelCase stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:[[camelCase substringToIndex:1] lowercaseString] ];
            return camelCase;
        };
        
        toJSONBlock = ^ NSString* (NSString* keyName) {
            
            NSMutableString* result = [NSMutableString stringWithString:keyName];
            NSRange upperCharRange = [result rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]];
            
            while ( upperCharRange.location!=NSNotFound) {
                
                NSString* lowerChar = [[result substringWithRange:upperCharRange] lowercaseString];
                [result replaceCharactersInRange:upperCharRange
                                      withString:[NSString stringWithFormat:@"_%@", lowerChar]];
                upperCharRange = [result rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]];
            }
            
            NSRange digitsRange = [result rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]];
            while ( digitsRange.location!=NSNotFound) {
                
                NSRange digitsRangeEnd = [result rangeOfString:@"\\D" options:NSRegularExpressionSearch range:NSMakeRange(digitsRange.location, result.length-digitsRange.location)];
                if (digitsRangeEnd.location == NSNotFound) {
                    digitsRangeEnd = NSMakeRange(result.length, 1);
                }
                
                NSRange replaceRange = NSMakeRange(digitsRange.location, digitsRangeEnd.location - digitsRange.location);
                NSString* digits = [result substringWithRange:replaceRange];
                
                [result replaceCharactersInRange:replaceRange withString:[NSString stringWithFormat:@"_%@", digits]];
                digitsRange = [result rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet] options:kNilOptions range:NSMakeRange(digitsRangeEnd.location+1, result.length-digitsRangeEnd.location-1)];
            }
            
            return result;
        };
    });
}

- (id)initWithDictionary:(NSDictionary *)dictionary
{
    if (!dictionary) return nil;
    if ([dictionary isKindOfClass:[BaseModel class]]) return (BaseModel *)dictionary;
    if (![dictionary isKindOfClass:[NSDictionary class]]) return nil;
    if (self = [super init]) {
        
        [self setupAllProperties];
        
        _dic = [NSMutableDictionary dictionaryWithDictionary:dictionary];
        
        if (![self mapperAllKeys]) return nil;
    }
    return self;
}

- (id)initWithData:(NSData *)data
{
    if (self = [super init]) {
        [self setupAllProperties];
        
        _dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        if (!_dic || ![_dic isKindOfClass:[NSMutableDictionary class]]) return nil;
        
        if (![self mapperAllKeys]) return nil;
    }
    return self;
}

- (id)initWithJSONString:(NSString *)json
{
    if (self = [super init]) {
        [self setupAllProperties];
        
        _dic = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
        if (!_dic || ![_dic isKindOfClass:[NSMutableDictionary class]]) return nil;
        
        if (![self mapperAllKeys]) return nil;
    }
    return self;
}

- (id)init
{
    return [self initWithDictionary:@{}];
}

-(NSArray*)properties
{
    NSArray* classProperties = objc_getAssociatedObject(self.class, &kClassPropertiesKey);
    if (classProperties) return classProperties;
    
    [self setupAllProperties];
    
    classProperties = objc_getAssociatedObject(self.class, &kClassPropertiesKey);
    return classProperties;
}

- (void)setupAllProperties
{
    NSMutableArray *propertyIndex = [NSMutableArray array];
    Class class = [self class];
    while (class != [BaseModel class]) {
        unsigned int propertyCount;
        objc_property_t *properties = class_copyPropertyList(class, &propertyCount);
        
        for (unsigned int i = 0; i < propertyCount; i++) {
            objc_property_t property = properties[i];
            ModelProperty *mp = [[ModelProperty alloc] initWithProperty:property];
            if (mp) {
                [propertyIndex addObject:mp];
            }
        }
        free(properties);
        class = [class superclass];
    }
    
    objc_setAssociatedObject(self.class,
                             &kClassPropertiesKey,
                             [propertyIndex copy],
                             OBJC_ASSOCIATION_RETAIN
                             );
}

- (BOOL)mapperAllKeys
{
    if (!_dic || ![_dic isKindOfClass:[NSDictionary class]]) return NO;
    
    NSArray *properties = [self properties];
    
    for (ModelProperty *mp in properties) {
        
        NSString *key = [self filterCustomKeyMapper:toJSONBlock(mp.name)];
        id value = _dic[key];
        
        id translatedValue = nil;
        if ([mp.type isSubclassOfClass:[BaseModel class]]) {
            translatedValue = [(BaseModel *)[mp.type alloc] initWithDictionary:value];
        }else if (mp.protocol && [NSClassFromString(mp.protocol) isSubclassOfClass:[BaseModel class]]) {
            translatedValue = [self excuteProtocolWithProperty:mp value:value];
        }else {
            translatedValue = [self translateValue:value property:mp];
        }
        if (translatedValue && [self respondsToSelector:NSSelectorFromString(mp.name)]) {
            [self setValue:translatedValue forKey:mp.name];
        }        
    }
    return YES;
}

- (id)translateValue:(id)value property:(ModelProperty *)property
{
    if (property.primitive) {
        if ([ModelProperty validPrimitivesValue:property.primitive]) {
            return value;
        }
    }else {
        if (property.type == [NSString class] && [value isKindOfClass:[NSNumber class]]) {
            return [value description];
        }else if (property.type == [NSNumber class] && [value isKindOfClass:[NSString class]]) {
            return value;
        }else if ([value isKindOfClass:property.type]) {
            return value;
        }
    }
    return nil;
}

- (id)excuteProtocolWithProperty:(ModelProperty *)property value:(id)value
{
    Class protocolClass = NSClassFromString(property.protocol);
    
    if ([property.type isSubclassOfClass:[NSArray class]]) {
        return [[protocolClass class] translateToModelFromDictionaries:value];
    }else if ([property.type isSubclassOfClass:[NSDictionary class]]) {
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        id object = [[protocolClass alloc] initWithDictionary:value];
        [dic setValue:object forKey:property.name];
        return dic;
    }else if ([property.type isSubclassOfClass:[BaseModel class]]) {
        return value;
    }
    return nil;
}

- (NSString *)description
{
    NSMutableString* text = [NSMutableString stringWithFormat:@"<%@>\n", [self class]];
    
    for (ModelProperty *p in [self properties]) {
        id value = ([p.name isEqualToString:@"description"])?self->_description:[self valueForKey:p.name];
        NSString* valueDescription;
        if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
            valueDescription = (value)?[value descriptionWithLocale:[NSLocale currentLocale]]:@"<nil>";
        }else {
            valueDescription = (value)?[value description]:@"<nil>";
        }
        valueDescription = [valueDescription stringByReplacingOccurrencesOfString:@"\n" withString:@"\n    "];
        [text appendFormat:@"    [%@]: %@\n", p.name, valueDescription];
    }
    
    [text appendFormat:@"</%@>", [self class]];
    return text;
}

- (NSDictionary *)originalDictionary
{
    return _dic;
}

- (NSDictionary *)customKeyMapper
{
    return @{};
}

- (NSString *)filterCustomKeyMapper:(NSString *)key
{
    if ([self customKeyMapper].count > 0) {
        for (NSString *_key in [self customKeyMapper].allKeys) {
            if ([_key isEqualToString:key]) {
                return [self customKeyMapper][key];
            }
        }
    }
    return key;
}

- (BOOL)ignoreNullClass
{
    return YES;
}

#pragma mark - copying & coding

-(id)copyWithZone:(NSZone *)zone
{
    return [NSKeyedUnarchiver unarchiveObjectWithData:
            [NSKeyedArchiver archivedDataWithRootObject:self]
            ];
}

-(id)initWithCoder:(NSCoder *)decoder
{
    return [self initWithJSONString:[decoder decodeObjectForKey:@"json"]];
}

-(void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.JSONString forKey:@"json"];
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

@end

@implementation BaseModel (ModelTranslation)

+ (NSMutableArray<BaseModel *> *)translateToModelFromDictionaries:(NSArray *)array
{
    if (!array || ![array isKindOfClass:[NSArray class]]) return nil;
    
    NSMutableArray* list = [NSMutableArray arrayWithCapacity:[array count]];
    for (int i=0; i<array.count; i++) {
        id d = array[i];
        if ([d isKindOfClass:NSDictionary.class]) {
            id obj = [[self alloc] initWithDictionary:d];
            if (obj == nil) return nil;
            [list addObject:obj];
        }else if ([d isKindOfClass:NSArray.class]) {
            [list addObjectsFromArray:[self.class translateToModelFromDictionaries:d]];
        }else if ([d isKindOfClass:[BaseModel class]]) {
            [list addObject:d];
        }
    }
    return list;
}

+ (NSMutableArray *)arrayOfModelsFromDictionaries:(NSArray *)array
{
    return [self.class translateToModelFromDictionaries:array];
}

@end

@implementation BaseModel (ContainerTranslation)

- (NSDictionary *)toDictionary
{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    for (ModelProperty *property in [self properties]) {
        NSString *key = [self filterCustomKeyMapper:toJSONBlock(property.name)];
        id value = [self valueForKey:property.name];
        if (value) {
            if ([value isKindOfClass:[BaseModel class]]) {
                [dic setObject:[value toDictionary] forKey:key];
            }else if ([value isKindOfClass:[NSArray class]] || [value isKindOfClass:[NSDictionary class]]) {
                [dic setObject:[BaseModel translateModelObject:value] forKey:key];
            }else {
                [dic setObject:value forKey:key];
            }
        }else {
            if (![self ignoreNullClass]) {
                [dic setObject:[NSNull null] forKey:key];
            }
        }
    }
    return dic;
}

+ (id)translateModelObject:(id)object
{
    if ([object isKindOfClass:[NSArray class]]) {
        NSMutableArray *array = [NSMutableArray array];
        for (int i=0; i<[object count]; i++) {
            if ([object[i] isKindOfClass:[BaseModel class]]) {
                [array addObject:[object[i] toDictionary]];
            }else if ([object[i] isKindOfClass:[NSArray class]] || [object[i] isKindOfClass:[NSDictionary class]]){
                [array addObject:[BaseModel translateModelObject:object[i]]];
            }
        }
        return array;
    }else if ([object isKindOfClass:[NSDictionary class]]) {
        for (NSString *key in [object allKeys]) {
            if ([object[key] isKindOfClass:[BaseModel class]]) {
                return [object[key] toDictionary];
            }else if ([object[key] isKindOfClass:[NSArray class]] || [object[key] isKindOfClass:[NSDictionary class]]){
                return [BaseModel translateModelObject:object[key]];
            }
        }
    }
    return object;
}

- (NSString *)JSONString
{
    if (![self ignoreNullClass]) return @"";
    NSData *data = [NSJSONSerialization dataWithJSONObject:[self toDictionary] options:0 error:nil];
    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return str ?: @"";
}

+ (NSMutableArray *)translateToDictionaryFromModels:(NSArray<BaseModel *> *)array
{
    if (!array || ![array isKindOfClass:[NSArray class]]) return nil;
    
    NSMutableArray *list = [NSMutableArray arrayWithCapacity:[array count]];
    for (int i=0; i<array.count; i++) {
        BaseModel *object = array[i];
        if (![object isKindOfClass:[BaseModel class]]) return nil;
        
        NSDictionary *obj = [object toDictionary];
        if (!obj) return nil;
        
        [list addObject:obj];
    }
    return list;
}

@end

@implementation NSArray (Model)

- (NSString *)descriptionWithLocale:(id)locale
{
    NSMutableString *str = [NSMutableString stringWithString:@"(\n"];
    for (int i=0; i<self.count; i++) {
        [str appendFormat:@"%@,\n", self[i]];
    }
    [str replaceCharactersInRange:NSMakeRange(str.length-2, 2) withString:@"\n)"];
    return [str stringByReplacingOccurrencesOfString:@"\n" withString:@"\n    "];
}

@end

@implementation NSDictionary (Model)

- (NSString *)descriptionWithLocale:(id)locale
{
    NSMutableString *str = [NSMutableString stringWithString:@"{\n"];
    for (NSString *key in self.allKeys) {
        [str appendFormat:@"[%@]: %@,\n", key, self[key]];
    }
    [str replaceCharactersInRange:NSMakeRange(str.length-2, 2) withString:@"\n}"];
    return [str stringByReplacingOccurrencesOfString:@"\n" withString:@"\n    "];
}

@end
