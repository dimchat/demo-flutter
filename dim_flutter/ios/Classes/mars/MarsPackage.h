//
//  MarsPackage.h
//  Runner
//
//  Created by Albert Moky on 2023/5/19.
//

#import <DIMClient/DIMClient.h>

NS_ASSUME_NONNULL_BEGIN

/*
 *  Message Packer for Tencent/mars
 *  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 *
 *  data structure:
 *      head_length - 4 bytes
 *      version     - 4 bytes
 *      cmd         - 4 bytes
 *      seq         - 4 bytes
 *      body_len    - 4 bytes
 *      options     - variable length (head_length - 20)
 */
@interface MarsHeader : NSObject

@property(nonatomic, readonly) NSData *data;
@property(nonatomic, readonly) NSUInteger length;  // data.length

@property(nonatomic, readonly) NSUInteger bodyLength;

- (instancetype)initWithData:(NSData *)data bodyLength:(NSUInteger)bodyLen;

+ (instancetype)create:(int)cmd seq:(int)sn body:(NSData *)payload;

+ (instancetype)parse:(NSData *)buffer;

@end

@interface MarsPackage : NSObject

@property(nonatomic, readonly) MarsHeader *head;
@property(nonatomic, readonly) NSData *body;

@property(nonatomic, readonly) NSData *data;  // head.data + body
@property(nonatomic, readonly) NSUInteger length;  // data.length

- (instancetype)initWithData:(NSData *)pack
                        head:(MarsHeader *)header
                        body:(NSData *)payload;

+ (instancetype)create:(int)cmd seq:(int)sn body:(NSData *)payload;

+ (instancetype)parse:(NSData *)buffer;

@end

typedef OKPair<MarsHeader *, NSNumber *> MarsSeekHeaderResult;
typedef OKPair<MarsPackage *, NSNumber *> MarsSeekPackageResult;

@interface MarsSeeker : NSObject

/**
 *  Seek package header in received data buffer
 *
 * @param buffer - received data buffer
 * @return header and it's offset, -1 on data error
 */
+ (MarsSeekHeaderResult *)seekHeader:(NSData *)buffer;

/**
 *  Seek data package from received data buffer
 *
 * @param buffer - received data buffer
 * @return package and it's offset, -1 on data error
 */
+ (MarsSeekPackageResult *)seekPackage:(NSData *)buffer;

@end

NS_ASSUME_NONNULL_END
