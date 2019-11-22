//
//  STIMNoteManager.h
//  qunarChatIphone
//
//  Created by 李露 on 2017/7/13.
//
//

#import <Foundation/Foundation.h>

#define QTNoteManagerSaveCloudMainSuccessNotification @"QTNoteManagerSaveCloudMainSuccessNotification"
#define QTNoteManagerGetCloudMainSuccessNotification @"QTNoteManagerGetCloudMainSuccessNotification"
#define QTNoteManagerGetCloudMainHistorySuccessNotification  @"QTNoteManagerGetCloudMainHistorySuccessNotification"

#define QTNoteManagerGetCloudSubSuccessNotification  @"QTNoteManagerGetCloudSubSuccessNotification"
#define QTNoteManagerGetCloudSubHistorySuccessNotification  @"QTNoteManagerGetCloudSubHistorySuccessNotification"


#define QTTodolistStateOutOfDate @"QTTodolistStateOutOfDate"
#define QTTodolistStateNormal @"QTTodolistStateNormal"
#define QTTodolistStateComplete @"QTTodolistStateComplete"

//加密会话
#define kNotifyBeginEncryptChat @"kNotifyBeginEncryptChat"
#define kNotifyAgreeEncryptChat @"kNotifyAgreeEncryptChat"
#define kNotifyRefuseEncryptChat @"kNotifyRefuseEncryptChat"
#define kNotifyCancelEncryptChat @"kNotifyCancelEncryptChat"
#define kNotifyCloseEncryptChat @"kNotifyCloseEncryptChat"

@class STIMNoteModel;
typedef enum : NSUInteger {
    STIMNoteTypePassword = 1,
    STIMNoteTypeTodoList = 2,
    STIMNoteTypeEverNote = 3,
    STIMNoteTypeChatPwdBox = 100,
} STIMNoteType;

typedef enum : NSUInteger {
    STIMPasswordTypeText = 1,
    STIMPasswordTypeURL,
    STIMPasswordTypeEmail,
    STIMPasswordTypeAddress,
    STIMPasswordTypeDateTime,
    STIMPasswordTypeYearMonth,
    STIMPasswordTypeOnePassword,
    STIMPasswordTypePassword,
    STIMPasswordTypeTelphone,
} STIMPasswordType;

typedef enum : NSUInteger {
    STIMNoteStateDelete = -1,
    STIMNoteStateNormal = 1,
    STIMNoteStateFavorite,
    STIMNoteStateBasket,
    STIMNoteStateCreate,
    STIMNoteStateUpdate,
} STIMNoteState;

typedef enum : NSUInteger {
    STIMNoteExtendedFlagStateNoNeedUpdatedd = -1,
    STIMNoteExtendedFlagStateLocalCreated = 1,
    STIMNoteExtendedFlagStateLocalModify,
    STIMNoteExtendedFlagStateRemoteUpdated,
} STIMNoteExtendedFlagState;

typedef enum : NSUInteger {
    STIMEncryptMessageType_Begin = 1,
    STIMEncryptMessageType_Agree,
    STIMEncryptMessageType_Refuse,
    STIMEncryptMessageType_Cancel,
    STIMEncryptMessageType_Close,
} STIMEncryptMessageType;

@interface STIMNoteManager : NSObject

+ (STIMNoteManager *)sharedInstance;

@property (nonatomic, copy) NSString *baseUrl;

- (NSString *)getPasswordWithCid:(NSInteger)cid;

- (void)setPassword:(NSString *)password ForCid:(NSInteger)cid;

- (void)setEncryptChatPasswordWithPassword:(NSString *)password ForUserId:(NSString *)userId;

- (NSString *)getEncryptChatPasswordWithUserId:(NSString *)userId;

/***************************Main Local****************************/

/**
 保存新MainItem
 */
- (void)saveNewQTNoteMainItem:(STIMNoteModel *)model;

/**
 更新mainItem
 */
- (void)updateQTNoteMainItemWithModel:(STIMNoteModel *)model;

/**
 删除MainItem
 */
- (void)deleteQTNoteMainItemWithModel:(STIMNoteModel *)model;

/**
 更新MainItem状态值
 */
- (void)updateQTNoteMainItemStateWithModel:(STIMNoteModel *)model;

/**
 根据关键词搜索MainItem
 */
- (NSArray *)getMainItemWithType:(STIMNoteType)type Keywords:(NSString *)keyWords;

/**
 排除某State
 */
- (NSArray *)getMainItemWithType:(STIMNoteType)type WithExceptState:(STIMNoteState)state;

/**
 get某State
 */
- (NSArray *)getMainItemWithType:(STIMNoteType)type State:(STIMNoteState)state;

/**
 读取未更新数据
 */
- (NSArray *)getMainItemWithQExtendedFlag:(STIMNoteExtendedFlagState)qExtendedFlag;

/**
 读取最大MainItem Cid
 */
- (NSInteger)getMaxQTNoteMainItemCid;

/**
 读取MainItem最大Version
 */
- (NSInteger)getQTNoteMainItemMaxTimeWithType:(STIMNoteType)type;


- (NSInteger)getQTNoteSubItemMaxTimeWitModel:(STIMNoteModel *)model;

/**
 根据完成状态读取TodoList
 */
- (NSArray *)getTodoListItemWithCompleteState:(NSString *)completeState;

