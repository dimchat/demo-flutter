//
//  FileTransferChannel.m
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import <DIMClient/DIMClient.h>

#import "FileTransfer.h"
#import "ChannelManager.h"

#import "FileTransferChannel.h"

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

@implementation FileTransferChannel

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
    [self invokeMethod:FtpChannelOnUploadSuccess arguments:params];
}

- (void)uploadTask:(__kindof DIMUploadRequest *)req onFailed:(NSException *)error {
    NSLog(@"onUploadFailed: %@, error: %@", req, error);
    NSMutableDictionary *params = uploadInfo(req);
    [params setObject:[error description] forKey:@"error"];
    [self invokeMethod:FtpChannelOnUploadFailure arguments:params];
}

- (void)uploadTask:(__kindof DIMUploadRequest *)req onError:(NSError *)error {
    NSLog(@"onUploadError: %@, error: %@", req, error);
    NSMutableDictionary *params = uploadInfo(req);
    [params setObject:[error description] forKey:@"error"];
    [self invokeMethod:FtpChannelOnUploadFailure arguments:params];
}

#pragma mark DIMDownloadDelegate

- (void)downloadTask:(__kindof DIMDownloadRequest *)req onSuccess:(NSString *)path {
    NSLog(@"onDownloadSuccess: %@, path: %@", req, path);
    NSDictionary *params = @{
        @"url": [req.url absoluteString],
        @"path": path,
    };
    [self invokeMethod:FtpChannelOnDownloadSuccess arguments:params];
}

- (void)downloadTask:(__kindof DIMDownloadRequest *)req onFailed:(NSException *)error {
    NSLog(@"onDownloadFailed: %@, error: %@", req, error);
    NSDictionary *params = @{
        @"url": [req.url absoluteString],
        @"path": req.path,
        @"error": [error description],
    };
    [self invokeMethod:FtpChannelOnDownloadFailure arguments:params];
}

- (void)downloadTask:(__kindof DIMDownloadRequest *)req onError:(NSError *)error {
    NSLog(@"onDownloadFailed: %@, error: %@", req, error);
    NSDictionary *params = @{
        @"url": [req.url absoluteString],
        @"path": req.path,
        @"error": [error description],
    };
    [self invokeMethod:FtpChannelOnDownloadFailure arguments:params];
}


@end

static inline void onMethodCall(FlutterMethodCall* call, FlutterResult success) {
    FileTransfer *ftp = [FileTransfer sharedInstance];
    NSString *method = [call method];
    if ([method isEqualToString:FtpChannelDownloadFile]) {
        // downloadEncryptedFile
        NSURL *url = [NSURL URLWithString:[call.arguments objectForKey:@"url"]];
        NSString *path = [ftp downloadEncryptedData:url];
        success(path);
    } else if ([method isEqualToString:FtpChannelDownloadAvatar]) {
        // downloadAvatar
        NSURL *url = [NSURL URLWithString:[call.arguments objectForKey:@"url"]];
        NSString *path = [ftp downloadAvatar:url];
        success(path);
    } else if ([method isEqualToString:FtpChannelUploadFile]) {
        // uploadEncryptFile
        FlutterStandardTypedData *data = [call.arguments objectForKey:@"data"];
        NSString *filename = [call.arguments objectForKey:@"filename"];
        id<MKMID> sender = MKMIDParse([call.arguments objectForKey:@"sender"]);
        NSURL *url = [ftp uploadEncryptedData:[data data] filename:filename sender:sender];
        success([url absoluteString]);
    } else if ([method isEqualToString:FtpChannelUploadAvatar]) {
        // uploadAvatar
        FlutterStandardTypedData *data = [call.arguments objectForKey:@"data"];
        NSString *filename = [call.arguments objectForKey:@"filename"];
        id<MKMID> sender = MKMIDParse([call.arguments objectForKey:@"sender"]);
        NSURL *url = [ftp uploadAvatar:[data data] filename:filename sender:sender];
        success([url absoluteString]);
    } else if ([method isEqualToString:FtpChannelSetUploadAPI]) {
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
    } else if ([method isEqualToString:FtpChannelGetCachesDirectory]) {
        // getCachesDirectory
        NSString *dir = [DIMStorage cachesDirectory];
        success(dir);
    } else if ([method isEqualToString:FtpChannelGetTemporaryDirectory]) {
        // getCachesDirectory
        NSString *dir = [DIMStorage temporaryDirectory];
        success(dir);
    } else {
        NSLog(@"not implemented: %@", method);
        assert(false);
    }
}
