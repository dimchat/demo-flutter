//
//  RSA.m
//  Sechat
//
//  Created by Albert Moky on 2025/4/24.
//

#import "DataCoder.h"

#import "SecKey.h"

#import "RSA.h"

@implementation RSAKeyStore

static NSString *s_application_tag = @"chat.dim.rsa.private";

+ (nullable NSDictionary *)loadKeyWithIdentifier:(NSString *)identifier {
    NSDictionary *keyInfo = nil;
    
    NSString *label = identifier;
    NSData *tag = MKMUTF8Encode(s_application_tag);
    
    NSDictionary *query = @{
        (id)kSecClass               :(id)kSecClassKey,
        (id)kSecAttrApplicationLabel:label,
        (id)kSecAttrApplicationTag  :tag,
        (id)kSecAttrKeyType         :(id)kSecAttrKeyTypeRSA,
        (id)kSecAttrKeyClass        :(id)kSecAttrKeyClassPrivate,
        (id)kSecAttrSynchronizable  :(id)kCFBooleanTrue,
        
        (id)kSecMatchLimit          :(id)kSecMatchLimitOne,
        (id)kSecReturnRef           :(id)kCFBooleanTrue,

        // FIXME: 'Status = -25308'
        (id)kSecAttrAccessible      :(id)kSecAttrAccessibleWhenUnlocked,
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &result);
    if (status == errSecSuccess) { // noErr
        // private key
        SecKeyRef privateKeyRef = (SecKeyRef)result;
        NSString *skc = [MKMSecKeyHelper serializePrivateKey:privateKeyRef algorithm:MKMAlgorithm_RSA];
        // public key
        SecKeyRef publicKeyRef = SecKeyCopyPublicKey(privateKeyRef);
        NSString *pkc = [MKMSecKeyHelper serializePublicKey:publicKeyRef algorithm:MKMAlgorithm_RSA];
        // key content
        NSString *content = [NSString stringWithFormat:@"%@%@", pkc, skc];
        NSString *algorithm = MKMAlgorithm_RSA;
        keyInfo = @{
            @"algorithm":algorithm,
            @"data"     :content,
        };
    } else {
        // sec key item not found
        NSAssert(status == errSecItemNotFound, @"RSA item status error: %d", status);
    }
    if (result) {
        CFRelease(result);
        result = NULL;
    }
    
    return keyInfo;
}

+ (BOOL)saveKeyWithIdentifier:(NSString *)identifier key:(NSDictionary *)info {
    NSString *pem = [info objectForKey:@"data"];
    NSData *data = [MKMSecKeyHelper privateKeyDataFromContent:pem algorithm:MKMAlgorithm_RSA];
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
        (id)kSecAttrKeyType         :(id)kSecAttrKeyTypeRSA,
        (id)kSecAttrKeyClass        :(id)kSecAttrKeyClassPrivate,
        (id)kSecAttrSynchronizable  :(id)kCFBooleanTrue,
        
        (id)kSecMatchLimit          :(id)kSecMatchLimitOne,
        (id)kSecReturnRef           :(id)kCFBooleanTrue,

        // FIXME: 'Status = -25308'
        (id)kSecAttrAccessible      :(id)kSecAttrAccessibleWhenUnlocked,
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, &result);
    if (status == errSecSuccess) { // noErr
        // already exists, delete it firest
        NSMutableDictionary *mQuery = [query mutableCopy];
        [mQuery removeObjectForKey:(id)kSecMatchLimit];
        [mQuery removeObjectForKey:(id)kSecReturnRef];
        
        status = SecItemDelete((CFDictionaryRef)mQuery);
        if (status != errSecSuccess) {
            NSAssert(false, @"RSA failed to erase key: %@", mQuery);
        }
    } else {
        // sec key item not found
        NSAssert(status == errSecItemNotFound, @"RSA item status error: %d", status);
    }
    if (result) {
        CFRelease(result);
        result = NULL;
    }
    
    // add key item
    NSMutableDictionary *attributes = [query mutableCopy];
    [attributes removeObjectForKey:(id)kSecMatchLimit];
    [attributes removeObjectForKey:(id)kSecReturnRef];
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
        NSAssert(false, @"RSA failed to update key");
        return NO;
    }
}

@end