- (void)batchSyncToRemoteMainItems;

/***************************Sub Local****************************/

/**
 保存新SubItem
 */
- (void)saveNewQTNoteSubItem:(STIMNoteModel *)model;

/**
 更新SubItem
 */
- (void)updateQTNoteSubItemWithQSModel:(STIMNoteModel *)model;

/**
 删除SubItem
 */
- (void)deleteQTNoteSubItemWithQSModel:(STIMNoteModel *)model;

/**
 更新SubItem状态值
 */
- (void)updateQTNoteSubItemStateWithQSModel:(STIMNoteModel *)model;

/**
 读取本地未更新SubItem
 */
- (NSArray *)getSubItemWithCid:(NSInteger)cid WithQSExtendedFlag:(STIMNoteExtendedFlagState)qsExtendedFlag;

- (NSArray *)getSubItemWithCid:(NSInteger)cid WithType:(STIMNoteType)type WithQState:(STIMNoteState)state;

- (NSArray *)getSubItemWithCid:(NSInteger)cid WithType:(STIMNoteType)type WithExpectState:(STIMNoteState)state;

/**
 读取某Cid下State的SubItem
 */
- (NSArray *)getSubItemWithCid:(NSInteger)cid WithState:(STIMNoteState)state;

/**
 排除某Cid下State的SubItem
 */
- (NSArray *)getSubItemWithCid:(NSInteger)cid WithExpectState:(STIMNoteState)state;

/**
 读取某State的SubItem
 */
- (NSArray *)getSubItemWithState:(STIMNoteState)state;

/**
 排除某State的SubItem
 */
- (NSArray *)getSubItemWithExpectState:(STIMNoteState)state;

/**
 读取最大SubItem的本地索引值
 */
- (NSInteger)getMaxQTNoteSubItemCSid;

- (void)batchSyncToRemoteSubItemsWithMainQid:(NSString *)qid;

/***************************Main Remote****************************/

- (void)saveToRemoteMainWithMainItem:(STIMNoteModel *)model;

- (void)updateToRemoteMainWithMainItem:(STIMNoteModel *)model;

- (void)deleteToRemoteMainWithQid:(NSInteger)qid;

- (void)collectToRemoteMainWithQid:(NSInteger)qid;

- (void)cancelCollectToRemoteMainWithQid:(NSInteger)qid;

- (void)moveToRemoteBasketMainWithQid:(NSInteger)qid;

- (void)moveOutRemoteBasketMainWithQid:(NSInteger)qid;

- (void)getCloudRemoteMainWithVersion:(NSInteger)version
                             WithType:(STIMNoteType)type;

- (void)getCloudRemoteMainHistoryWithQId:(NSInteger)qid;

/***************************Sub Remote****************************/

- (void)saveToRemoteSubWithSubModel:(STIMNoteModel *)model;

- (void)updateToRemoteSubWithSubModel:(STIMNoteModel *)model;

- (void)deleteToRemoteSubWithQSid:(NSInteger)qsid;

- (void)collectionToRemoteSubWithQSid:(NSInteger)qsid;

- (void)cancelCollectionToRemoteSubWithQSid:(NSInteger)qsid;

- (void)moveToBasketRemoteSubWithQSid:(NSInteger)qsid;

- (void)moveOutRemoteBasketSubWithQSid:(NSInteger)qsid;

- (void)getCloudRemoteSubWithQid:(NSInteger)qid
                             Cid:(NSInteger)cid
                         version:(NSInteger)version
                            type:(STIMPasswordType)type;

- (NSArray *)getCloudRemoteSubHistoryWithQSid:(NSInteger)qsid;

//get sub evernotes
- (void)getCloudRemoteSubWithQid:(NSInteger)qid
                             Cid:(NSInteger)cid
                         version:(NSInteger)version;

@end

@interface STIMNoteManager (EncryptMessage)

- (void)beginEncryptionSessionWithUserId:(NSString *)userId
                            WithPassword:(NSString *)password;
    
/**
 同意加密会话请求

 @param userId 用户Id
 */
- (void)agreeEncryptSessionWithUserId:(NSString *)userId;


/**
 拒绝加密会话请求

 @param userId 用户Id
 */
- (void)refuseEncryptSessionWithUserId:(NSString *)userId;

    
/**
 取消加密会话请求

 @param userId 用户Id
 */
- (void)cancelEncryptSessionWithUserId:(NSString *)userId;

/**
 关闭加密会话

 @param userId 用户Id
 */
- (void)closeEncryptSessionWithUserId:(NSString *)userId;


- (void)getCloudRemoteEncrypt;

/**
 获取加密会话密码箱

 @return 加密会话密码箱Model
 */
- (STIMNoteModel *)getEncrptPwdBox;


/**
 获取加密会话密码

 @param userId 用户Id
 @param cid cid
 @return 获取对方Id对应的加密会话密码
 */
-  (NSString *)getChatPasswordWithUserId:(NSString *)userId
                                 WithCid:(NSInteger)cid;


/**
 保存加密会话密码

 @param userId 用户Id
 @param password 密码
 @param cid cid
 @return 加密会话密码Model
 */
- (STIMNoteModel *)saveEncryptionPasswordWithUserId:(NSString *)userId
                                     WithPassword:(NSString *)password
                                          WithCid:(NSInteger)cid;

@end
