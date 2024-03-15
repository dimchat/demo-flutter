//
//  DIMFileTransfer.m
//  Sechat
//
//  Created by Albert Moky on 2019/9/6.
//  Copyright © 2019 DIM Group. All rights reserved.
//

#import <ObjectKey/ObjectKey.h>
#import <DIMCore/DIMCore.h>
#import <DIMPlugins/DIMPlugins.h>

#import "DIMFileTransfer.h"

#pragma mark - DIMContentFactory.m

@interface DIMContentFactory () {
    
    DIMContentParserBlock _block;
}

@end

@implementation DIMContentFactory

- (instancetype)init {
    NSAssert(false, @"don't call me!");
    DIMContentParserBlock block = NULL;
    return [self initWithBlock:block];
}

/* NS_DESIGNATED_INITIALIZER */
- (instancetype)initWithBlock:(DIMContentParserBlock)block {
    if (self = [super init]) {
        _block = block;
    }
    return self;
}

- (nullable id<DKDContent>)parseContent:(NSDictionary *)content {
    return _block(content);
}

@end

void DIMRegisterContentFactories(void) {
    
    // Text
    DIMContentRegisterClass(DKDContentType_Text, DIMTextContent);
    
    // File
    DIMContentRegisterClass(DKDContentType_File, DIMFileContent);
    // Image
    DIMContentRegisterClass(DKDContentType_Image, DIMImageContent);
    // Audio
    DIMContentRegisterClass(DKDContentType_Audio, DIMAudioContent);
    // Video
    DIMContentRegisterClass(DKDContentType_Video, DIMVideoContent);
    
    // Web Page
    DIMContentRegisterClass(DKDContentType_Page, DIMPageContent);
    
    // Name Card
    DIMContentRegisterClass(DKDContentType_NameCard, DIMNameCard);
    
    // Money
    DIMContentRegisterClass(DKDContentType_Money, DIMMoneyContent);
    DIMContentRegisterClass(DKDContentType_Transfer, DIMTransferContent);
    
    // Command
    id<DKDContentFactory> cmdParser = [[DIMBaseCommandFactory alloc] init];
    DIMContentRegister(DKDContentType_Command, cmdParser);
    
    // History Command
    id<DKDContentFactory> hisParser = [[DIMHistoryCommandFactory alloc] init];
    DIMContentRegister(DKDContentType_History, hisParser);
    
    /*
    // Application Customized
    DIMContentRegisterClass(DKDContentType_Customized, DIMCustomizedContent);
    DIMContentRegisterClass(DKDContentType_Application, DIMCustomizedContent);
     */
    
    // Content Array
    DIMContentRegisterClass(DKDContentType_Array, DIMArrayContent);

    // Top-Secret
    DIMContentRegisterClass(DKDContentType_Forward, DIMForwardContent);

    // unknown content type
    DIMContentRegisterClass(0, DIMContent);
}

#pragma mark - DIMCommandFactory.m

@interface DIMCommandFactory () {
    
    DIMCommandParserBlock _block;
}

@end

@implementation DIMCommandFactory

- (instancetype)init {
    NSAssert(false, @"don't call me!");
    DIMCommandParserBlock block = NULL;
    return [self initWithBlock:block];
}

/* NS_DESIGNATED_INITIALIZER */
- (instancetype)initWithBlock:(DIMCommandParserBlock)block {
    if (self = [super init]) {
        _block = block;
    }
    return self;
}

- (nullable id<DKDCommand>)parseCommand:(NSDictionary *)content {
    return _block(content);
}

@end

@implementation DIMBaseCommandFactory

- (nullable id<DKDContent>)parseContent:(NSDictionary *)content {
    DIMCommandFactoryManager *man = [DIMCommandFactoryManager sharedManager];
    // get factory by command name
    NSString *cmd = [man.generalFactory getCmd:content defaultValue:@"*"];
    id<DKDCommandFactory> factory = [man.generalFactory commandFactoryForName:cmd];
    if (!factory) {
        // check for group commands
        if ([content objectForKey:@"group"]
            /*&& ![cmd isEqualToString:@"group"]*/) {
            factory = [man.generalFactory commandFactoryForName:@"group"];
        }
        if (!factory) {
            factory = self;
        }
    }
    return [factory parseCommand:content];
}

- (nullable id<DKDCommand>)parseCommand:(NSDictionary *)content {
    return [[DIMCommand alloc] initWithDictionary:content];
}

@end

@implementation DIMHistoryCommandFactory

- (nullable id<DKDCommand>)parseCommand:(NSDictionary *)content {
    return [[DIMHistoryCommand alloc] initWithDictionary:content];
}

@end

@implementation DIMGroupCommandFactory

- (nullable id<DKDContent>)parseContent:(NSDictionary *)content {
    DIMCommandFactoryManager *man = [DIMCommandFactoryManager sharedManager];
    // get factory by command name
    NSString *cmd = [man.generalFactory getCmd:content defaultValue:@"*"];
    id<DKDCommandFactory> factory = [man.generalFactory commandFactoryForName:cmd];
    if (!factory) {
        factory = self;
    }
    return [factory parseCommand:content];
}

- (nullable id<DKDCommand>)parseCommand:(NSDictionary *)content {
    return [[DIMGroupCommand alloc] initWithDictionary:content];
}

@end

void DIMRegisterCommandFactories(void) {

    // Meta Command
    DIMCommandRegisterClass(DIMCommand_Meta, DIMMetaCommand);

    // Document Command
    DIMCommandRegisterClass(DIMCommand_Document, DIMDocumentCommand);
    
    // Receipt Command
    DIMCommandRegisterClass(DIMCommand_Receipt, DIMReceiptCommand);

    // Group Commands
    DIMCommandRegister(@"group", [[DIMGroupCommandFactory alloc] init]);
    DIMCommandRegisterClass(DIMGroupCommand_Invite, DIMInviteGroupCommand);
    // 'expel' is deprecated (use 'reset' instead)
    DIMCommandRegisterClass(DIMGroupCommand_Expel, DIMExpelGroupCommand);
    DIMCommandRegisterClass(DIMGroupCommand_Join, DIMJoinGroupCommand);
    DIMCommandRegisterClass(DIMGroupCommand_Quit, DIMQuitGroupCommand);
    DIMCommandRegisterClass(DIMGroupCommand_Query, DIMQueryGroupCommand);
    DIMCommandRegisterClass(DIMGroupCommand_Reset, DIMResetGroupCommand);
    // Group Admin Commands
    // TODO:
}

#pragma mark -

void DIMRegisterAllFactories(void) {
    //
    //  Register core factories
    //
//    DIMRegisterMessageFactories();
    DIMRegisterContentFactories();
    DIMRegisterCommandFactories();
    
    //
    //  Register customized factories
    //
    DIMContentRegisterClass(DKDContentType_Customized, DIMCustomizedContent);
    DIMContentRegisterClass(DKDContentType_Application, DIMCustomizedContent);
}

@implementation DIMRegister

+ (void)prepare {
    OKSingletonDispatchOnce(^{

        // load plugins
        [MKMPlugins loadPlugins];

        // load message/content factories
        DIMRegisterAllFactories();  // core factories

    });
}

@end

@implementation DIMClientFacebook

+ (void)prepare {
    [DIMRegister prepare];
}

@end
