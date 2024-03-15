//
//  DIMChannelManager.m
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import <ObjectKey/ObjectKey.h>

#import "DIMAudioChannel.h"
#import "DIMSessionChannel.h"
#import "DIMFileTransferChannel.h"
#import "DIMDatabaseChannel.h"

#import "DIMChannelManager.h"

@interface DIMChannelManager ()

@property(nonatomic, strong) DIMAudioChannel *audioChannel;
@property(nonatomic, strong) DIMSessionChannel *sessionChannel;
@property(nonatomic, strong) DIMFileTransferChannel *ftpChannel;
@property(nonatomic, strong) DIMDatabaseChannel *dbChannel;

@end

@implementation DIMChannelManager

OKSingletonImplementations(DIMChannelManager, sharedInstance)

- (instancetype)init {
    if (self = [super init]) {
        self.audioChannel = nil;
        self.sessionChannel = nil;
        self.ftpChannel = nil;
        self.dbChannel = nil;
    }
    return self;
}

- (void)initChannels:(NSObject<FlutterBinaryMessenger>*)messenger {
    // FIXME: BigDecimal
    FlutterStandardReaderWriter *rw = [[FlutterStandardReaderWriter alloc] init];
    FlutterStandardMethodCodec *codec;
    codec = [FlutterStandardMethodCodec codecWithReaderWriter:rw];
    
    self.audioChannel = [DIMAudioChannel channelWithName:kChannelName_Audio
                                      binaryMessenger:messenger
                                                codec:codec];
    self.sessionChannel = [DIMSessionChannel channelWithName:kChannelName_Session
                                             binaryMessenger:messenger
                                                       codec:codec];
    self.ftpChannel = [DIMFileTransferChannel channelWithName:kChannelName_FileTransfer
                                           binaryMessenger:messenger
                                                     codec:codec];
    self.dbChannel = [DIMDatabaseChannel channelWithName:kChannelName_Database
                                      binaryMessenger:messenger
                                                codec:codec];
}

@end
