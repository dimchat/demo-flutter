//
//  DIMStorage.h
//  Sechat
//
//  Created by Albert Moky on 2023/5/9.
//

#import <Foundation/Foundation.h>

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

NS_ASSUME_NONNULL_END
