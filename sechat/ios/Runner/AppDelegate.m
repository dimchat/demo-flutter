
#import "SharedSession.h"

#import "GeneratedPluginRegistrant.h"

#import "AppDelegate.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    FlutterViewController* controller;
    controller = (FlutterViewController*)[self.window rootViewController];
    
    // init method channels with flutter
    DIMChannelManager *manager = [DIMChannelManager sharedInstance];
    [manager initChannels:controller.binaryMessenger];
    
    // client session creator
    DIMSessionController *sc = [DIMSessionController sharedInstance];
    sc.creator = ^DIMClientSession *(id<DIMSessionDBI> db, id<MKMStation>  server) {
        return [[SharedSession alloc] initWithDatabase:db station:server];
    };
    
    // load plugins
    [DIMClientFacebook prepare];
    
    // query device token
    DIMPushNotificationController *pnc = [DIMPushNotificationController sharedInstance];
    [pnc application:application didFinishLaunchingWithOptions:launchOptions];
    
    [GeneratedPluginRegistrant registerWithRegistry:self];
    // Override point for customization after application launch.
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"APNs didFailToRegisterForRemoteNotificationsWithError: %@", error);
    DIMPushNotificationController *apns = [DIMPushNotificationController sharedInstance];
    [apns application:application didFailToRegisterForRemoteNotificationsWithError:error];
    [super application:application didFailToRegisterForRemoteNotificationsWithError:error];
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSLog(@"APNs didRegisterForRemoteNotificationsWithDeviceToken: %@", deviceToken);
    DIMPushNotificationController *apns = [DIMPushNotificationController sharedInstance];
    [apns application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
    [super application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    NSLog(@"APNs applicationDidBecomeActive");
    DIMPushNotificationController *apns = [DIMPushNotificationController sharedInstance];
    [apns applicationDidBecomeActive:application];
    [super applicationDidBecomeActive:application];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center willPresentNotification:(UNNotification *)notification withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    NSLog(@"APNs willPresentNotification: %@", notification);
    DIMPushNotificationController *apns = [DIMPushNotificationController sharedInstance];
    [apns userNotificationCenter:center willPresentNotification:notification withCompletionHandler:completionHandler];
    [super userNotificationCenter:center willPresentNotification:notification withCompletionHandler:completionHandler];
}

@end
