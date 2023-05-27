//
//  DIMSessionChannel.m
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import "MarsPackage.h"

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

- (void)onStateChangedFrom:(nullable DIMSessionState *)previous
                        to:(nullable DIMSessionState *)current
                      when:(NSTimeInterval)now {
    NSDictionary *params = @{
        @"previous": @([previous index]),
        @"current": @([current index]),
        @"now": @(now),
    };
    NSLog(@"channel: %@, method: %@", self, kChannelMethod_OnStateChanged);
    [self invokeMethod:kChannelMethod_OnStateChanged arguments:params];
}

- (void)onReceivedData:(NSData *)pack from:(id<NIOSocketAddress>)remote {
    NSDictionary *params = @{
        @"payload": pack,
        @"remote": [remote description],
    };
    [self invokeMethod:kChannelMethod_OnReceived arguments:params];
}

- (void)sendCommand:(id<DKDCommand>)content {
    NSDictionary *params = @{
        @"content": [content dictionary],
    };
    [self invokeMethod:kChannelMethod_SendCommand arguments:params];
}
- (void)sendCommand:(id<DKDCommand>)content receiver:(id<MKMID>)to {
    NSDictionary *params = @{
        @"content": [content dictionary],
        @"receiver": [to string],
    };
    [self invokeMethod:kChannelMethod_SendCommand arguments:params];
}

- (void)sendContent:(id<DKDContent>)content receiver:(id<MKMID>)to {
    NSDictionary *params = @{
        @"content": [content dictionary],
        @"receiver": [to string],
    };
    [self invokeMethod:kChannelMethod_SendContent arguments:params];
}

@end

static inline NSData *packData(NSData *payload) {
    NSLog(@"packing payload: %lu bytes", payload.length);
    int cmd = 3;  // SEND_MSG
    int seq = 9527;
    MarsPackage *pack = [MarsPackage create:cmd seq:seq body:payload];
    return [pack data];
}

static inline MarsSeekPackageResult *unpackData(NSData *data) {
    NSLog(@"unpacking data: %lu bytes", data.length);
    MarsSeekPackageResult *result = [MarsSeeker seekPackage:data];
    MarsPackage *pack = result.first;
    NSInteger offset = [result.second integerValue];
    if (pack.length == 0) {
        NSLog(@"got nothing, offset: %ld", offset);
    } else {
        NSLog(@"got package length: %lu, payload: %lu, offset: %ld",
              pack.length, pack.body.length, offset);
    }
    return result;
}

static inline void queueMessagePackage(NSDictionary *msg, NSData *data, int prior) {
    id<DKDReliableMessage> rMsg = DKDReliableMessageParse(msg);
    NSLog(@"sending (%lu bytes): %@, priority: %d", [data length], msg, prior);
    DIMSessionController *controller = [DIMSessionController sharedInstance];
    DIMClientSession *session = [controller session];
    if (session) {
        [session queueMessage:rMsg package:data priority:prior];
    } else {
        NSLog(@"session not start yet");
    }
}

static inline NSUInteger getState(void) {
    DIMSessionController *controller = [DIMSessionController sharedInstance];
    DIMSessionState *state = [controller state];
    NSLog(@"session state: %@", state);
    return [state index];
}

static inline void connectTo(NSString *host, UInt16 port) {
    NSLog(@"connecting to %@:%u ...", host, port);
    DIMSessionController *controller = [DIMSessionController sharedInstance];
    [controller connectToHost:host port:port];
}

static inline BOOL loginUser(NSString *user) {
    NSLog(@"login user: %@", user);
    id<MKMID> ID = MKMIDParse(user);
    assert(ID);
    DIMSessionController *controller = [DIMSessionController sharedInstance];
    return [controller loginWithUser:ID];
}

static inline void setSessionKey(NSString *sessionKey) {
    NSLog(@"session key: %@", sessionKey);
    DIMSessionController *controller = [DIMSessionController sharedInstance];
    [controller setSessionKey:sessionKey];
}

static inline void onMethodCall(FlutterMethodCall* call, FlutterResult success) {
    NSString *method = [call method];
    if ([method isEqualToString:kChannelMethod_SendMessagePack]) {
        // queueMessagePackage
        NSDictionary *msg = [call.arguments objectForKey:@"msg"];
        FlutterStandardTypedData *data = [call.arguments objectForKey:@"data"];
        NSNumber *prior = [call.arguments objectForKey:@"priority"];
        // call
        queueMessagePackage(msg, [data data], [prior intValue]);
        success(nil);
    } else if ([method isEqualToString:kChannelMethod_GetState]) {
        // getState
        NSUInteger state = getState();
        success(@(state));
    } else if ([method isEqualToString:kChannelMethod_Connect]) {
        // connect
        NSString *host = [call.arguments objectForKey:@"host"];
        NSNumber *port = [call.arguments objectForKey:@"port"];
        // call
        connectTo(host, [port unsignedShortValue]);
        success(nil);
    } else if ([method isEqualToString:kChannelMethod_Login]) {
        // login
        NSString *user = [call.arguments objectForKey:@"user"];
        BOOL ok = loginUser(user);
        success(@(ok));
    } else if ([method isEqualToString:kChannelMethod_SetSessionKey]) {
        // setSessionKey
        NSString *session = [call.arguments objectForKey:@"session"];
        setSessionKey(session);
        success(nil);
    } else if ([method isEqualToString:kChannelMethod_PackData]) {
        // packData
        FlutterStandardTypedData *payload = [call.arguments objectForKey:@"payload"];
        NSData *pack = packData([payload data]);
        success(pack);
    } else if ([method isEqualToString:kChannelMethod_UnpackData]) {
        // unpackData
        FlutterStandardTypedData *data = [call.arguments objectForKey:@"data"];
        NSDictionary *info;
        MarsSeekPackageResult *result = unpackData([data data]);
        MarsPackage *pack = result.first;
        NSData *payload = [pack body];
        if ([payload length] == 0) {
            // incompleted package?
            payload = [[NSData alloc] init];
        }
        NSInteger offset = [result.second integerValue];
        if (offset < 0) {
            // data error, drop the whole buffer
            info = @{
                @"position": @([data.data length]),
            };
        } else {
            info = @{
                @"position": @(offset + pack.length),
                @"payload": payload,
            };
        }
        success(info);
    } else {
        NSLog(@"not implemented: %@", method);
        assert(false);
    }
}
