//
//  QCCodingUtilities.m
//  QCCore
//
//  Created by XuQian on 12/15/15.
//  Copyright © 2015 qcwl. All rights reserved.
//

#import "QCCodingUtilities.h"
#import <CommonCrypto/CommonDigest.h>
#import <zlib.h>

NSString *QCPercentEscapesEncoding(NSString *string)
{
    if (!string) return @"";
    
    CFStringRef encodedCFString = CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                          (__bridge CFStringRef) string,
                                                                          nil,
                                                                          CFSTR("?!@#$^&%*+,:;='\"`<>()[]{}/\\| "),
                                                                          kCFStringEncodingUTF8);
    
    NSString *encodedString = [[NSString alloc] initWithString:(__bridge_transfer NSString*) encodedCFString];
    
    if(!encodedString)
        encodedString = @"";
    
    return encodedString;
}

NSString *QCPercentEscapesDecoding(NSString *string)
{
    if (!string) return @"";
    
    CFStringRef decodedCFString = CFURLCreateStringByReplacingPercentEscapesUsingEncoding(kCFAllocatorDefault,
                                                                                          (__bridge CFStringRef) string,
                                                                                          CFSTR(""),
                                                                                          kCFStringEncodingUTF8);
    
    NSString *decodedString = [[NSString alloc] initWithString:(__bridge_transfer NSString*) decodedCFString];
    return (!decodedString) ? @"" : decodedString;
}

NSString *QCMd5Encoding(NSString *string)
{
    const char *cStr = [string UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5( cStr, (unsigned int)strlen(cStr), digest );
    
    NSMutableString *output = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02X", digest[i]];
    
    return output;
}

NSString * QCSHA1Encode(NSString *string)
{
    const char *cstr = [string cStringUsingEncoding:NSUTF8StringEncoding];
    NSData *data = [NSData dataWithBytes:cstr length:string.length];
    
    uint8_t digest[CC_SHA1_DIGEST_LENGTH];
    
    CC_SHA1(data.bytes, (unsigned int)data.length, digest);
    
    NSMutableString* output = [NSMutableString stringWithCapacity:CC_SHA1_DIGEST_LENGTH * 2];
    
    for(int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++)
        [output appendFormat:@"%02x", digest[i]];
    
    return output;
}

#define DefaultCompressBufferSize 16384

static inline z_stream NewStream()
{
    struct internal_state state = {0};
    z_stream stream = {0,0,0,0,0,0,NULL,&state,Z_NULL,Z_NULL,Z_NULL,0,0};
    return stream;
}

NSData * CompressData(NSData *data)
{
    if (!data || data.length == 0) return nil;
    
    NSMutableData *_compressData = [NSMutableData dataWithLength:DefaultCompressBufferSize];
    
    @synchronized (_compressData) {
        z_stream stream = NewStream();
        stream.next_in = (Bytef *)[data bytes];
        stream.avail_in = (uInt)[data length];
        
        int status = deflateInit2(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, 15+16, 8, Z_DEFAULT_STRATEGY);
        if (status != Z_OK) return nil;
        
        do {
            if (stream.total_out >= _compressData.length) {
                [_compressData increaseLengthBy:DefaultCompressBufferSize];
            }
            
            stream.next_out = [_compressData mutableBytes] + stream.total_out;
            stream.avail_out = (uInt)([_compressData length] - stream.total_out);
            
            status = deflate(&stream, Z_FINISH);
        }while (stream.avail_out == 0);
        
        deflateEnd(&stream);
        
        [_compressData setLength:stream.total_out];
    }
    
    return _compressData?[NSData dataWithData:_compressData]:nil;
}

NSData * UncompressData(NSData *data)
{
    if (!data || data.length == 0) return nil;
    
    NSMutableData *_uncompressData = [NSMutableData dataWithLength:DefaultCompressBufferSize];
    
    @synchronized (_uncompressData) {
        z_stream stream = NewStream();
        stream.next_in = (Bytef *)[data bytes];
        stream.avail_in = (uInt)[data length];
        
        int status = inflateInit2(&stream, 15+32);
        if (status != Z_OK) return nil;
        
        while (status != Z_STREAM_END) {
            
            if (stream.total_out >= _uncompressData.length) {
                [_uncompressData increaseLengthBy:DefaultCompressBufferSize];
            }
            
            stream.next_out = [_uncompressData mutableBytes] + stream.total_out;
            stream.avail_out = (uInt)([_uncompressData length] - stream.total_out);
            status = inflate(&stream, Z_SYNC_FLUSH);
            
            if (status == Z_STREAM_END) {
                break;
            }else if (status != Z_OK) {
                return nil;
            }
        }
        
        if (inflateEnd(&stream) != Z_OK) return nil;
        
        [_uncompressData setLength:stream.total_out];
    }
    
    return _uncompressData?[NSData dataWithData:_uncompressData]:nil;
}
