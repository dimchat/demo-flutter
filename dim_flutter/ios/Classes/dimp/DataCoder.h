//
//  DataCoder.h
//  Sechat
//
//  Created by Albert Moky on 2025/4/24.
//

#import <Foundation/Foundation.h>

@interface UTF8Coder : NSObject

+ (NSData *_Nonnull)encode:(NSString *_Nonnull)string;
+ (nullable NSString *)decode:(NSData *_Nonnull)utf8;

@end

#define MKMUTF8Encode(string) [UTF8Coder encode:(string)]
#define MKMUTF8Decode(data)   [UTF8Coder decode:(data)]

@interface HexCoder : NSObject

+ (NSString *_Nonnull)encode:(NSData *_Nonnull)data;
+ (nullable NSData *)decode:(NSString *_Nonnull)string;

@end

@interface Base64Coder : NSObject

+ (NSString *_Nonnull)encode:(NSData *_Nonnull)data;
+ (nullable NSData *)decode:(NSString *_Nonnull)string;

@end

#define MKMHexEncode(data)      [HexCoder encode:(data)]
#define MKMHexDecode(string)    [HexCoder decode:(string)]

#define MKMBase64Encode(data)   [Base64Coder encode:(data)]
#define MKMBase64Decode(string) [Base64Coder decode:(string)]
