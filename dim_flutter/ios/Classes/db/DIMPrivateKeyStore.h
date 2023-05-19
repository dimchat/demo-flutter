//
//  DIMPrivateKeyStore.h
//  Runner
//
//  Created by Albert Moky on 2023/5/16.
//

#import <DIMClient/DIMClient.h>

NS_ASSUME_NONNULL_BEGIN

@interface DIMPrivateKeyStore : NSObject <DIMPrivateKeyDBI>

+ (instancetype)sharedInstance;

@end

NS_ASSUME_NONNULL_END
