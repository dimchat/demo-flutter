//
//  DIMDatabaseChannel.h
//  Sechat
//
//  Created by Albert Moky on 2023/5/16.
//

#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

@interface DIMDatabaseChannel : FlutterMethodChannel

+ (instancetype)channelWithName:(NSString*)name
                binaryMessenger:(NSObject<FlutterBinaryMessenger>*)messenger
                          codec:(NSObject<FlutterMethodCodec>*)codec;

@end

NS_ASSUME_NONNULL_END
