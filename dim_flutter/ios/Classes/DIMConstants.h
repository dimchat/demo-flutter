//
//  DIMConstants.h
//  Sechat
//
//  Created by Albert Moky on 2023/5/9.
//

#import <MingKeMing/MingKeMing.h>

#pragma mark - DIMStorage.h

NS_ASSUME_NONNULL_BEGIN

@interface DIMStorage : NSObject

// "{HOME}/Documents"
+ (NSString *)documentDirectory;

// "{HOME}/Library/Caches"
+ (NSString *)cachesDirectory;

// "{HOME}/tmp"
+ (NSString *)temporaryDirectory;

@end

@interface DIMStorage (FileManager)

+ (BOOL)createDirectoryAtPath:(NSString *)directory;
+ (BOOL)createDirectoryAtPath:(NSString *)directory error:(NSError **)error;

+ (BOOL)fileExistsAtPath:(NSString *)path;

+ (BOOL)removeItemAtPath:(NSString *)path;
+ (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error;

+ (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath;
+ (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath
                 error:(NSError **)error;

+ (BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath;
+ (BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath
                 error:(NSError **)error;

@end

@interface DIMStorage (Serialization)

+ (nullable NSDictionary *)dictionaryWithContentsOfFile:(NSString *)path;
+ (BOOL)dictionary:(NSDictionary *)dict writeToBinaryFile:(NSString *)path;

+ (nullable NSArray *)arrayWithContentsOfFile:(NSString *)path;
+ (BOOL)array:(NSArray *)list writeToFile:(NSString *)path;

+ (nullable NSData *)dataWithContentsOfFile:(NSString *)path;
+ (BOOL)data:(NSData *)data writeToFile:(NSString *)path;

@end

@interface DIMStorage (LocalCache)

/**
 *  Avatar image file path
 *
 * @param filename - image filename: hex(md5(data)) + ext
 * @return "Library/Caches/avatar/{AA}/{BB}/{filename}"
 */
+ (NSString *)avatarPathWithFilename:(NSString *)filename;

/**
 *  Cached file path
 *  (image, audio, video, ...)
 *
 * @param filename - messaged filename: hex(md5(data)) + ext
 * @return "Library/Caches/files/{AA}/{BB}/{filename}"
 */
+ (NSString *)cachePathWithFilename:(NSString *)filename;

/**
 *  Encrypted data file path
 *
 * @param filename - messaged filename: hex(md5(data)) + ext
 * @return "tmp/upload/{filename}"
 */
+ (NSString *)uploadPathWithFilename:(NSString *)filename;

/**
 *  Encrypted data file path
 *
 * @param filename - messaged filename: hex(md5(data)) + ext
 * @return "tmp/download/{filename}"
 */
+ (NSString *)downloadPathWithFilename:(NSString *)filename;

/**
 *  Delete expired files in this directory cyclically
 *
 * @param dir     - directory
 * @param expired - expired time (milliseconds, from Jan 1, 1970 UTC)
 */
+ (void)cleanupDirectory:(NSString *)dir beforeTime:(NSTimeInterval)expired;

@end

NS_ASSUME_NONNULL_END

#pragma mark - DIMAccountDBI.h

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
- (BOOL)savePrivateKey:(id<MKMPrivateKey>)key withType:(NSString *)type forUser:(id<MKMID>)user;

/**
 *  Get private keys for user
 *
 * @param user - user ID
 * @return all keys marked for decryption
 */
- (NSArray<id<MKMDecryptKey>> *)privateKeysForDecryption:(id<MKMID>)user;

/**
 *  Get private key for user
 *
 * @param user - user ID
 * @return first key marked for signature
 */
- (nullable id<MKMPrivateKey>)privateKeyForSignature:(id<MKMID>)user;

/**
 *  Get private key for user
 *
 * @param user - user ID
 * @return the private key matched with meta.key
 */
- (nullable id<MKMPrivateKey>)privateKeyForVisaSignature:(id<MKMID>)user;

@end

NS_ASSUME_NONNULL_END

#pragma mark - DIMPrivateKeyStore.h

NS_ASSUME_NONNULL_BEGIN

@interface DIMPrivateKeyStore : NSObject <DIMPrivateKeyDBI>

+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
