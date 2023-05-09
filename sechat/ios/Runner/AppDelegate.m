#import <DIMClient/DIMClient.h>

#import "ChannelManager.h"

#import "GeneratedPluginRegistrant.h"

#import "AppDelegate.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    FlutterViewController* controller;
    controller = (FlutterViewController*)[self.window rootViewController];
    
    ChannelManager *manager = [ChannelManager sharedInstance];
    [manager initChannels:controller.binaryMessenger];
    
    [DIMClientFacebook prepare];
    
    [GeneratedPluginRegistrant registerWithRegistry:self];
    // Override point for customization after application launch.
    return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
