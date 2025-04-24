//
//  PrivateKey.h
//  Sechat
//
//  Created by Albert Moky on 2025/4/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#define DIMPrivateKeyType_Meta @"M"
#define DIMPrivateKeyType_Visa @"V"

@protocol DIMPrivateKeyDBI <NSObject>

/**
 *  Save private key for user
 *
 * @param user - user ID
 * @param key - private key
 * @param type - 'M' for matching meta.key; or 'P' for matching profile.key
 * @return false on error
 */
- (BOOL)savePrivateKey:(NSDictionary *)key withType:(NSString *)type forUser:(NSString *)user;

/**
 *  Get private keys for user
 *
 * @param user - user ID
 * @return all keys marked for decryption
 */
- (NSArray<NSDictionary *> *)privateKeysForDecryption:(NSString *)user;

/**
 *  Get private key for user
 *
 * @param user - user ID
 * @return first key marked for signature
 */
- (nullable NSDictionary *)privateKeyForSignature:(NSString *)user;

/**
 *  Get private key for user
 *
 * @param user - user ID
 * @return the private key matched with meta.key
 */
- (nullable NSDictionary *)privateKeyForVisaSignature:(NSString *)user;

@end

NS_ASSUME_NONNULL_END

#pragma mark - DIMPrivateKeyStore.h

NS_ASSUME_NONNULL_BEGIN

@interface DIMPrivateKeyStore : NSObject <DIMPrivateKeyDBI>

+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C"
{
#endif

NSDictionary *MKMPrivateKeyLoad(NSString * identifier);

BOOL MKMPrivateKeySave(NSString * identifier, NSDictionary *sKey);

#ifdef __cplusplus
} /* end of extern "C" */
#endif

NS_ASSUME_NONNULL_END
