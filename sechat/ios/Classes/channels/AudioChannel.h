//
//  AudioChannel.h
//  Runner
//
//  Created by Albert Moky on 2023/5/12.
//

#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioChannel : FlutterMethodChannel

+ (instancetype)channelWithName:(NSString*)name
                binaryMessenger:(NSObject<FlutterBinaryMessenger>*)messenger
                          codec:(NSObject<FlutterMethodCodec>*)codec;

@end

NS_ASSUME_NONNULL_END
