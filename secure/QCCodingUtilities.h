//
//  QCCodingUtilities.h
//  QCCore
//
//  Created by XuQian on 12/15/15.
//  Copyright © 2015 qcwl. All rights reserved.
//

#import <Foundation/Foundation.h>

FOUNDATION_EXPORT NSString *QCPercentEscapesEncoding(NSString *string);

FOUNDATION_EXPORT NSString *QCPercentEscapesDecoding(NSString *string);

FOUNDATION_EXPORT NSString *QCMd5Encoding(NSString *string);

FOUNDATION_EXPORT NSString * QCSHA1Encode(NSString *string);

FOUNDATION_EXTERN NSData * CompressData(NSData *data);

FOUNDATION_EXTERN NSData * UncompressData(NSData *data);
