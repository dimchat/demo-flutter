//
//  ChannelManager.m
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import <DIMClient/DIMClient.h>

#import "AudioChannel.h"
#import "SessionChannel.h"
#import "FileTransferChannel.h"

#import "ChannelManager.h"

@interface ChannelManager ()

@property(nonatomic, strong) AudioChannel *audioChannel;
@property(nonatomic, strong) SessionChannel *sessionChannel;
@property(nonatomic, strong) FileTransferChannel *ftpChannel;

@end

@implementation ChannelManager

OKSingletonImplementations(ChannelManager, sharedInstance)

- (instancetype)init {
    if (self = [super init]) {
        self.sessionChannel = nil;
        self.ftpChannel = nil;
    }
    return self;
}

- (void)initChannels:(NSObject<FlutterBinaryMessenger>*)messenger {
    // FIXME: BigDecimal
    FlutterStandardReaderWriter *rw = [[FlutterStandardReaderWriter alloc] init];
    FlutterStandardMethodCodec *codec;
    codec = [FlutterStandardMethodCodec codecWithReaderWriter:rw];
    
    self.audioChannel = [AudioChannel channelWithName:ChannelNameAudio
                                      binaryMessenger:messenger
                                                codec:codec];
    self.sessionChannel = [SessionChannel channelWithName:ChannelNameSession
                                          binaryMessenger:messenger
                                                    codec:codec];
    self.ftpChannel = [FileTransferChannel channelWithName:ChannelNameFileTransfer
                                           binaryMessenger:messenger
                                                     codec:codec];
}

@end