//
//  KeychainHelper.h
//  QCCore
//
//  Created by XuQian on 3/16/16.
//  Copyright © 2016 qcwl. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSData * ReadKeychainData(NSString *identifier, NSString *service);
FOUNDATION_EXPORT NSString * ReadKeychainString(NSString *identifier, NSString *service);
FOUNDATION_EXPORT id ReadKeychainContainer(NSString *identifier, NSString *service);

FOUNDATION_EXPORT OSStatus UpdateKeychainData(NSData *value, NSString *identifier, NSString *service);
FOUNDATION_EXPORT OSStatus UpdateKeychainString(NSString *value, NSString *identifier, NSString *service);
FOUNDATION_EXPORT OSStatus UpdateKeychainContainer(id value, NSString *identifier, NSString *service);

FOUNDATION_EXPORT OSStatus DeleteKeychainValue(NSString *identifier, NSString *service);
