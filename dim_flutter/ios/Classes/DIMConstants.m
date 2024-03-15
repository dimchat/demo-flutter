//
//  DIMConstants.m
//  Sechat
//
//  Created by Albert Moky on 2023/5/9.
//

#import <ObjectKey/ObjectKey.h>
#import <DIMPlugins/DIMPlugins.h>

#import "DIMConstants.h"

#pragma mark - NSDictionary+Binary.m

@implementation NSDictionary (Binary)

- (BOOL)writeToBinaryFile:(NSString *)path {
    return [self writeToBinaryFile:path atomically:YES];
}

- (BOOL)writeToBinaryFile:(NSString *)path atomically:(BOOL)atomically {
    NSData *data;
    NSPropertyListFormat fmt = NSPropertyListBinaryFormat_v1_0;
    NSPropertyListWriteOptions opt = 0;
    NSError *err = nil;
    data = [NSPropertyListSerialization dataWithPropertyList:self
                                                      format:fmt
                                                     options:opt
                                                       error:&err];
    if (err) {
        NSAssert(false, @"serialize failed: %@", err);
        return NO;
    }
    return [data writeToFile:path atomically:atomically];
}

@end

#pragma mark - DIMStorage.m

@implementation DIMStorage

static NSString *s_documentDirectory = nil;

+ (NSString *)documentDirectory {
    OKSingletonDispatchOnce(^{
        if (s_documentDirectory == nil) {
            NSArray *paths;
            paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
                                                        NSUserDomainMask, YES);
            s_documentDirectory = paths.firstObject;
        }
    });
    return s_documentDirectory;
}

static NSString *s_cachesDirectory = nil;

+ (NSString *)cachesDirectory {
    OKSingletonDispatchOnce(^{
        if (s_cachesDirectory == nil) {
            NSArray *paths;
            paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,
                                                        NSUserDomainMask, YES);
            s_cachesDirectory = paths.firstObject;
        }
    });
    return s_cachesDirectory;
}

static NSString *s_temporaryDirectory = nil;

+ (NSString *)temporaryDirectory {
    OKSingletonDispatchOnce(^{
        if (s_temporaryDirectory == nil) {
            s_temporaryDirectory = NSTemporaryDirectory();
        }
    });
    return s_temporaryDirectory;
}

@end

@implementation DIMStorage (FileManager)

+ (BOOL)createDirectoryAtPath:(NSString *)directory {
    return [self createDirectoryAtPath:directory error:nil];
}
+ (BOOL)createDirectoryAtPath:(NSString *)directory error:(NSError **)error {
    // check base directory exists
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir;
    if ([fm fileExistsAtPath:directory isDirectory:&isDir]) {
        // already exists
        NSAssert(isDir, @"path exists but not a directory: %@", directory);
        return YES;
    }
    return [fm createDirectoryAtPath:directory
         withIntermediateDirectories:YES
                          attributes:nil
                               error:error];
}

+ (BOOL)fileExistsAtPath:(NSString *)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    return [fm fileExistsAtPath:path];
}

+ (BOOL)removeItemAtPath:(NSString *)path {
    return [self removeItemAtPath:path error:nil];
}
+ (BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL ok = [fm fileExistsAtPath:path];
    if (!ok) {
        // file not found
        return YES;
    }
    return [fm removeItemAtPath:path error:error];
}

