//
//  DIMFileTransfer.h
//  Sechat
//
//  Created by Albert Moky on 2019/9/6.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import <DIMCore/DIMCore.h>

#pragma mark - DIMContentFactory.h

NS_ASSUME_NONNULL_BEGIN

typedef id<DKDContent>_Nullable(^DIMContentParserBlock)(NSDictionary *content);

/**
 *  Base Content Factory
 *  ~~~~~~~~~~~~~~~~~~~~
 */
@interface DIMContentFactory : NSObject <DKDContentFactory>

@property (readonly, nonatomic, nullable) DIMContentParserBlock block;

- (instancetype)initWithBlock:(DIMContentParserBlock)block
NS_DESIGNATED_INITIALIZER;

@end

#define DIMContentFactoryWithBlock(block)                                      \
            [[DIMContentFactory alloc] initWithBlock:(block)]                  \
                                   /* EOF 'DIMContentFactoryWithBlock(block)' */

#define DIMContentFactoryWithClass(clazz)                                      \
            DIMContentFactoryWithBlock(^(NSDictionary *content) {              \
                return [[clazz alloc] initWithDictionary:content];             \
            })                                                                 \
                                   /* EOF 'DIMContentFactoryWithClass(clazz)' */

#define DIMContentRegister(type, factory)                                      \
            DKDContentSetFactory(type, factory)                                \
                            /* EOF 'DIMContentFactoryRegister(type, factory)' */

#define DIMContentRegisterBlock(type, block)                                   \
            DKDContentSetFactory((type), DIMContentFactoryWithBlock(block))    \
                                /* EOF 'DIMContentRegisterBlock(type, block)' */

#define DIMContentRegisterClass(type, clazz)                                   \
            DKDContentSetFactory((type), DIMContentFactoryWithClass(clazz))    \
                                /* EOF 'DIMContentRegisterClass(type, clazz)' */

#ifdef __cplusplus
extern "C" {
#endif

/**
 *  Register Core Content Factories
 */
void DIMRegisterContentFactories(void);

#ifdef __cplusplus
} /* end of extern "C" */
#endif

NS_ASSUME_NONNULL_END

#pragma mark - DIMCommandFactory.h

NS_ASSUME_NONNULL_BEGIN

typedef id<DKDCommand>_Nullable(^DIMCommandParserBlock)(NSDictionary *content);

/**
 *  Base Command Factory
 *  ~~~~~~~~~~~~~~~~~~~~
 */
@interface DIMCommandFactory : NSObject <DKDCommandFactory>

@property (readonly, nonatomic) DIMCommandParserBlock block;

- (instancetype)initWithBlock:(DIMCommandParserBlock)block
NS_DESIGNATED_INITIALIZER;

@end

#define DIMCommandFactoryWithBlock(block)                                      \
            [[DIMCommandFactory alloc] initWithBlock:(block)]                  \
                                   /* EOF 'DIMCommandFactoryWithBlock(block)' */

#define DIMCommandFactoryWithClass(clazz)                                      \
            DIMCommandFactoryWithBlock(^(NSDictionary *content) {              \
                return [[clazz alloc] initWithDictionary:content];             \
            })                                                                 \
                                   /* EOF 'DIMCommandFactoryWithClass(clazz)' */

#define DIMCommandRegister(name, factory)                                      \
            DKDCommandSetFactory(name, factory)                                \
                            /* EOF 'DIMCommandRegister(name, factory)' */

#define DIMCommandRegisterBlock(name, block)                                   \
            DKDCommandSetFactory((name), DIMCommandFactoryWithBlock(block))    \
                                /* EOF 'DIMCommandRegisterBlock(name, block)' */

#define DIMCommandRegisterClass(name, clazz)                                   \
            DKDCommandSetFactory((name), DIMCommandFactoryWithClass(clazz))    \
                                /* EOF 'DIMCommandRegisterClass(name, clazz)' */

#ifdef __cplusplus
extern "C" {
#endif

/**
 *  Register Core Command Factories
 */
void DIMRegisterCommandFactories(void);

#ifdef __cplusplus
} /* end of extern "C" */
#endif

#pragma mark -

@interface DIMBaseCommandFactory : NSObject <DKDContentFactory, DKDCommandFactory>

@end

@interface DIMHistoryCommandFactory : DIMBaseCommandFactory

@end

@interface DIMGroupCommandFactory : DIMHistoryCommandFactory

@end

NS_ASSUME_NONNULL_END

#pragma mark -

NS_ASSUME_NONNULL_BEGIN

@interface DIMRegister : NSObject

+ (void)prepare;

@end

@interface DIMClientFacebook : NSObject

+ (void)prepare;

@end

NS_ASSUME_NONNULL_END
