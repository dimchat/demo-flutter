//
//  DIMSessionController.m
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import <ObjectKey/ObjectKey.h>

#import "DIMChannelManager.h"
#import "DIMSessionChannel.h"

#import "DIMSessionController.h"

static inline NSString *device_model(void) {
    // @"iPhone", @"iPad", @"iPod touch"
    return [[UIDevice currentDevice] model];
}
static inline NSString *device_system(void) {
    // @"iPadOS 16.3"
    NSString *name = [[UIDevice currentDevice] systemName];
    NSString *version = [[UIDevice currentDevice] systemVersion];
    return [NSString stringWithFormat:@"%@ %@", name, version];
}
static inline NSString *bundle_id(void) {
    // @"chat.dim.sechat"
    return [[NSBundle mainBundle] bundleIdentifier];
}
static inline BOOL is_sandbox(void) {
#if DEBUG
    return YES;
#else
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSLog(@"appStoreReceiptURL: %@", receiptURL);
    return [receiptURL.path hasSuffix:@"sandboxReceipt"];
#endif
}

#define DIMCommand_Report  @"report"
#define DIMCommand_Online  @"online"
#define DIMCommand_Offline @"offline"

@interface DIMPushNotificationController () {
    
    bool _sent;
}

@property(nonatomic, strong) NSData *deviceToken;

@end

@implementation DIMPushNotificationController

OKSingletonImplementations(DIMPushNotificationController, sharedInstance)

- (instancetype)init {
    if (self = [super init]) {
        _sent = NO;
    }
    return self;
}

- (void)reportDeviceToken {
    if (_sent) {
        NSLog(@"APNs: only report once time");
        return;
    }
    NSData *token = [self deviceToken];
    if ([token length] == 0) {
        NSLog(@"APNs: device token not found");
        return;
    }
    NSString *hex = MKMHexEncode(token);
    //DIMReportCommand *content = [[DIMReportCommand alloc] initWithTitle:@"apns"];
    DIMCommand *content = [[DIMCommand alloc] initWithCommandName:DIMCommand_Report];
    [content setObject:@"apns" forKey:@"title"];
    [content setObject:hex forKey:@"device_token"];
    [content setObject:@"iOS" forKey:@"platform"];
    [content setObject:device_system() forKey:@"system"];
    [content setObject:device_model() forKey:@"model"];
    [content setObject:bundle_id() forKey:@"topic"];
    if (is_sandbox()) {
        // development
        [content setObject:@(YES) forKey:@"sandbox"];
    }
    id<MKMID> receiver = MKMIDParse(@"apns@anywhere");
    NSLog(@"APNs report command: %@ => %@", content, receiver);
    DIMChannelManager *man = [DIMChannelManager sharedInstance];
    DIMSessionChannel *channel = [man sessionChannel];
    [channel sendCommand:content receiver:receiver];
    _sent = YES;
}

#pragma mark UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(nullable NSDictionary<UIApplicationLaunchOptionsKey, id> *)launchOptions  {
    
    // request permission
    UNUserNotificationCenter *center;
    center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = self;
    UNAuthorizationOptions type;
    type = UNAuthorizationOptionBadge|UNAuthorizationOptionSound|UNAuthorizationOptionAlert;
    [center requestAuthorizationWithOptions:type
                          completionHandler:^(BOOL granted, NSError *error) {
        NSLog(@"APNs granted: %u, error: %@", granted, error);
    }];
    // query for device token
    [application registerForRemoteNotifications];

    return YES;
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"APNs register failed: %@", error);
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    if ([deviceToken isKindOfClass:[NSData class]]) {
        NSLog(@"APNs token: %@", deviceToken);
        self.deviceToken = deviceToken;
        [self reportDeviceToken];
    } else {
        NSLog(@"APNs token error: %@", deviceToken);
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    UNUserNotificationCenter *center;
    center = [UNUserNotificationCenter currentNotificationCenter];
    [center removeAllDeliveredNotifications];
    application.applicationIconBadgeNumber = -1;
    NSLog(@"APNs: notifications cleared on become active");
}

- (void)applicationWillResignActive:(UIApplication *)application {
    UNUserNotificationCenter *center;
    center = [UNUserNotificationCenter currentNotificationCenter];
    [center removeAllDeliveredNotifications];
    application.applicationIconBadgeNumber = -1;
    NSLog(@"APNs: notifications cleared on resign active");
}

#pragma mark UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    UNNotificationRequest *request = [notification request];
    UNNotificationContent *content = [request content];
    UNNotificationTrigger *trigger = [request trigger];
    NSLog(@"APNs received push content: %@", content);
    if ([trigger isKindOfClass:[UNPushNotificationTrigger class]]) {
        // TODO: process remote content
    }
    UNNotificationPresentationOptions type;
    type = UNAuthorizationOptionBadge|UNAuthorizationOptionSound|UNAuthorizationOptionAlert;
    completionHandler(type);
}

@end