+ (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath {
    return [self moveItemAtPath:srcPath toPath:dstPath error:nil];
}
+ (BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath
                 error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL ok = [fm fileExistsAtPath:srcPath];
    if (!ok) {
        NSLog(@"file not found: %@", srcPath);
        return NO;
    }
    // prepare dir
    NSString *dir = [dstPath stringByDeletingLastPathComponent];
    ok = [DIMStorage createDirectoryAtPath:dir];
    if (!ok) {
        NSAssert(false, @"failed to create directory: %@", dir);
        return NO;
    }
    return [fm moveItemAtPath:srcPath toPath:dstPath error:error];
}

+ (BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath {
    return [self copyItemAtPath:srcPath toPath:dstPath error:nil];
}
+ (BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL ok = [fm fileExistsAtPath:srcPath];
    if (!ok) {
        NSLog(@"file not found: %@", srcPath);
        return NO;
    }
    // prepare dir
    NSString *dir = [dstPath stringByDeletingLastPathComponent];
    ok = [DIMStorage createDirectoryAtPath:dir];
    if (!ok) {
        NSAssert(false, @"failed to create directory: %@", dir);
        return NO;
    }
    return [fm copyItemAtPath:srcPath toPath:dstPath error:error];
}

@end

@implementation DIMStorage (Serialization)

+ (nullable NSDictionary *)dictionaryWithContentsOfFile:(NSString *)path {
    BOOL ok = [DIMStorage fileExistsAtPath:path];
    if (!ok) {
        NSLog(@"file not found: %@", path);
        return nil;
    }
    return [NSDictionary dictionaryWithContentsOfFile:path];
}

+ (BOOL)dictionary:(NSDictionary *)dict writeToBinaryFile:(NSString *)path {
    // prepare directory
    NSString *dir = [path stringByDeletingLastPathComponent];
    BOOL ok = [DIMStorage createDirectoryAtPath:dir];
    if (!ok) {
        NSAssert(false, @"failed to create directory: %@", dir);
        return NO;
    }
    return [dict writeToBinaryFile:path atomically:YES];
}

+ (nullable NSArray *)arrayWithContentsOfFile:(NSString *)path {
    BOOL ok = [DIMStorage fileExistsAtPath:path];
    if (!ok) {
        NSLog(@"file not found: %@", path);
        return nil;
    }
    return [NSArray arrayWithContentsOfFile:path];
}

+ (BOOL)array:(NSArray *)list writeToFile:(NSString *)path {
    // prepare directory
    NSString *dir = [path stringByDeletingLastPathComponent];
    BOOL ok = [DIMStorage createDirectoryAtPath:dir];
    if (!ok) {
        NSAssert(false, @"failed to create directory: %@", dir);
        return NO;
    }
    return [list writeToFile:path atomically:YES];
}

+ (nullable NSData *)dataWithContentsOfFile:(NSString *)path {
    BOOL ok = [DIMStorage fileExistsAtPath:path];
    if (!ok) {
        NSLog(@"file not found: %@", path);
        return nil;
    }
    return [NSData dataWithContentsOfFile:path];
}

+ (BOOL)data:(NSData *)data writeToFile:(NSString *)path {
    // prepare directory
    NSString *dir = [path stringByDeletingLastPathComponent];
    BOOL ok = [DIMStorage createDirectoryAtPath:dir];
    if (!ok) {
        NSAssert(false, @"failed to create directory: %@", dir);
        return NO;
    }
    return [data writeToFile:path atomically:YES];
}

@end

@implementation DIMStorage (LocalCache)

+ (NSString *)avatarPathWithFilename:(NSString *)filename {
    NSString *dir = [self cachesDirectory];
    dir = [dir stringByAppendingPathComponent:@"avatar"];
    NSString *AA = [filename substringWithRange:NSMakeRange(0, 2)];
    NSString *BB = [filename substringWithRange:NSMakeRange(2, 2)];
    return [NSString stringWithFormat:@"%@/%@/%@/%@", dir, AA, BB, filename];
}

+ (NSString *)cachePathWithFilename:(NSString *)filename {
    NSString *dir = [self cachesDirectory];
    dir = [dir stringByAppendingPathComponent:@"files"];
    NSString *AA = [filename substringWithRange:NSMakeRange(0, 2)];
    NSString *BB = [filename substringWithRange:NSMakeRange(2, 2)];
    return [NSString stringWithFormat:@"%@/%@/%@/%@", dir, AA, BB, filename];
}

+ (NSString *)uploadPathWithFilename:(NSString *)filename {
    NSString *dir = [self temporaryDirectory];
    dir = [dir stringByAppendingPathComponent:@"upload"];
    return [NSString stringWithFormat:@"%@/%@", dir, filename];
}

+ (NSString *)downloadPathWithFilename:(NSString *)filename {
    NSString *dir = [self temporaryDirectory];
    dir = [dir stringByAppendingPathComponent:@"download"];
    return [NSString stringWithFormat:@"%@/%@", dir, filename];
}

+ (void)cleanupDirectory:(NSString *)dir beforeTime:(NSTimeInterval)expired {
    // TODO: Delete expired files in this directory cyclically
}

@end

#pragma mark - DIMPrivateKeyStore.m

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
