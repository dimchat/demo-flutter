//
//  SharedSession.m
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import "ChannelManager.h"
#import "SessionChannel.h"
#import "MarsHub.h"

#import "SharedSession.h"

@implementation SharedSession

// Override
- (STStreamHub *)createHubForRemoteAddress:(id<NIOSocketAddress>)remote
                             socketChannel:(NIOSocketChannel *)sock
                                  delegate:(id<STConnectionDelegate>)gate {
    return [[MarsHub alloc] initWithConnectionDelegate:gate];
}

@end

@implementation SharedSession (Process)

- (NSArray<NSData *> *)processData:(NSData *)pack
                        fromRemote:(id<NIOSocketAddress>)source {
    NSLog(@"pack length: %lu", pack.length);
    ChannelManager *man = [ChannelManager sharedInstance];
    SessionChannel *channel = [man sessionChannel];
    [channel onReceivedData:pack from:source];
    return @[];
}

@end

#pragma mark -

@implementation SessionController

OKSingletonImplementations(SessionController, sharedInstance)

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
    cs = [[SharedSession alloc] initWithDatabase:self.database station:station];
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

#pragma mark - DIMSessionStateDelegate

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
    }
    // callback for flutter
    ChannelManager *man = [ChannelManager sharedInstance];
    SessionChannel *channel = [man sessionChannel];
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
