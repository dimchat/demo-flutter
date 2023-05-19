//
//  DIMFileTransferChannel.m
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import <DIMClient/DIMClient.h>

#import "DIMFileTransfer.h"
#import "DIMChannelManager.h"

#import "DIMFileTransferChannel.h"

static void onMethodCall(FlutterMethodCall* call, FlutterResult result);

static NSMutableDictionary *uploadInfo(DIMUploadRequest *request) {
    NSDictionary *info;
    if ([request isKindOfClass:[DIMUploadTask class]]) {
        DIMUploadTask *task = (DIMUploadTask *)request;
        info = @{
            @"api": [task.url absoluteString],
            @"name": task.name,
            @"filename": task.filename,
        };
    } else {
        info = @{
            @"api": [request.url absoluteString],
            @"name": request.name,
            @"path": request.path,
            @"sender": [request.sender string],
        };
    }
    return [info mutableCopy];
}

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

#pragma mark DIMUploadDelegate

- (void)uploadTask:(__kindof DIMUploadRequest *)req onSuccess:(NSURL *)url {
    NSLog(@"onUploadSuccess: %@, url: %@", req, url);
    NSMutableDictionary *params = uploadInfo(req);
    [params setObject:@{
        @"url": [url absoluteString],
    } forKey:@"response"];
    [self invokeMethod:kChannelMethod_OnUploadSuccess arguments:params];
}

- (void)uploadTask:(__kindof DIMUploadRequest *)req onFailed:(NSException *)error {
    NSLog(@"onUploadFailed: %@, error: %@", req, error);
    NSMutableDictionary *params = uploadInfo(req);
    [params setObject:[error description] forKey:@"error"];
    [self invokeMethod:kChannelMethod_OnUploadFailure arguments:params];
}

- (void)uploadTask:(__kindof DIMUploadRequest *)req onError:(NSError *)error {
    NSLog(@"onUploadError: %@, error: %@", req, error);
    NSMutableDictionary *params = uploadInfo(req);
    [params setObject:[error description] forKey:@"error"];
    [self invokeMethod:kChannelMethod_OnUploadFailure arguments:params];
}

#pragma mark DIMDownloadDelegate

- (void)downloadTask:(__kindof DIMDownloadRequest *)req onSuccess:(NSString *)path {
    NSLog(@"onDownloadSuccess: %@, path: %@", req, path);
    NSDictionary *params = @{
        @"url": [req.url absoluteString],
        @"path": path,
    };
    [self invokeMethod:kChannelMethod_OnDownloadSuccess arguments:params];
}

- (void)downloadTask:(__kindof DIMDownloadRequest *)req onFailed:(NSException *)error {
    NSLog(@"onDownloadFailed: %@, error: %@", req, error);
    NSDictionary *params = @{
        @"url": [req.url absoluteString],
        @"path": req.path,
        @"error": [error description],
    };
    [self invokeMethod:kChannelMethod_OnDownloadFailure arguments:params];
}

- (void)downloadTask:(__kindof DIMDownloadRequest *)req onError:(NSError *)error {
    NSLog(@"onDownloadFailed: %@, error: %@", req, error);
    NSDictionary *params = @{
        @"url": [req.url absoluteString],
        @"path": req.path,
        @"error": [error description],
    };
    [self invokeMethod:kChannelMethod_OnDownloadFailure arguments:params];
}


@end

static inline void onMethodCall(FlutterMethodCall* call, FlutterResult success) {
    DIMFileTransfer *ftp = [DIMFileTransfer sharedInstance];
    NSString *method = [call method];
    if ([method isEqualToString:kChannelMethod_DownloadFile]) {
        // downloadEncryptedFile
        NSURL *url = [NSURL URLWithString:[call.arguments objectForKey:@"url"]];
        NSString *path = [ftp downloadEncryptedData:url];
        success(path);
    } else if ([method isEqualToString:kChannelMethod_DownloadAvatar]) {
        // downloadAvatar
        NSURL *url = [NSURL URLWithString:[call.arguments objectForKey:@"url"]];
        NSString *path = [ftp downloadAvatar:url];
        success(path);
    } else if ([method isEqualToString:kChannelMethod_UploadFile]) {
        // uploadEncryptFile
        FlutterStandardTypedData *data = [call.arguments objectForKey:@"data"];
        NSString *filename = [call.arguments objectForKey:@"filename"];
        id<MKMID> sender = MKMIDParse([call.arguments objectForKey:@"sender"]);
        NSURL *url = [ftp uploadEncryptedData:[data data] filename:filename sender:sender];
        success([url absoluteString]);
    } else if ([method isEqualToString:kChannelMethod_UploadAvatar]) {
        // uploadAvatar
        FlutterStandardTypedData *data = [call.arguments objectForKey:@"data"];
        NSString *filename = [call.arguments objectForKey:@"filename"];
        id<MKMID> sender = MKMIDParse([call.arguments objectForKey:@"sender"]);
        NSURL *url = [ftp uploadAvatar:[data data] filename:filename sender:sender];
        success([url absoluteString]);
    } else if ([method isEqualToString:kChannelMethod_SetUploadAPI]) {
        // setUploadAPI
        NSString *api = [call.arguments objectForKey:@"api"];
        NSString *secret = [call.arguments objectForKey:@"secret"];
        if (api) {
            ftp.api = api;
        }
        if (secret) {
            ftp.secret = secret;
        }
        success(nil);
    } else if ([method isEqualToString:kChannelMethod_GetCachesDirectory]) {
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
