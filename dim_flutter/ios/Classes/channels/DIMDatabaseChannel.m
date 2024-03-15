//
//  DIMDatabaseChannel.m
//  Runner
//
//  Created by Albert Moky on 2023/5/16.
//

#import "DIMConstants.h"

#import "DIMChannelManager.h"

#import "DIMDatabaseChannel.h"

static void onMethodCall(FlutterMethodCall* call, FlutterResult result);

@implementation DIMDatabaseChannel

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
    DIMPrivateKeyStore *db = [DIMPrivateKeyStore sharedInstance];
    id<MKMID> user = MKMIDParse([call.arguments objectForKey:@"user"]);
    assert(user);
    
    NSString *method = [call method];
    if ([method isEqualToString:kChannelMethod_SavePrivateKey]) {
        // savePrivateKey
        NSString *type = [call.arguments objectForKey:@"type"];
        id<MKMPrivateKey> key = MKMPrivateKeyParse([call.arguments objectForKey:@"key"]);
        assert(key);
        BOOL ok = [db savePrivateKey:key withType:type forUser:user];
        success(ok ? @1 : @0);
    } else if ([method isEqualToString:kChannelMethod_PrivateKeyForSignature]) {
        // privateKeyForSignature
        id<MKMPrivateKey> key = [db privateKeyForSignature:user];
        success([key dictionary]);
    } else if ([method isEqualToString:kChannelMethod_PrivateKeyForVisaSignature]) {
        // privateKeyForVisaSignature
        id<MKMPrivateKey> key = [db privateKeyForVisaSignature:user];
        success([key dictionary]);
    } else if ([method isEqualToString:kChannelMethod_PrivateKeysForDecryption]) {
        // privateKeysForDecryption
        id keys = [db privateKeysForDecryption:user];
        //success(DIMRevertPrivateKeys(keys));
        success(keys);
    } else {
        NSLog(@"not implemented: %@", method);
        assert(false);
    }
}
