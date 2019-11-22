//
//  STIMNotifyManager.h
//  qunarChatIphone
//
//  Created by 李露 on 2018/2/26.
//

#import <Foundation/Foundation.h>

@class STIMNotifyView;

@protocol STIMNotifyManagerDelegate <NSObject>

- (void)showGloablNotifyWithView:(STIMNotifyView *)view;

@optional
- (void)showChatNotifyWithView:(STIMNotifyView *)view WithMessage:(NSDictionary *)message;

@end

@interface STIMNotifyManager : NSObject

+ (instancetype)shareNotifyManager;

@property(nonatomic, weak) id <STIMNotifyManagerDelegate> notifyManagerGlobalDelegate;

@property(nonatomic, weak) id <STIMNotifyManagerDelegate> notifyManagerSpecifiedDelegate;


- (void)showGlobalNotifyWithMessage:(NSDictionary *)message;

- (void)showChatNotifyWithMessage:(NSDictionary *)message;

@end
