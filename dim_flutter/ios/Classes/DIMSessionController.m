//
//  DIMSessionController.m
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import "DIMChannelManager.h"
#import "DIMSessionChannel.h"

#import "DIMSessionController.h"

@implementation DIMSessionController

OKSingletonImplementations(DIMSessionController, sharedInstance)

- (instancetype)init {
    if (self = [super init]) {
        //self.session = nil;
    }
    return self;
}

- (void)connectToHost:(NSString *)host port:(UInt16)port {
    // 0. check old session
    DIMClientSession *cs = self.session;
    if (cs) {
        DIMStation *station = cs.station;
        NSString *oHost = station.host;
        UInt16 oPort = station.port;
        if (oPort == port && [host isEqualToString:oHost]) {
            DIMSessionState *state = [cs state];
            NSLog(@"checking connection state: %@, %@", station, state);
            if (state.index == DIMSessionStateOrderError) {
                NSLog(@"current station is not connected");
            } else {
                NSLog(@"current station state: %@", state);
                return;
            }
        }
        NSLog(@"connection to %@:%u", host, port);
        [cs stop];
        self.session = nil;
    }
    NSLog(@"connecting to %@:%u", host, port);
    // 1. create station
    DIMStation *station = [[DIMStation alloc] initWithHost:host port:port];
    station.dataSource = self.facebook;
    // 2. create session for station
    cs = self.creator(self.database, station);
    [cs startWithStateDelegate:self];
    self.session = cs;
}

- (BOOL)loginWithUser:(id<MKMID>)user {
    DIMClientSession *cs = [self session];
    return [cs setID:user];
}

- (void)setSessionKey:(NSString *)session {
    DIMClientSession *cs = [self session];
    NSLog(@"set session key: %@, %@", session, cs);
    [cs setKey:session];
}

- (DIMSessionState *)state {
    DIMClientSession *cs = [self session];
    return [cs state];
}

#pragma mark DIMSessionStateDelegate

- (void)machine:(DIMSessionStateMachine *)ctx
     enterState:(nullable DIMSessionState *)next
           time:(NSTimeInterval)now {
    
}

- (void)machine:(DIMSessionStateMachine *)ctx
      exitState:(nullable DIMSessionState *)previous
           time:(NSTimeInterval)now {
    DIMSessionState *current = [ctx currentState];
    NSLog(@"state changed: %@ -> %@", previous, current);
    // check docker for current session
    if (!current) {
        NSLog(@"current state empty, stopped?");
    } else if (current.index == DIMSessionStateOrderConnecting) {
        DIMClientSession *cs = [self session];
        if (!cs) {
            NSLog(@"client session gone");
        } else {
            STCommonGate *gate = [cs gate];
            if (!gate) {
                NSLog(@"failed to open gate: %@", cs.station);
            } else {
                id<NIOSocketAddress> remote = [cs remoteAddress];
                STDocker *docker = [gate dockerForAdvanceParty:@[]
                                                 remoteAddress:remote
                                                  localAddress:nil];
                if (!docker) {
                    NSLog(@"failed to create docker: %@", remote);
                } else {
                    NSLog(@"created docker: %@", docker);
                }
            }
        }
    } else if (current.index == DIMSessionStateOrderRunning) {
        DIMPushNotificationController *pnc = [DIMPushNotificationController sharedInstance];
        [pnc reportDeviceToken];
    }
    // callback for flutter
    DIMChannelManager *man = [DIMChannelManager sharedInstance];
    DIMSessionChannel *channel = [man sessionChannel];
    [channel onStateChangedFrom:previous to:current when:now];
}

- (void)machine:(DIMSessionStateMachine *)ctx
     pauseState:(DIMSessionState *)current
           time:(NSTimeInterval)now {
    
}

- (void)machine:(DIMSessionStateMachine *)ctx
    resumeState:(DIMSessionState *)current
           time:(NSTimeInterval)now {
    
}

@end

#pragma mark -

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
    DIMSessionController *sc = [DIMSessionController sharedInstance];
    DIMSessionState *state = [sc.session state];
    if (state.index != DIMSessionStateOrderRunning) {
        // waiting for handshake accepted
        return;
    }
    NSString *hex = MKMHexEncode(token);
    DIMReportCommand *content = [[DIMReportCommand alloc] initWithTitle:@"apns"];
    [content setObject:hex forKey:@"device_token"];
    // TODO: get platform name
    [content setObject:@"iOS" forKey:@"platform"];
    NSLog(@"APNs report command: %@", content);
    DIMChannelManager *man = [DIMChannelManager sharedInstance];
    DIMSessionChannel *channel = [man sessionChannel];
    [channel sendCommand:content];
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
    NSLog(@"APNs: notifications cleared");
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
