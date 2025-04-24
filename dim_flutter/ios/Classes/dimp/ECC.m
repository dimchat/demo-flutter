//
//  ECC.m
//  Sechat
//
//  Created by Albert Moky on 2025/4/24.
//

#import "DataCoder.h"

#import "SecKey.h"

#import "ECC.h"

extern NSString *NSStringFromKeyContent(NSString *content, NSString *tag);

@implementation ECCKeyStore

static NSString *s_application_tag = @"chat.dim.ecc.private";

+ (nullable NSDictionary *)loadKeyWithIdentifier:(NSString *)identifier {
    NSDictionary *keyInfo = nil;
    
    NSString *label = identifier;
    NSData *tag = MKMUTF8Encode(s_application_tag);
    
    NSDictionary *query = @{
        (id)kSecClass               :(id)kSecClassKey,
        (id)kSecAttrApplicationLabel:label,
        (id)kSecAttrApplicationTag  :tag,
        (id)kSecAttrKeyType         :(id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrKeyClass        :(id)kSecAttrKeyClassPrivate,
        (id)kSecAttrSynchronizable  :(id)kCFBooleanTrue,
              
        (id)kSecMatchLimit          :(id)kSecMatchLimitOne,
        (id)kSecReturnData          :(id)kCFBooleanTrue,

        // FIXME: 'Status = -25308'
        (id)kSecAttrAccessible      :(id)kSecAttrAccessibleWhenUnlocked,
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &result);
    if (status == errSecSuccess) { // noErr
        // private key
        NSData *privateKeyData = (__bridge NSData *)result;
        NSString *content;
        if (privateKeyData.length == 32) {
            // Hex encode
            content = MKMHexEncode(privateKeyData);
        } else {
            // PEM
            content = MKMBase64Encode(privateKeyData);
            content = NSStringFromKeyContent(content, @"EC PRIVATE");
        }
        NSString *algorithm = MKMAlgorithm_ECC;
        keyInfo = @{
            @"algorithm":algorithm,
            @"data"     :content,
        };
    } else {
        // sec key item not found
        NSAssert(status == errSecItemNotFound, @"ECC item status error: %d", status);
    }
    if (result) {
        CFRelease(result);
        result = NULL;
    }
    
    return keyInfo;

}

+ (BOOL)saveKeyWithIdentifier:(NSString *)identifier key:(NSDictionary *)info {
    NSString *pem = [info objectForKey:@"data"];
    NSData *data = nil;
    // check for raw data (32 bytes)
    NSUInteger len = pem.length;
    if (len == 64) {
        // Hex encode
        data = MKMHexDecode(pem);
    } else if (len > 0) {
        // PEM
        data = [MKMSecKeyHelper privateKeyDataFromContent:pem algorithm:MKMAlgorithm_ECC];
    }
    if ([data length] == 0) {
        NSAssert(NO, @"private key data error: %@", info);
        return NO;
    }
    
    NSString *label = identifier;
    NSData *tag = MKMUTF8Encode(s_application_tag);
    
    NSDictionary *query = @{
        (id)kSecClass               :(id)kSecClassKey,
        (id)kSecAttrApplicationLabel:label,
        (id)kSecAttrApplicationTag  :tag,
        (id)kSecAttrKeyType         :(id)kSecAttrKeyTypeECSECPrimeRandom,
        (id)kSecAttrKeyClass        :(id)kSecAttrKeyClassPrivate,
        (id)kSecAttrSynchronizable  :(id)kCFBooleanTrue,
        
        (id)kSecMatchLimit          :(id)kSecMatchLimitOne,
        (id)kSecReturnData          :(id)kCFBooleanTrue,

        // FIXME: 'Status = -25308'
        (id)kSecAttrAccessible      :(id)kSecAttrAccessibleWhenUnlocked,
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &result);
    if (status == errSecSuccess) { // noErr
        // already exists, delete it firest
        NSMutableDictionary *mQuery = [query mutableCopy];
        [mQuery removeObjectForKey:(id)kSecMatchLimit];
        [mQuery removeObjectForKey:(id)kSecReturnData];
        
        status = SecItemDelete((CFDictionaryRef)mQuery);
        if (status != errSecSuccess) {
            NSAssert(false, @"ECC failed to erase key: %@", mQuery);
        }
    } else {
        // sec key item not found
        NSAssert(status == errSecItemNotFound, @"ECC item status error: %d", status);
    }
    if (result) {
        CFRelease(result);
        result = NULL;
    }
    
    // add key item
    NSMutableDictionary *attributes = [query mutableCopy];
    [attributes removeObjectForKey:(id)kSecMatchLimit];
    [attributes removeObjectForKey:(id)kSecReturnData];
    //[attributes setObject:(__bridge id)privateKeyRef forKey:(id)kSecValueRef];
    [attributes setObject:data forKey:(id)kSecValueData];
    
    status = SecItemAdd((CFDictionaryRef)attributes, &result);
    if (result) {
        CFRelease(result);
        result = NULL;
    }
    if (status == errSecSuccess) {
        return YES;
    } else {
        NSAssert(false, @"ECC failed to update key");
        return NO;
    }
}

@end
