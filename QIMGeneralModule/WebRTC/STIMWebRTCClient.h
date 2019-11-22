//
//  STIMWebRTCClient.h
//  ChatDemo
//
//  Created by Harvey on 16/5/30.
//  Copyright © 2016年 Mac. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "STIMRTCSingleView.h"
#import "STIMRTCNSNotification.h"

@interface STIMWebRTCClient : NSObject

@property(strong, nonatomic) STIMRTCSingleView *rtcView;

@property(copy, nonatomic) NSString *myJID;  /**< 自己的JID */
@property(copy, nonatomic) NSString *remoteJID;    /**< 对方JID */
@property(copy, nonatomic) NSString *remoteResource;

+ (instancetype)sharedInstance;

- (void)startEngine;

- (void)stopEngine;

- (BOOL)calling;

- (void)showRTCViewByXmppId:(NSString *)remoteName isVideo:(BOOL)isVideo isCaller:(BOOL)isCaller;

- (void)resizeViews;

- (void)changeViews;

- (void)callBusy;

@end
