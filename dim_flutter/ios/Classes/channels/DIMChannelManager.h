//
//  DIMChannelManager.h
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

//
//  Channnel Names
//
#define kChannelName_Audio          @"chat.dim/audio"
#define kChannelName_Session        @"chat.dim/session"
#define kChannelName_FileTransfer   @"chat.dim/ftp"
#define kChannelName_Database       @"chat.dim/db"


//
//  Audio Channel Methods
//
#define kChannelMethod_StartRecord                @"startRecord"
#define kChannelMethod_StopRecord                 @"stopRecord"
#define kChannelMethod_StartPlay                  @"startPlay"
#define kChannelMethod_StopPlay                   @"stopPlay"

#define kChannelMethod_OnRecordFinished           @"onRecordFinished"
#define kChannelMethod_OnPlayFinished             @"onPlayFinished"

//
//  Session Channel Methods
//
#define kChannelMethod_Connect                    @"connect"
#define kChannelMethod_Login                      @"login"
#define kChannelMethod_SetSessionKey              @"setSessionKey"
#define kChannelMethod_GetState                   @"getState"
#define kChannelMethod_SendMessagePack            @"queueMessagePackage"

#define kChannelMethod_OnStateChanged             @"onStateChanged"
#define kChannelMethod_OnReceived                 @"onReceived"

#define kChannelMethod_OnEnterBackground          @"onEnterBackground"
#define kChannelMethod_OnEnterForeground          @"onEnterForeground"

#define kChannelMethod_SendContent                @"sendContent"
#define kChannelMethod_SendCommand                @"sendCommand"

#define kChannelMethod_PackData                   @"packData"
#define kChannelMethod_UnpackData                 @"unpackData"

//
//  FTP Channel Methods
//
#define kChannelMethod_SetUploadAPI               @"setUploadAPI"

#define kChannelMethod_UploadAvatar               @"uploadAvatar"
#define kChannelMethod_UploadFile                 @"uploadEncryptFile"
#define kChannelMethod_DownloadAvatar             @"downloadAvatar"
#define kChannelMethod_DownloadFile               @"downloadEncryptedFile"

#define kChannelMethod_OnUploadSuccess            @"onUploadSuccess"
#define kChannelMethod_OnUploadFailure            @"onUploadFailed"
#define kChannelMethod_OnDownloadSuccess          @"onDownloadSuccess"
#define kChannelMethod_OnDownloadFailure          @"onDownloadFailed"

#define kChannelMethod_GetCachesDirectory         @"getCachesDirectory"
#define kChannelMethod_GetTemporaryDirectory      @"getTemporaryDirectory"


//
//  Database Channel Methods
//
#define kChannelMethod_SavePrivateKey             @"savePrivateKey"
#define kChannelMethod_PrivateKeyForSignature     @"privateKeyForSignature"
#define kChannelMethod_PrivateKeyForVisaSignature @"privateKeyForVisaSignature"
#define kChannelMethod_PrivateKeysForDecryption   @"privateKeysForDecryption"


@class DIMAudioChannel;
@class DIMSessionChannel;
@class DIMFileTransferChannel;
@class DIMDatabaseChannel;


@interface DIMChannelManager : NSObject

@property(nonatomic, readonly) DIMAudioChannel *audioChannel;
@property(nonatomic, readonly) DIMSessionChannel *sessionChannel;
@property(nonatomic, readonly) DIMFileTransferChannel *ftpChannel;
@property(nonatomic, readonly) DIMDatabaseChannel *dbChannel;

+ (instancetype)sharedInstance;

- (void)initChannels:(NSObject<FlutterBinaryMessenger>*)messenger;

@end

NS_ASSUME_NONNULL_END
