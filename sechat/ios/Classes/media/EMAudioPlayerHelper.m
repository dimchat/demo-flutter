//
//  EMAudioPlayerHelper.m
//  Sechat
//
//  Created by Albert Moky on 2018/12/24.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#import "EMAudioPlayerHelper.h"

static EMAudioPlayerHelper *playerHelper = nil;
@interface EMAudioPlayerHelper()<AVAudioPlayerDelegate>

@property (nonatomic, strong) AVAudioPlayer *player;
@property (nonatomic, copy) void (^playerFinished)(NSError *error);

@end

@implementation EMAudioPlayerHelper

+ (instancetype)sharedHelper
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        playerHelper = [[EMAudioPlayerHelper alloc] init];
    });

    return playerHelper;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
    }

    return self;
}

- (void)dealloc
{
    [self stopPlayer];
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player
                       successfully:(BOOL)flag
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIDeviceProximityStateDidChangeNotification object:nil];
    [UIDevice currentDevice].proximityMonitoringEnabled = NO;

    if (self.playerFinished) {
        self.playerFinished(nil);
    }

    self.playerFinished = nil;
    if (_player) {
        _player.delegate = nil;
        _player = nil;
    }
}

-(BOOL)isPlaying{
    return self.player.playing;
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player
                                 error:(NSError *)error
{
    if (self.playerFinished) {
        NSError *error = [NSError errorWithDomain:@"播放失败!" code:-1 userInfo:nil];
        self.playerFinished(error);
    }

    self.playerFinished = nil;
    if (_player) {
        _player.delegate = nil;
        _player = nil;
    }
}

#pragma mark - Private

// 处理监听触发事件
- (void)sensorStateChange:(NSNotificationCenter *)notification
{
    if ([[UIDevice currentDevice] proximityState] == YES) {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    } else {
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    }
}

#pragma mark - Public

- (void)startPlayerWithPath:(NSString *)aPath
                      model:(id)aModel
                 completion:(void(^)(NSError *error))aCompleton
{
    NSError *error = nil;
    do {
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:aPath]) {
            error = [NSError errorWithDomain:@"文件路径不存在" code:-1 userInfo:nil];
            break;
        }

        if (self.player && self.player.isPlaying && [self.playingPath isEqualToString:aPath]) {
            break;
        } else {
            [self stopPlayer];
        }

        //aPath = [self _convertAudioFile:aPath];
        if ([aPath length] == 0) {
            error = [NSError errorWithDomain:@"转换音频格式失败" code:-1 userInfo:nil];
            break;
        }

        self.model = aModel;

        NSURL *wavUrl = [[NSURL alloc] initFileURLWithPath:aPath];
        self.player = [[AVAudioPlayer alloc] initWithContentsOfURL:wavUrl error:&error];
        if (error || !self.player) {
            self.player = nil;
            error = [NSError errorWithDomain:@"初始化AVAudioPlayer失败" code:-1 userInfo:nil];
            break;
        }

        self.playingPath = aPath;
        [self setPlayerFinished:aCompleton];

        self.player.delegate = self;

        [UIDevice currentDevice].proximityMonitoringEnabled = YES;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sensorStateChange:) name:UIDeviceProximityStateDidChangeNotification object:nil];

        BOOL ret = [self.player prepareToPlay];
        if (ret) {
            AVAudioSession *audioSession = [AVAudioSession sharedInstance];
            [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
            if (error) {
                break;
            }
        }

        ret = [self.player play];
        if (!ret) {
            [self stopPlayer];
            error = [NSError errorWithDomain:@"AVAudioPlayer播放失败" code:-1 userInfo:nil];
        }

    } while (0);

    if (error) {
        if (aCompleton) {
            NSLog(@"语音播放错误，startPlayerWithPath: %@", error.localizedDescription);
            aCompleton(error);
        }
    }
}

- (void)stopPlayer
{
    [UIDevice currentDevice].proximityMonitoringEnabled = NO;
    
    if(_player) {
        _player.delegate = nil;
        [_player stop];
        _player = nil;
    }

    self.playingPath = nil;
    self.playerFinished = nil;
}

@end
