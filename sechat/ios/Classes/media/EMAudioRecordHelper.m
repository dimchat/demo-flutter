//
//  EMAudioRecordHelper.m
//  Sechat
//
//  Created by Albert Moky on 2018/12/24.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

#import "EMAudioRecordHelper.h"

static EMAudioRecordHelper *recordHelper = nil;
@interface EMAudioRecordHelper()<AVAudioRecorderDelegate>

@property (nonatomic, strong) NSDate *startDate;
@property (nonatomic, strong) NSDate *endDate;

@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) NSDictionary *recordSetting;

@property (nonatomic, copy) void (^recordFinished)(NSString *aPath, NSInteger aTimeLength);

@end


@implementation EMAudioRecordHelper

+ (instancetype)sharedHelper
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        recordHelper = [[EMAudioRecordHelper alloc] init];
    });
    
    return recordHelper;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _recordSetting = @{AVSampleRateKey:@(44100), AVFormatIDKey:@(kAudioFormatLinearPCM), AVLinearPCMBitDepthKey:@(16), AVNumberOfChannelsKey:@(1), AVEncoderAudioQualityKey:@(AVAudioQualityHigh), AVEncoderBitRateKey: @(96000)};
        
    }
    
    return self;
}

- (void)dealloc
{
    [self _stopRecord];
}

#pragma mark - AVAudioRecorderDelegate

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder
                           successfully:(BOOL)flag
{
    NSInteger timeLength = [[NSDate date] timeIntervalSinceDate:self.startDate];
    NSString *recordPath = [[self.recorder url] path];
    if (self.recordFinished) {
        if (!flag) {
            recordPath = nil;
        }
        
        self.recordFinished(recordPath, timeLength);
    }
    self.recorder = nil;
    self.recordFinished = nil;
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder
                                   error:(NSError *)error{
    NSLog(@"audioRecorderEncodeErrorDidOccur");
}

#pragma mark - Private

- (void)_stopRecord
{
    _recorder.delegate = nil;
    if (_recorder.recording) {
        [_recorder stop];
    }
    _recorder = nil;
    self.recordFinished = nil;
}

#pragma mark - Public

- (AVAudioSessionRecordPermission)currentRecordPermission
{
    return [AVAudioSession sharedInstance].recordPermission;
}

- (void)requestRecordPermissionCompletion:(void(^)(BOOL granted))aCompletion
{
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session requestRecordPermission:aCompletion];
}

- (void)startRecordWithPath:(NSString *)aPath
                 completion:(void(^)(NSError *error))aCompletion
{
    NSError *error = nil;
    do {
        if (self.recorder && self.recorder.isRecording) {
            error = [NSError errorWithDomain:@"正在进行录制" code:-1 userInfo:nil];
            break;
        }
        
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:&error];
        if (!error){
            [[AVAudioSession sharedInstance] setActive:YES error:&error];
        }
        
        if (error) {
            error = [NSError errorWithDomain:@"AVAudioSession SetCategory失败" code:-1 userInfo:nil];
            break;
        }
        
        NSString *wavPath = [[aPath stringByDeletingPathExtension] stringByAppendingPathExtension:@"caf"];
        NSURL *wavUrl = [[NSURL alloc] initFileURLWithPath:wavPath];
        self.recorder = [[AVAudioRecorder alloc] initWithURL:wavUrl settings:self.recordSetting error:&error];
        if(error || !self.recorder) {
            self.recorder = nil;
            error = [NSError errorWithDomain:@"文件格式转换失败" code:-1 userInfo:nil];
            break;
        }
        
        BOOL ret = [self.recorder prepareToRecord];
        if (ret) {
            self.startDate = [NSDate date];
            self.recorder.meteringEnabled = YES;
            self.recorder.delegate = self;
            ret = [self.recorder record];
        }
        
        if (!ret) {
            [self _stopRecord];
            error = [NSError errorWithDomain:@"准备录制工作失败" code:-1 userInfo:nil];
        }
        
    } while (0);
    
    if (aCompletion) {
        aCompletion(error);
    }
}

-(void)stopRecordWithCompletion:(void(^)(NSString *aPath, NSInteger aTimeLength))aCompletion
{
    self.recordFinished = aCompletion;
    [self.recorder stop];
}

-(void)cancelRecord
{
    [self _stopRecord];
    self.startDate = nil;
    self.endDate = nil;
}

@end
