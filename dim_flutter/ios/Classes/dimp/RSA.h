//
//  RSA.h
//  Sechat
//
//  Created by Albert Moky on 2025/4/24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RSAKeyStore : NSObject

+ (nullable NSDictionary *)loadKeyWithIdentifier:(NSString *)identifier;

+ (BOOL)saveKeyWithIdentifier:(NSString *)identifier key:(NSDictionary *)info;

@end

NS_ASSUME_NONNULL_END
