//
//  DIMSessionController.h
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <DIMClient/DIMClient.h>

NS_ASSUME_NONNULL_BEGIN

typedef DIMClientSession *_Nonnull(^DIMSessionCreator)(id<DIMSessionDBI> db,
                                                       id<MKMStation> server);

@interface DIMSessionController : NSObject <DIMSessionStateDelegate>

@property(nonatomic, strong) id<DIMSessionDBI> database;

@property(nonatomic, strong) DIMCommonFacebook *facebook;

@property(nonatomic, strong, nullable) DIMClientSession *session;

@property(nonatomic, assign) DIMSessionCreator creator;

+ (instancetype)sharedInstance;

- (void)connectToHost:(NSString *)host port:(UInt16)port;

- (BOOL)loginWithUser:(id<MKMID>)user;

- (void)setSessionKey:(NSString *)session;

- (DIMSessionState *)state;

@end

@interface DIMPushNotificationController : NSObject <UIApplicationDelegate, UNUserNotificationCenterDelegate>

@property(nonatomic, readonly) NSData *deviceToken;

+ (instancetype)sharedInstance;

// callback after handshake accepted
- (void)reportDeviceToken;

@end

NS_ASSUME_NONNULL_END
