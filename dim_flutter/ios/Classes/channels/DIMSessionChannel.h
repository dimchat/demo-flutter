//
//  DIMSessionChannel.h
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import <Flutter/Flutter.h>
#import <DIMCore/DIMCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface DIMSessionChannel : FlutterMethodChannel

+ (instancetype)channelWithName:(NSString*)name
                binaryMessenger:(NSObject<FlutterBinaryMessenger>*)messenger
                          codec:(NSObject<FlutterMethodCodec>*)codec;

- (void)sendCommand:(id<DKDCommand>)content;
- (void)sendCommand:(id<DKDCommand>)content receiver:(id<MKMID>)to;
- (void)sendContent:(id<DKDContent>)content receiver:(id<MKMID>)to;

@end

NS_ASSUME_NONNULL_END
