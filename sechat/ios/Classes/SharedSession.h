//
//  SharedSession.h
//  Sechat
//
//  Created by Albert Moky on 2023/5/7.
//

#import <DIMClient/DIMClient.h>

NS_ASSUME_NONNULL_BEGIN

@interface SharedSession : DIMClientSession

@end

#pragma mark -

@interface SessionController : NSObject <DIMSessionStateDelegate>

@property(nonatomic, strong) id<DIMSessionDBI> database;

@property(nonatomic, strong) DIMCommonFacebook *facebook;

@property(nonatomic, strong, nullable) DIMClientSession *session;

+ (instancetype)sharedInstance;

- (void)connectToHost:(NSString *)host port:(UInt16)port;

- (BOOL)loginWithUser:(id<MKMID>)user;

- (void)setSessionKey:(NSString *)session;

- (DIMSessionState *)state;

@end

NS_ASSUME_NONNULL_END
