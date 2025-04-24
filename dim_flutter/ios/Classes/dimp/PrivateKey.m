//
//  PrivateKey.m
//  Sechat
//
//  Created by Albert Moky on 2025/4/24.
//

#import <ObjectKey/ObjectKey.h>

#import "ECC.h"
#import "RSA.h"

#import "PrivateKey.h"

static inline NSString *private_label(NSString *type, NSString *ID) {
    NSArray<NSString *> *pair = [ID componentsSeparatedByString:@"/"];
    assert(pair.firstObject.length > 0);
    pair = [pair.firstObject componentsSeparatedByString:@"@"];
    assert(pair.lastObject.length > 0);
    NSString *address = pair.lastObject;
    if ([type length] == 0) {
        return address;
    }
    return [NSString stringWithFormat:@"%@:%@", type, address];
}

static inline BOOL private_save(NSDictionary *key, NSString *type, NSString *ID) {
    NSString *label = private_label(type, ID);
    return MKMPrivateKeySave(label, key);
}

static inline NSDictionary *private_load(NSString *type, NSString *ID) {
    NSString *label = private_label(type, ID);
    return MKMPrivateKeyLoad(label);
}

@implementation DIMPrivateKeyStore

OKSingletonImplementations(DIMPrivateKeyStore, sharedInstance)

- (instancetype)init {
    if (self = [super init]) {
        //
    }
    return self;
}

// Override
- (BOOL)savePrivateKey:(NSDictionary *)key
              withType:(NSString *)type
               forUser:(NSString *)user {
    // TODO: support multi private keys
    BOOL ok = private_save(key, type, user);
    NSLog(@"save private key: %d, %@", ok, user);
    return ok;
}

// Override
- (NSDictionary *)privateKeyForSignature:(NSString *)user {
    // TODO: support multi private keys
    return [self privateKeyForVisaSignature:user];
}

// Override
- (NSDictionary *)privateKeyForVisaSignature:(NSString *)user {
    NSDictionary *key = nil;
    // get private key paired with meta.key
    key = private_load(DIMPrivateKeyType_Meta, user);
    if (!key) {
        // get private key paired with meta.key
        key = private_load(nil, user);
    }
    NSLog(@"load private key: %@, %@", [key objectForKey:@"algorithm"], user);
    return key;
}

// Override
- (NSArray<NSDictionary *> *)privateKeysForDecryption:(NSString *)user {
    NSMutableArray *mArray = [[NSMutableArray alloc] init];
    NSDictionary *key;
    // 1. get private key paired with visa.key
    key = private_load(DIMPrivateKeyType_Visa, user);
    if (key) {
        [mArray addObject:key];
    }
    // get private key paired with meta.key
    key = private_load(DIMPrivateKeyType_Meta, user);
    //if ([key conformsToProtocol:@protocol(MKMDecryptKey)]) {
    NSString *algorithm = [key objectForKey:@"algorithm"];
    BOOL isDecryptKey = [algorithm containsString:@"RSA"];
    if (isDecryptKey) {
        [mArray addObject:key];
    }
    // get private key paired with meta.key
    key = private_load(nil, user);
    if (isDecryptKey) {
        [mArray addObject:key];
    }
    NSLog(@"load private keys: %lu, %@", [mArray count], user);
    return mArray;
}

@end

NSDictionary *MKMPrivateKeyLoad(NSString * identifier) {
    //id key = [MKMRSAPrivateKey loadKeyWithIdentifier:identifier];
    id key = [RSAKeyStore loadKeyWithIdentifier:identifier];
    if (key) {
        return key;
    }
    key = [ECCKeyStore loadKeyWithIdentifier:identifier];
    if (key) {
        return key;
    }
    return nil;
}

BOOL MKMPrivateKeySave(NSString * identifier, NSDictionary *sKey) {
    NSString *algorithm = [sKey objectForKey:@"algorithm"];
    if ([algorithm containsString:@"RSA"]) {
        return [RSAKeyStore saveKeyWithIdentifier:identifier key:sKey];
    }
    if ([algorithm containsString:@"ECC"]) {
        return [ECCKeyStore saveKeyWithIdentifier:identifier key:sKey];
    }
    return NO;
}
