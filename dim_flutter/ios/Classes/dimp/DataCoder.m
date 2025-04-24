//
//  DataCoder.m
//  Sechat
//
//  Created by Albert Moky on 2025/4/24.
//

#import "DataCoder.h"

@implementation UTF8Coder

+ (NSData *_Nonnull)encode:(NSString *_Nonnull)string {
    return [string dataUsingEncoding:NSUTF8StringEncoding];
}

+ (nullable NSString *)decode:(NSData *_Nonnull)data {
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    // rtrim '\0'
    NSInteger pos = data.length - 1;
    for (; pos >= 0; --pos) {
        if (bytes[pos] != 0) {
            break;
        }
    }
    NSUInteger length = pos + 1;
    return [[NSString alloc] initWithBytes:bytes length:length encoding:NSUTF8StringEncoding];
}

@end

#pragma mark - HEX

@implementation HexCoder

static inline char hex_char(char ch) {
    if (ch >= '0' && ch <= '9') {
        return ch - '0';
    }
    if (ch >= 'a' && ch <= 'f') {
        return ch - 'a' + 10;
    }
    if (ch >= 'A' && ch <= 'F') {
        return ch - 'A' + 10;
    }
    return 0;
}

+ (NSString *_Nonnull)encode:(NSData *_Nonnull)data {
    NSMutableString *output = nil;
    
    const unsigned char *bytes = (const unsigned char *)[data bytes];
    NSUInteger len = [data length];
    output = [[NSMutableString alloc] initWithCapacity:(len*2)];
    for (int i = 0; i < len; ++i) {
        [output appendFormat:@"%02x", bytes[i]];
    }
    
    return output;
}

+ (nullable NSData *)decode:(NSString *_Nonnull)string {
    NSMutableData *output = nil;
    
    NSString *str = string;
    // 1. remove ' ', ':', '-', '\n'
    str = [str stringByReplacingOccurrencesOfString:@" " withString:@""];
    str = [str stringByReplacingOccurrencesOfString:@":" withString:@""];
    str = [str stringByReplacingOccurrencesOfString:@"-" withString:@""];
    str = [str stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    
    // 2. skip '0x' prefix
    char ch0, ch1;
    NSUInteger pos = 0;
    NSUInteger len = [string length];
    if (len > 2) {
        ch0 = [str characterAtIndex:0];
        ch1 = [str characterAtIndex:1];
        if (ch0 == '0' && (ch1 == 'x' || ch1 == 'X')) {
            pos = 2;
        }
    }
    
    // 3. decode bytes
    output = [[NSMutableData alloc] initWithCapacity:(len/2)];
    unsigned char byte;
    for (; (pos + 1) < len; pos += 2) {
        ch0 = [str characterAtIndex:pos];
        ch1 = [str characterAtIndex:(pos + 1)];
        byte = hex_char(ch0) * 16 + hex_char(ch1);
        [output appendBytes:&byte length:1];
    }
    
    return output;
}

@end

#pragma mark - BASE-64

@implementation Base64Coder

+ (NSString *_Nonnull)encode:(NSData *_Nonnull)data {
    NSDataBase64EncodingOptions opt;
    opt = NSDataBase64EncodingEndLineWithCarriageReturn;
    return [data base64EncodedStringWithOptions:opt];
}

+ (nullable NSData *)decode:(NSString *_Nonnull)string {
    NSDataBase64DecodingOptions opt;
    opt = NSDataBase64DecodingIgnoreUnknownCharacters;
    return [[NSData alloc] initWithBase64EncodedString:string options:opt];
}

@end
