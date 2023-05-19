//
//  EMAudioRecordHelper.h
//  Sechat
//
//  Created by Albert Moky on 2018/12/24.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMAudioRecordHelper : NSObject

+ (instancetype)sharedHelper;

- (void)requestRecordPermissionCompletion:(void(^)(BOOL granted))aCompletion;
- (void)startRecordWithPath:(NSString *)aPath
                 completion:(void(^)(NSError *error))aCompletion;
- (void)stopRecordWithCompletion:(void(^)(NSString *aPath, NSInteger aTimeLength))aCompletion;

- (void)cancelRecord;

@end

NS_ASSUME_NONNULL_END
