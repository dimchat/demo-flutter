// license: https://mit-license.org
//
//  Ming-Ke-Ming : Decentralized User Identity Authentication
//
//                               Written in 2020 by Moky <albert.moky@gmail.com>
//
// =============================================================================
// The MIT License (MIT)
//
// Copyright (c) 2020 Albert Moky
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
// =============================================================================
//
//  MKMSecKeyHelper.m
//  DIMPlugins
//
//  Created by Albert Moky on 2020/12/15.
//  Copyright © 2020 Albert Moky. All rights reserved.
//

#import "DataCoder.h"

#import "SecKey.h"

static inline NSString *KeyContentFromPEM(NSString *content,
                                          NSString *algorithm,
                                          NSString *tag) {
    NSString *sTag, *eTag;
    NSRange spos, epos;
    NSString *key = content;
    
    sTag = [NSString stringWithFormat:@"-----BEGIN %@ %@ KEY-----", algorithm, tag];
    eTag = [NSString stringWithFormat:@"-----END %@ %@ KEY-----", algorithm, tag];
    spos = [key rangeOfString:sTag];
    if (spos.length > 0) {
        epos = [key rangeOfString:eTag];
    } else {
        sTag = [NSString stringWithFormat:@"-----BEGIN %@ KEY-----", tag];
        eTag = [NSString stringWithFormat:@"-----END %@ KEY-----", tag];
        spos = [key rangeOfString:sTag];
        epos = [key rangeOfString:eTag];
    }
    
    if (spos.location != NSNotFound && epos.location != NSNotFound) {
        NSUInteger s = spos.location + spos.length;
        NSUInteger e = epos.location;
        NSRange range = NSMakeRange(s, e - s);
        key = [key substringWithRange:range];
    }
    
    key = [key stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    key = [key stringByReplacingOccurrencesOfString:@" "  withString:@""];
    
    return key;
}

static inline SecKeyRef SecKeyRefFromData(NSData *data,
                                          NSString *keyType,
                                          NSString *keyClass) {
    // Set the private key query dictionary.
    NSDictionary * dict;
    dict = @{(id)kSecAttrKeyType :keyType,
             (id)kSecAttrKeyClass:keyClass,
             };
    CFErrorRef error = NULL;
    SecKeyRef keyRef = SecKeyCreateWithData((CFDataRef)data,
                                            (CFDictionaryRef)dict,
                                            &error);
    if (error) {
        NSLog(@"failed to create sec key with data: %@, error: %@", data, error);
        assert(keyRef == NULL); // the key ref should be empty when error
        assert(false);
        CFRelease(error);
        error = NULL;
    }
    return keyRef;
}

NSData *NSDataFromSecKeyRef(SecKeyRef keyRef) {
    CFErrorRef error = NULL;
    CFDataRef dataRef = SecKeyCopyExternalRepresentation(keyRef, &error);
    if (error) {
        NSLog(@"RSA failed to copy data with sec key: %@", keyRef);
        assert(dataRef == NULL); // the data ref should be empty when error
        assert(false);
        CFRelease(error);
        error = NULL;
    }
    return (__bridge_transfer NSData *)dataRef;
}

NSString *NSStringFromKeyContent(NSString *content, NSString *tag) {
    NSString *sTag, *eTag;
    sTag = [NSString stringWithFormat:@"-----BEGIN %@ KEY-----\n", tag];
    eTag = [NSString stringWithFormat:@"-----END %@ KEY-----", tag];
    
    NSMutableString *mString = [[NSMutableString alloc] init];
    [mString appendString:sTag];
    NSUInteger pos1, pos2, len = content.length;
    NSString *substr;
    for (pos1 = 0, pos2 = 64; pos1 < len; pos1 = pos2, pos2 += 64) {
        if (pos2 > len) {
            pos2 = len;
        }
        substr = [content substringWithRange:NSMakeRange(pos1, pos2 - pos1)];
        [mString appendString:substr];
        [mString appendString:@"\n"];
    }
    [mString appendString:eTag];
    return mString;
}

@implementation MKMSecKeyHelper

+ (NSData *)publicKeyDataFromContent:(NSString *)pem algorithm:(NSString *)name {
    if ([name isEqualToString:MKMAlgorithm_ECC]) {
        name = @"EC";
    }
    NSString *base64 = KeyContentFromPEM(pem, name, @"PUBLIC");
    return MKMBase64Decode(base64);
}

+ (SecKeyRef)publicKeyFromData:(NSData *)data algorithm:(NSString *)name {
    if ([name isEqualToString:MKMAlgorithm_ECC]) {
        name = @"EC";
    }
    if ([name isEqualToString:MKMAlgorithm_RSA]) {
        return SecKeyRefFromData(data, (__bridge id)kSecAttrKeyTypeRSA, (__bridge id)kSecAttrKeyClassPublic);
    } else if ([name isEqualToString:@"EC"]) {
        return SecKeyRefFromData(data, (__bridge id)kSecAttrKeyTypeECSECPrimeRandom, (__bridge id)kSecAttrKeyClassPublic);
    }
    NSAssert(false, @"unknown algorithm: %@", name);
    return nil;
}

+ (NSData *)privateKeyDataFromContent:(NSString *)pem algorithm:(NSString *)name {
    if ([name isEqualToString:MKMAlgorithm_ECC]) {
        name = @"EC";
    }
    NSString *base64 = KeyContentFromPEM(pem, name, @"PRIVATE");
    return MKMBase64Decode(base64);
}

+ (SecKeyRef)privateKeyFromData:(NSData *)data algorithm:(NSString *)name {
    if ([name isEqualToString:MKMAlgorithm_ECC]) {
        name = @"EC";
    }
    if ([name isEqualToString:MKMAlgorithm_RSA]) {
        return SecKeyRefFromData(data, (__bridge id)kSecAttrKeyTypeRSA, (__bridge id)kSecAttrKeyClassPrivate);
    } else if ([name isEqualToString:@"EC"]) {
        return SecKeyRefFromData(data, (__bridge id)kSecAttrKeyTypeECSECPrimeRandom, (__bridge id)kSecAttrKeyClassPrivate);
    }
    NSAssert(false, @"unknown algorithm: %@", name);
    return nil;
}

+ (NSData *)dataFromKey:(SecKeyRef)key {
    return NSDataFromSecKeyRef(key);
}

+ (NSString *)serializePublicKey:(SecKeyRef)pKey algorithm:(NSString *)name {
    if ([name isEqualToString:MKMAlgorithm_ECC]) {
        name = @"EC";
    }
    NSString *tag = [NSString stringWithFormat:@"%@ PUBLIC", name];
    NSData *data = NSDataFromSecKeyRef(pKey);  // kSecAttrKeyTypeRSA PKCS#1 format
    NSString *base64 = MKMBase64Encode(data);
    return NSStringFromKeyContent(base64, tag);
}

+ (NSString *)serializePrivateKey:(SecKeyRef)sKey algorithm:(NSString *)name {
    if ([name isEqualToString:MKMAlgorithm_ECC]) {
        name = @"EC";
    }
    NSString *tag = [NSString stringWithFormat:@"%@ PRIVATE", name];
    NSData *data = NSDataFromSecKeyRef(sKey);
    NSString *base64 = MKMBase64Encode(data);
    return NSStringFromKeyContent(base64, tag);
}

@end
