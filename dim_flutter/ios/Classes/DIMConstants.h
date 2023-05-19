//
//  DIMConstants.h
//  Sechat
//
//  Created by Albert Moky on 2023/5/9.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString * const kNotificationName_ServerStateChanged;

extern NSString * const kNotificationName_ConversationUpdated;
extern NSString * const kNotificationName_MessageInserted;

extern NSString * const kNotificationName_MessageSent;
extern NSString * const kNotificationName_SendMessageFailed;

extern NSString * const kNotificationName_MessageRemoved;
extern NSString * const kNotificationName_MessageWithdrawed;
extern NSString * const kNotificationName_MessageCleaned;

extern NSString * const kNotificationName_MetaSaved;
extern NSString * const kNotificationName_DocumentUpdated;
extern NSString * const kNotificationName_ContactsUpdated;
extern NSString * const kNotificationName_GroupMembersUpdated;

extern NSString * const kNotificationName_FileUploaded;
extern NSString * const kNotificationName_FileUploadFailed;
extern NSString * const kNotificationName_FileDownloaded;
extern NSString * const kNotificationName_FileDownloadFailed;

NS_ASSUME_NONNULL_END
