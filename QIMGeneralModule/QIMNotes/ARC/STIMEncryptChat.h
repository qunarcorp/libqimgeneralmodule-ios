//
//  STIMEncryptChatView.h
//  qunarChatIphone
//
//  Created by 李露 on 2017/9/5.
//
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@class STIMMessageModel;
typedef enum : NSUInteger {
    STIMEncryptChatStateNone = 0,
    STIMEncryptChatStateEncrypting,
    STIMEncryptChatStateDecrypted,
} STIMEncryptChatState;

typedef enum : NSUInteger {
    STIMEncryptChatDirectionSent = 0,
    STIMEncryptChatDirectionReceived,
} STIMEncryptChatDirection;

@protocol STIMEncryptChatReloadViewDelegate <NSObject>

- (void)reloadBaseViewWithUserId:(NSString *)userId WithEncryptChatState:(STIMEncryptChatState)encryptChatState;

@end

@class STIMNoteManager;
@interface STIMEncryptChat : NSObject

+ (instancetype)sharedInstance;

@property (nonatomic, weak) id <STIMEncryptChatReloadViewDelegate> delegate;


/**
 做一些跟加密解密相关的操作

 @param userId 用户Id
 */

- (void)doSomeEncryptChatWithUserId:(NSString *)userId;
- (void)closeEncrypt;
- (void)cancelDescrpytChat;

#pragma mark - EncryptChatState

- (STIMEncryptChatState)getEncryptChatStateWithUserId:(NSString *)userId;

#pragma mark - Setter SecurityTime

- (void)setEncryptChatLeaveTimeWithUserId:(NSString *)userId
                                 WithTime:(NSTimeInterval)leftTime;

- (NSTimeInterval)getEncryptChatLeaveTimeWithUserId:(NSString *)userId;

#pragma mark - Encrypt Message

- (NSString *)encryptMessageWithMsgType:(NSInteger)msgType WithOriginBody:(NSString *)body WithOriginExtendInfo:(NSString *)extendInfo WithUserId:(NSString *)userId;

#pragma mark - DeCrypt Message

/**
 解密得到MessageType
 */
- (NSInteger)getMessageTypeWithEncryptMsg:(STIMMessageModel *)msg WithUserId:(NSString *)userId;

/**
 解密得到MessageBody
 */
- (NSString *)getMessageBodyWithEncryptMsg:(STIMMessageModel *)msg WithUserId:(NSString *)userId;

/**
 解密得到MessageExtendInfo
 */
- (NSString *)getMessageExtendInfoWithEncryptMsg:(STIMMessageModel *)msg WithUserId:(NSString *)userId;

@end
