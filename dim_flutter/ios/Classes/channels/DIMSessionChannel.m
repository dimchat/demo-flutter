//
//  DIMSessionChannel.m
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import "DIMChannelManager.h"
#import "DIMSessionController.h"

#import "DIMSessionChannel.h"

static void onMethodCall(FlutterMethodCall* call, FlutterResult result);

@implementation DIMSessionChannel

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

- (void)sendCommand:(NSDictionary *)content {
    NSDictionary *params = @{
        @"content": content,
    };
    [self invokeMethod:kChannelMethod_SendCommand arguments:params];
}
- (void)sendCommand:(NSDictionary *)content receiver:(NSString *)to {
    NSDictionary *params = @{
        @"content": content,
        @"receiver": to,
    };
    [self invokeMethod:kChannelMethod_SendCommand arguments:params];
}

- (void)sendContent:(NSDictionary *)content receiver:(NSString *)to {
    NSDictionary *params = @{
        @"content": content,
        @"receiver": to,
    };
    [self invokeMethod:kChannelMethod_SendContent arguments:params];
}

@end

static inline void onMethodCall(FlutterMethodCall* call, FlutterResult success) {
    NSString *method = [call method];
    NSLog(@"not implemented: %@", method);
    assert(false);
}
