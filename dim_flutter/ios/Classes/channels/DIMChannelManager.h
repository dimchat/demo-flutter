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
#define kChannelMethod_SendContent                @"sendContent"
#define kChannelMethod_SendCommand                @"sendCommand"

//
//  FTP Channel Methods
//
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
