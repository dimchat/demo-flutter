//
//  DIMPrivateKeyStore.m
//  Runner
//
//  Created by Albert Moky on 2023/5/16.
//

#import "DIMPrivateKeyStore.h"

static inline NSString *private_label(NSString *type, id<MKMID> ID) {
    NSString *address = [ID.address string];
    if ([type length] == 0) {
        return address;
    }
    return [NSString stringWithFormat:@"%@:%@", type, address];
}

static inline BOOL private_save(id<MKMPrivateKey> key, NSString *type, id<MKMID> ID) {
    NSString *label = private_label(type, ID);
    return MKMPrivateKeySave(label, key);
}

static inline id<MKMPrivateKey> private_load(NSString *type, id<MKMID> ID) {
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
- (BOOL)savePrivateKey:(id<MKMPrivateKey>)key
              withType:(NSString *)type
               forUser:(id<MKMID>)user {
    // TODO: support multi private keys
    BOOL ok = private_save(key, type, user);
    NSLog(@"save private key: %d, %@", ok, user);
    return ok;
}

// Override
- (id<MKMPrivateKey>)privateKeyForSignature:(id<MKMID>)user {
    // TODO: support multi private keys
    return [self privateKeyForVisaSignature:user];
}

// Override
- (id<MKMPrivateKey>)privateKeyForVisaSignature:(id<MKMID>)user {
    id<MKMPrivateKey> key;
    // get private key paired with meta.key
    key = private_load(DIMPrivateKeyType_Meta, user);
    if (!key) {
        // get private key paired with meta.key
        key = private_load(nil, user);
    }
    NSLog(@"load private key: %@, %@", [key algorithm], user);
    return key;
}

// Override
- (NSArray<id<MKMDecryptKey>> *)privateKeysForDecryption:(id<MKMID>)user {
    NSMutableArray *mArray = [[NSMutableArray alloc] init];
    id<MKMPrivateKey> key;
    // 1. get private key paired with visa.key
    key = private_load(DIMPrivateKeyType_Visa, user);
    if (key) {
        [mArray addObject:key];
    }
    // get private key paired with meta.key
    key = private_load(DIMPrivateKeyType_Meta, user);
    if ([key conformsToProtocol:@protocol(MKMDecryptKey)]) {
        [mArray addObject:key];
    }
    // get private key paired with meta.key
    key = private_load(nil, user);
    if ([key conformsToProtocol:@protocol(MKMDecryptKey)]) {
        [mArray addObject:key];
    }
    NSLog(@"load private keys: %lu, %@", [mArray count], user);
    return mArray;
}

@end
