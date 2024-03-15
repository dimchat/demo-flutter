//
//  DIMFileTransferChannel.m
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import "DIMConstants.h"

#import "DIMFileTransfer.h"
#import "DIMChannelManager.h"

#import "DIMFileTransferChannel.h"

static void onMethodCall(FlutterMethodCall* call, FlutterResult result);

@implementation DIMFileTransferChannel

+ (instancetype)channelWithName:(NSString*)name
                binaryMessenger:(NSObject<FlutterBinaryMessenger>*)messenger
                          codec:(NSObject<FlutterMethodCodec>*)codec {
    id channel = [[self alloc] initWithName:name
                            binaryMessenger:messenger
                                      codec:codec];
    [channel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
        onMethodCall(call, result);
    }];
    return channel;
}

@end

static inline void onMethodCall(FlutterMethodCall* call, FlutterResult success) {
    NSString *method = [call method];
    if ([method isEqualToString:kChannelMethod_GetCachesDirectory]) {
        // getCachesDirectory
        NSString *dir = [DIMStorage cachesDirectory];
        success(dir);
    } else if ([method isEqualToString:kChannelMethod_GetTemporaryDirectory]) {
        // getCachesDirectory
        NSString *dir = [DIMStorage temporaryDirectory];
        success(dir);
    } else {
        NSLog(@"not implemented: %@", method);
        assert(false);
    }
}
