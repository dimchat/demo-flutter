//
//  DIMDatabaseChannel.m
//  Sechat
//
//  Created by Albert Moky on 2023/5/16.
//

#import "DIMStorage.h"
#import "PrivateKey.h"

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
    NSString *user = [call.arguments objectForKey:@"user"];
    assert(user);
    
    NSString *method = [call method];
    if ([method isEqualToString:kChannelMethod_SavePrivateKey]) {
        // savePrivateKey
        NSString *type = [call.arguments objectForKey:@"type"];
        NSDictionary *key = [call.arguments objectForKey:@"key"];
        assert(key);
        BOOL ok = [db savePrivateKey:key withType:type forUser:user];
        success(ok ? @1 : @0);
    } else if ([method isEqualToString:kChannelMethod_PrivateKeyForSignature]) {
        // privateKeyForSignature
        NSDictionary *key = [db privateKeyForSignature:user];
        success(key);
    } else if ([method isEqualToString:kChannelMethod_PrivateKeyForVisaSignature]) {
        // privateKeyForVisaSignature
        NSDictionary *key = [db privateKeyForVisaSignature:user];
        success(key);
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
