//
//  DIMAudioChannel.m
//  Sechat
//
//  Created by Albert Moky on 2023/5/12.
//

#import <AVFoundation/AVFoundation.h>

#import "DIMStorage.h"

#import "EMAudioPlayerHelper.h"
#import "EMAudioRecordHelper.h"
#import "DIMChannelManager.h"

#import "DIMAudioChannel.h"

static void onMethodCall(FlutterMethodCall* call, FlutterResult result);

@implementation DIMAudioChannel

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

- (void)onRecordFinished:(NSString *)mp4Path duration:(Float64)seconds {
    NSData *data = [[NSData alloc] initWithContentsOfFile:mp4Path];
    NSDictionary *params = @{
        @"data": [FlutterStandardTypedData typedDataWithBytes:data],
        @"current": @(seconds),
    };
    NSLog(@"Audio channel: %@, method: %@", self, kChannelMethod_OnRecordFinished);
    [self invokeMethod:kChannelMethod_OnRecordFinished arguments:params];
}

- (void)onPlayFinished:(NSString *)mp4Path {
    NSDictionary *params = @{
        @"path": mp4Path,
    };
    NSLog(@"Audio channel: %@, method: %@", self, kChannelMethod_OnPlayFinished);
    [self invokeMethod:kChannelMethod_OnPlayFinished arguments:params];
}

@end

static inline void startRecord(void) {
    NSString *dir = [DIMStorage temporaryDirectory];
    NSString *path = [dir stringByAppendingPathComponent:@"voice"];
    EMAudioRecordHelper *recorder = [EMAudioRecordHelper sharedHelper];
    [recorder startRecordWithPath:path completion:^(NSError *error) {
        if (error == nil) {
            NSLog(@"Now start to record %@", path);
        } else {
            NSLog(@"Recording can not start, error : %@", error);
        }
    }];
}

static inline void stopRecord(void) {
    EMAudioRecordHelper *recorder = [EMAudioRecordHelper sharedHelper];
    [recorder stopRecordWithCompletion:^(NSString *path, NSInteger duration) {
        NSString *dir = [DIMStorage temporaryDirectory];
        NSString *mp4Path = [dir stringByAppendingPathComponent:@"voice.mp4"];
        [DIMStorage removeItemAtPath:mp4Path];
        NSLog(@"Convert audio file %@ => %@", path, mp4Path);
        AVAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:path]];
        NSString *preset = AVAssetExportPresetMediumQuality;
        AVAssetExportSession *session;
        session = [[AVAssetExportSession alloc] initWithAsset:asset presetName:preset];
        session.outputFileType = AVFileTypeMPEG4;
        session.metadata = asset.metadata;
        session.outputURL = [NSURL fileURLWithPath:mp4Path];
        [session exportAsynchronouslyWithCompletionHandler:^{
            if (session.status == AVAssetExportSessionStatusCompleted) {
                NSLog(@"AV Export success");
                Float64 duration = CMTimeGetSeconds(asset.duration);
                DIMChannelManager *man = [DIMChannelManager sharedInstance];
                [man.audioChannel onRecordFinished:mp4Path duration:duration];
            } else if (session.status == AVAssetExportSessionStatusCancelled) {
                NSLog(@"AV Export success");
            } else {
                NSLog(@"AV Export error %@", session.error);
            }
        }];
    }];
}

static inline void startPlay(NSString *path) {
    DIMChannelManager *man = [DIMChannelManager sharedInstance];
    EMAudioPlayerHelper *player = [EMAudioPlayerHelper sharedHelper];
    if ([player isPlaying]) {
        NSString *old = [player playingPath];
        [player stopPlayer];
        [man.audioChannel onPlayFinished:old];
    }
    if ([DIMStorage fileExistsAtPath:path]) {
        NSLog(@"Start play: %@", path);
    } else {
        NSLog(@"Audio file not exists: %@", path);
        return;
    }
    [player startPlayerWithPath:path
                          model:man.audioChannel
                     completion:^(NSError *error) {
        [man.audioChannel onPlayFinished:path];
        if (error == nil) {
            NSLog(@"Audio finished: %@", path);
        } else {
            NSLog(@"Audio error %@, %@", error, path);
        }
    }];
}

static inline void stopPlay(NSString *path) {
    EMAudioPlayerHelper *player = [EMAudioPlayerHelper sharedHelper];
    if ([player isPlaying]) {
        [player stopPlayer];
    }
}

static inline void onMethodCall(FlutterMethodCall* call, FlutterResult success) {
    NSString *method = [call method];
    if ([method isEqualToString:kChannelMethod_StartRecord]) {
        // startRecord
        startRecord();
        success(nil);
    } else if ([method isEqualToString:kChannelMethod_StopRecord]) {
        // stopRecord
        stopRecord();
        success(nil);
    } else if ([method isEqualToString:kChannelMethod_StartPlay]) {
        // startPlay
        NSString *path = [call.arguments objectForKey:@"path"];
        startPlay(path);
        success(nil);
    } else if ([method isEqualToString:kChannelMethod_StopPlay]) {
        // stopPlay
        NSString *path = [call.arguments objectForKey:@"path"];
        stopPlay(path);
        success(nil);
    } else {
        NSLog(@"not implemented: %@", method);
        assert(false);
    }
}
