//
//  FileTransferChannel.h
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import <Flutter/Flutter.h>
#import <DIMClient/DIMClient.h>

NS_ASSUME_NONNULL_BEGIN

@interface FileTransferChannel : FlutterMethodChannel <DIMUploadDelegate, DIMDownloadDelegate>

+ (instancetype)channelWithName:(NSString*)name
                binaryMessenger:(NSObject<FlutterBinaryMessenger>*)messenger
                          codec:(NSObject<FlutterMethodCodec>*)codec;

@end

NS_ASSUME_NONNULL_END
