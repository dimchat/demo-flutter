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
#define ChannelNameDatabase             @"chat.dim/db"


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

#define FtpChannelGetCachesDirectory    @"getCachesDirectory"
#define FtpChannelGetTemporaryDirectory @"getTemporaryDirectory"


//
//  Database Channel Methods
//
#define DbChannelSavePrivateKey             @"savePrivateKey"
#define DbChannelPrivateKeyForSignature     @"privateKeyForSignature"
#define DbChannelPrivateKeyForVisaSignature @"privateKeyForVisaSignature"
#define DbChannelPrivateKeysForDecryption   @"privateKeysForDecryption"


@class AudioChannel;
@class SessionChannel;
@class FileTransferChannel;
@class DatabaseChannel;


@interface ChannelManager : NSObject

@property(nonatomic, readonly) AudioChannel *audioChannel;
@property(nonatomic, readonly) SessionChannel *sessionChannel;
@property(nonatomic, readonly) FileTransferChannel *ftpChannel;
@property(nonatomic, readonly) DatabaseChannel *dbChannel;

+ (instancetype)sharedInstance;

- (void)initChannels:(NSObject<FlutterBinaryMessenger>*)messenger;

@end

NS_ASSUME_NONNULL_END
