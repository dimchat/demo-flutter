//
//  EMAudioPlayerHelper.h
//  Sechat
//
//  Created by Albert Moky on 2018/12/24.
//  Copyright © 2018 DIM Group. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface EMAudioPlayerHelper : NSObject

@property (nonatomic, strong) id model;
@property (nonatomic, strong, nullable) NSString *playingPath;
@property (readwrite, nonatomic) BOOL isPlaying;

+ (instancetype)sharedHelper;

- (void)startPlayerWithPath:(NSString *)aPath
                      model:(id)aModel
                 completion:(void(^)(NSError *error))aCompleton;

- (void)stopPlayer;

@end

NS_ASSUME_NONNULL_END
