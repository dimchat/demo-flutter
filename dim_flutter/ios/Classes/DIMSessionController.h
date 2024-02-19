//
//  DIMSessionController.h
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

@interface DIMPushNotificationController : NSObject <UIApplicationDelegate, UNUserNotificationCenterDelegate>

@property(nonatomic, readonly) NSData *deviceToken;

+ (instancetype)sharedInstance;

// callback after handshake accepted
- (void)reportDeviceToken;

@end

NS_ASSUME_NONNULL_END
