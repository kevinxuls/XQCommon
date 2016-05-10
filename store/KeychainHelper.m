//
//  KeychainHelper.m
//  QCCore
//
//  Created by XuQian on 3/16/16.
//  Copyright © 2016 qcwl. All rights reserved.
//

#import "KeychainHelper.h"
#import <Security/Security.h>

NSData * ReadKeychainData(NSString *identifier, NSString *service)
{
    if (!identifier) return nil;
    if (!service) return nil;
    
    NSDictionary *query = @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService: service,
                            (__bridge id)kSecAttrAccount: identifier,
                            (__bridge id)kSecReturnData: @YES};
    CFTypeRef dataTypeRef = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &dataTypeRef);
    if (status == errSecSuccess) {
        return (__bridge_transfer NSData *)dataTypeRef;
    }else {
        CoreLog(@"read keychain failed with identifier: %@, service: %@", identifier, service);
        return nil;
    }
}

NSString * ReadKeychainString(NSString *identifier, NSString *service)
{
    NSData *resultData = ReadKeychainData(identifier, service);
    return resultData?[[NSString alloc] initWithData:resultData encoding:NSUTF8StringEncoding]:nil;
}

id ReadKeychainContainer(NSString *identifier, NSString *service)
{
    NSData *resultData = ReadKeychainData(identifier, service);
    if (resultData) {
        NSError *error;
        NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
        NSDictionary *info = [NSPropertyListSerialization propertyListWithData:resultData options:NSPropertyListImmutable format:&format error:&error];
        if (!error) {
            return info;
        }
        CoreLog(@"keychain value with identifier: %@, service: %@ got an error: %@", identifier, service, error);
    }
    return nil;
}

OSStatus UpdateKeychainData(NSData *value, NSString *identifier, NSString *service)
{
    if (!value) return errSecParam;
    if (!identifier) return errSecParam;
    if (!service) return errSecParam;
    
    NSDictionary *query = @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService: service,
                            (__bridge id)kSecAttrAccount: identifier};
    
    NSDictionary *changes = @{(__bridge id)kSecValueData: value};
    
    if (ReadKeychainData(identifier, service)) {
        return SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)changes);
    }else {
        NSMutableDictionary *info = [NSMutableDictionary dictionaryWithDictionary:query];
        [info setObject:value forKey:(__bridge id)kSecValueData];
        return SecItemAdd((__bridge CFDictionaryRef)info, NULL);
    }
}

OSStatus UpdateKeychainString(NSString *value, NSString *identifier, NSString *service)
{
    NSData *data = [value dataUsingEncoding:NSUTF8StringEncoding];
    
    return UpdateKeychainData(data, identifier, service);
}

OSStatus UpdateKeychainContainer(id value, NSString *identifier, NSString *service)
{
    NSError *plistError;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:value format:NSPropertyListBinaryFormat_v1_0 options:NSPropertyListImmutable error:&plistError];
    if (plistError || !data) {
        CoreLog(@"can't create plist data");
        return errSecParam;
    }
    
    return UpdateKeychainData(data, identifier, service);
}

OSStatus DeleteKeychainValue(NSString *identifier, NSString *service)
{
    NSDictionary *query = @{(__bridge id)kSecClass:(__bridge id)kSecClassGenericPassword,
                            (__bridge id)kSecAttrService: service,
                            (__bridge id)kSecAttrAccount: identifier};
    return SecItemDelete((__bridge CFDictionaryRef)query);
}
