//
//  ChannelManager.h
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

//
//  Channnel Names
//
#define ChannelNameAudio                @"chat.dim/audio"
#define ChannelNameSession              @"chat.dim/session"
#define ChannelNameFileTransfer         @"chat.dim/ftp"


//
//  Audio Channel Methods
//
#define AudioChannelStartRecord         @"startRecord"
#define AudioChannelStopRecord          @"stopRecord"
#define AudioChannelStartPlay           @"startPlay"
#define AudioChannelStopPlay            @"stopPlay"

#define AudioChannelOnRecordFinished    @"onRecordFinished"
#define AudioChannelOnPlayFinished      @"onPlayFinished"

//
//  Session Channel Methods
//
#define SessionChannelConnect           @"connect"
#define SessionChannelLogin             @"login"
#define SessionChannelSetSessionKey     @"setSessionKey"
#define SessionChannelGetState          @"getState"
#define SessionChannelSendMessagePack   @"queueMessagePackage"

#define SessionChannelOnStateChanged    @"onStateChanged"
#define SessionChannelOnReceived        @"onReceived"

#define SessionChannelPackData          @"packData"
#define SessionChannelUnpackData        @"unpackData"

//
//  FTP Channel Methods
//
#define FtpChannelSetUploadAPI          @"setUploadAPI"

#define FtpChannelUploadAvatar          @"uploadAvatar"
#define FtpChannelUploadFile            @"uploadEncryptFile"
#define FtpChannelDownloadAvatar        @"downloadAvatar"
#define FtpChannelDownloadFile          @"downloadEncryptedFile"

#define FtpChannelOnUploadSuccess       @"onUploadSuccess"
#define FtpChannelOnUploadFailure       @"onUploadFailed"
#define FtpChannelOnDownloadSuccess     @"onDownloadSuccess"
#define FtpChannelOnDownloadFailure     @"onDownloadFailed"


@class AudioChannel;
@class SessionChannel;
@class FileTransferChannel;


@interface ChannelManager : NSObject

@property(nonatomic, readonly) AudioChannel *audioChannel;
@property(nonatomic, readonly) SessionChannel *sessionChannel;
@property(nonatomic, readonly) FileTransferChannel *ftpChannel;

+ (instancetype)sharedInstance;

- (void)initChannels:(NSObject<FlutterBinaryMessenger>*)messenger;

@end

NS_ASSUME_NONNULL_END
