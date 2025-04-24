//
//  DIMSessionChannel.h
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

@interface DIMSessionChannel : FlutterMethodChannel

+ (instancetype)channelWithName:(NSString*)name
                binaryMessenger:(NSObject<FlutterBinaryMessenger>*)messenger
                          codec:(NSObject<FlutterMethodCodec>*)codec;

- (void)sendCommand:(NSDictionary *)content;
- (void)sendCommand:(NSDictionary *)content receiver:(NSString *)to;
- (void)sendContent:(NSDictionary *)content receiver:(NSString *)to;

@end

NS_ASSUME_NONNULL_END
