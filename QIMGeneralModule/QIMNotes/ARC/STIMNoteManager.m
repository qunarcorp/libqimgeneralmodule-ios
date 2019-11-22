//
//  STIMNoteManager.m
//  qunarChatIphone
//
//  Created by 李露 on 2017/7/13.
//
//

#import "STIMNoteManager.h"
#import "STIMNoteModel.h"
#import "STIMJSONSerializer.h"
#import "ASIHTTPRequest.h"
#import "STIMUUIDTools.h"
#import "NSMutableDictionary+STIMSafe.h"
#import "STIMKit+STIMDBDataManager.h"
#import "STIMKit+STIMUserCacheManager.h"
#import "STIMKit.h"
#import "STIMKit+STIMNavConfig.h"
#import "STIMKit+STIMMessage.h"
#import "STIMKit+STIMAppSetting.h"
#import "STIMKit+STIMEncryptChat.h"
#import "STIMNetwork.h"
#import "STIMPublicRedefineHeader.h"
#import "AESCrypt.h"
#import "STIMAES256.h"
#import "NSBundle+STIMLibrary.h"

@interface STIMNoteManager () {
    dispatch_queue_t _loadNoteModelQueue;
}

@property (nonatomic, assign) NSInteger passwordVersion;

@property (nonatomic, strong) NSMutableDictionary *passwordDict;

@property (nonatomic, strong) NSMutableDictionary *encryptPasswordDict;

@end

@interface STIMNoteManager (EverNoteAPI)

- (NSMutableDictionary *)requestHeaders;

#pragma mark - Main Remote API

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

- (void)batchSyncToRemoteMainItemsWithInserts:(NSArray *)inserts updates:(NSArray *)updates;

#pragma mark - Sub Remote API

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

- (void)batchSyncToRemoteSubItemsWithInserts:(NSArray *)inserts updates:(NSArray *)updates;

@end

@interface STIMNoteManager (EncryptMessageAPI)

- (void)receiveEncryptMessage:(NSDictionary *)infoDic;

@end

@implementation STIMNoteManager

+ (void)load {
//    [STIMNoteManager sharedInstance];
}

static STIMNoteManager *__STIMNoteManager = nil;
+ (STIMNoteManager *)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __STIMNoteManager = [[STIMNoteManager alloc] init];
    });
    return __STIMNoteManager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.baseUrl = [[STIMKit sharedInstance] qimNav_QCloudHost];
        if (self.baseUrl.length <= 0) {
            self.baseUrl = @"https://qim.qunar.com/package/qtapi/qcloud/";
        }
        self.passwordVersion = [[[STIMKit sharedInstance] userObjectForKey:@"passwordVerison"] integerValue];
        self.passwordDict = [NSMutableDictionary dictionary];
        _loadNoteModelQueue = dispatch_queue_create("Load NoteModel Queue", DISPATCH_QUEUE_PRIORITY_DEFAULT);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(receiveEncryptMessage:) name:@"kNotifyReceiveEncryptMessage" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getCloudRemoteEncrypt) name:@"kNotifyNotificationGetRemoteEncrypt" object:nil];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)description {
    return @"STIMNoteManager";
}

- (NSString *)getPasswordWithCid:(NSInteger)cid {
    return [_passwordDict objectForKey:@(cid)];
}

- (void)setPassword:(NSString *)password ForCid:(NSInteger)cid{
    if (_passwordDict == nil) {
        _passwordDict = [NSMutableDictionary dictionaryWithCapacity:5];
    }
    if (password && cid) {
        [_passwordDict setObject:password forKey:@(cid)];
    }
    if (password == nil) {
        [_passwordDict removeObjectForKey:@(cid)];
    }
}

- (void)setEncryptChatPasswordWithPassword:(NSString *)password ForUserId:(NSString *)userId {
    if (_encryptPasswordDict == nil) {
        _encryptPasswordDict = [NSMutableDictionary dictionaryWithCapacity:5];
    }
    if (_encryptPasswordDict && userId && password) {
        [_encryptPasswordDict setObject:password forKey:userId];
    }
    if (password == nil && userId) {
        [_encryptPasswordDict removeObjectForKey:userId];
    }
}

- (NSString *)getEncryptChatPasswordWithUserId:(NSString *)userId {
    return [_encryptPasswordDict objectForKey:userId];
}

/***************************Main Local****************************/

/**
 保存新MainItem
 */
- (void)saveNewQTNoteMainItem:(STIMNoteModel *)model {
    
    [[STIMKit sharedInstance] insertQTNotesMainItemWithQId:model.q_id WithCid:model.c_id WithQType:model.q_type WithQTitle:model.q_title WithQIntroduce:model.q_introduce WithQContent:model.q_content WithQTime:model.q_time WithQState:model.q_state WithQExtendedFlag:STIMNoteExtendedFlagStateLocalCreated];
    [self saveToRemoteMainWithMainItem:model];
}

/**
 更新mainItem
 */
- (void)updateQTNoteMainItemWithModel:(STIMNoteModel *)model {
    STIMNoteExtendedFlagState exFlagState = STIMNoteExtendedFlagStateLocalModify;
    if (model.q_ExtendedFlag == STIMNoteExtendedFlagStateLocalCreated) {
        exFlagState = STIMNoteExtendedFlagStateLocalCreated;
    }
    [[STIMKit sharedInstance] updateToMainWithQId:model.q_id WithCid:model.c_id WithQType:model.q_type WithQTitle:model.q_title WithQDescInfo:model.q_introduce WithQContent:model.q_content WithQTime:model.q_time WithQState:model.q_state WithQExtendedFlag:exFlagState];
    [self updateToRemoteMainWithMainItem:model];
}

/**
 删除MainItem
 */
- (void)deleteQTNoteMainItemWithModel:(STIMNoteModel *)model {
    [self deleteToRemoteMainWithQid:model.q_id];
}

/**
 更新MainItem状态值
 */
- (void)updateQTNoteMainItemStateWithModel:(STIMNoteModel *)model {
    STIMNoteExtendedFlagState exFlagState = STIMNoteExtendedFlagStateLocalModify;
    if (model.q_ExtendedFlag == STIMNoteExtendedFlagStateLocalCreated) {
        exFlagState = STIMNoteExtendedFlagStateLocalCreated;
    }
    [[STIMKit sharedInstance] updateMainStateWithQid:model.q_id WithCid:model.c_id WithQState:model.q_state WithQExtendedFlag:exFlagState];
    if (model.q_state == STIMNoteStateFavorite) {
        [self collectToRemoteMainWithQid:model.q_id];
    } else if (model.q_state == STIMNoteStateBasket) {
        [self moveToRemoteBasketMainWithQid:model.q_id];
    } else if (model.q_state == STIMNoteStateDelete) {
        [self deleteToRemoteMainWithQid:model.q_id];
    } else if (model.q_state == STIMNoteStateNormal) {
        [self cancelCollectToRemoteMainWithQid:model.q_id];
        [self moveOutRemoteBasketMainWithQid:model.q_id];
    }
}

/**
 根据关键词搜索MainItem
 */
- (NSArray *)getMainItemWithType:(STIMNoteType)type Keywords:(NSString *)keyWords {
    NSArray *array = [[STIMKit sharedInstance] getQTNotesMainItemWithQType:type QString:keyWords];
    NSMutableArray *models = [NSMutableArray arrayWithCapacity:5];
    for (NSDictionary *dict in array) {
        STIMNoteModel *model = [[STIMNoteModel alloc] init];
        [model setValuesForKeysWithDictionary:dict];
        [models addObject:model];
    }
    return models;
}

- (NSArray *)getMainItemWithType:(STIMNoteType)type WithExceptState:(STIMNoteState)state {
    
    NSArray *array = [[STIMKit sharedInstance] getQTNotesMainItemWithQType:type WithExceptQState:state];
    NSMutableArray *models = [NSMutableArray arrayWithCapacity:5];
    for (NSDictionary *dict in array) {
        STIMNoteModel *model = [[STIMNoteModel alloc] init];
        [model setValuesForKeysWithDictionary:dict];
        [models addObject:model];
    }
    return models;
}

- (NSArray *)getMainItemWithType:(STIMNoteType)type State:(STIMNoteState)state {
    
    NSArray *array = [[STIMKit sharedInstance] getQTNotesMainItemWithQType:type WithQState:state];
    NSMutableArray *models = [NSMutableArray arrayWithCapacity:5];
    for (NSDictionary *dict in array) {
        STIMNoteModel *model = [[STIMNoteModel alloc] init];
        [model setValuesForKeysWithDictionary:dict];
        [models addObject:model];
    }
    return models;
}


- (NSArray *)getMainItemWithQExtendedFlag:(STIMNoteExtendedFlagState)qExtendedFlag {
    NSArray *array = [[STIMKit sharedInstance] getQTNotesMainItemWithQExtendFlag:qExtendedFlag];
    NSMutableArray *models = [NSMutableArray arrayWithCapacity:5];
    for (NSDictionary *dict in array) {
        STIMNoteModel *model = [[STIMNoteModel alloc] init];
        [model setValuesForKeysWithDictionary:dict];
        [models addObject:model];
    }
    return models;
}


- (NSInteger)getMaxQTNoteMainItemCid {
    return [[STIMKit sharedInstance] getMaxQTNoteMainItemCid];
}

- (NSInteger)getQTNoteMainItemMaxTimeWithType:(STIMNoteType)type {
    return [[STIMKit sharedInstance] getQTNoteMainItemMaxTimeWithQType:type];
}

- (NSInteger)getQTNoteSubItemMaxTimeWitModel:(STIMNoteModel *)model {
    return [[STIMKit sharedInstance] getQTNoteSubItemMaxTimeWithCid:model.c_id WithQSType:model.q_type];
}

- (NSArray *)getTodoListItemWithCompleteState:(NSString *)completeState {
    NSArray *array = [[STIMKit sharedInstance] getQTNoteMainItemWithQType:STIMNoteTypeTodoList WithQDescInfo:completeState];
    NSMutableArray *models = [NSMutableArray arrayWithCapacity:5];
    for (NSDictionary *dict in array) {
        STIMNoteModel *model = [[STIMNoteModel alloc] init];
        [model setValuesForKeysWithDictionary:dict];
        [models addObject:model];
    }
    return models;
}

- (void)batchSyncToRemoteMainItems {
    NSArray *needInserts = [[STIMKit sharedInstance] getQTNotesMainItemWithQExtendedFlag:1 needConvertToString:YES];
    NSArray *needUpdates = [[STIMKit sharedInstance] getQTNotesMainItemWithQExtendedFlag:2 needConvertToString:YES];
    if (needInserts.count || needUpdates.count) {
        [self batchSyncToRemoteMainItemsWithInserts:needInserts updates:needUpdates];
    }
}

#pragma mark - Sub Local

- (void)saveNewQTNoteSubItem:(STIMNoteModel *)model {
    if (model.cs_id < 1) {
        model.cs_id = [[STIMKit sharedInstance] getMaxQTNoteSubItemCSid] + 1;
    }
    if (model.qs_time <= 0) {
        model.qs_time = [NSDate timeIntervalSinceReferenceDate];
    }
    [[STIMKit sharedInstance] insertQTNotesSubItemWithCId:model.c_id WithQSId:0 WithCSId:model.cs_id WithQSType:model.qs_type WithQSTitle:model.qs_title WithQSIntroduce:model.qs_introduce WithQSContent:model.qs_content WithQSTime:model.qs_time WithQState:model.qs_state WithQS_ExtendedFlag:STIMNoteExtendedFlagStateLocalCreated];
    STIMVerboseLog(@"saveNewQTNoteSubItem == %@", model);
    
    [self saveToRemoteSubWithSubModel:model];
}

- (void)updateQTNoteSubItemWithQSModel:(STIMNoteModel *)model {
    STIMNoteExtendedFlagState exFlagState = STIMNoteExtendedFlagStateLocalModify;
    if (model.q_ExtendedFlag == STIMNoteExtendedFlagStateLocalCreated) {
        exFlagState = STIMNoteExtendedFlagStateLocalCreated;
    }
    STIMVerboseLog(@"updateQTNoteSubItemWithQSModel == %@", model);
    [[STIMKit sharedInstance] updateToSubWithCid:model.c_id WithQSid:model.qs_id WithCSid:model.cs_id WithQSTitle:model.qs_title WithQSDescInfo:model.qs_introduce WithQSContent:model.qs_content WithQSTime:model.qs_time WithQSState:model.qs_state WithQS_ExtendedFlag:exFlagState];
    [self updateToRemoteSubWithSubModel:model];
}

- (void)deleteQTNoteSubItemWithQSModel:(STIMNoteModel *)model {
    
    [[STIMKit sharedInstance] deleteToSubWithCSId:model.cs_id];
    //[[STIMKit sharedInstance] deleteToSubWithCId:model.c_id];
    [self deleteToRemoteSubWithQSid:model.qs_id];
}

- (void)updateQTNoteSubItemStateWithQSModel:(STIMNoteModel *)model {
    STIMNoteExtendedFlagState exFlagState = STIMNoteExtendedFlagStateLocalModify;
    if (model.q_ExtendedFlag == STIMNoteExtendedFlagStateLocalCreated) {
        exFlagState = STIMNoteExtendedFlagStateLocalCreated;
    }
    [[STIMKit sharedInstance] updateSubStateWithCSId:model.cs_id WithQSState:model.qs_state WithQsExtendedFlag:exFlagState] ;
    if (model.qs_state == STIMNoteStateFavorite) {
        [self collectionToRemoteSubWithQSid:model.qs_id];
    } else if (model.qs_state == STIMNoteStateBasket) {
        [self moveToBasketRemoteSubWithQSid:model.qs_id];
    } else if (model.qs_state == STIMNoteStateDelete) {
        [self deleteToRemoteSubWithQSid:model.qs_id];
    } else if (model.qs_state == STIMNoteStateNormal) {
        [self cancelCollectionToRemoteSubWithQSid:model.qs_id];
        [self moveOutRemoteBasketSubWithQSid:model.qs_id];
    }
}

- (NSArray *)getSubItemWithCid:(NSInteger)cid WithQSExtendedFlag:(STIMNoteExtendedFlagState)qsExtendedFlag {
    NSArray *array = [[STIMKit sharedInstance] getQTNotesSubItemWithCid:cid QSExtendedFlag:qsExtendedFlag];
    NSMutableArray *models = [NSMutableArray arrayWithCapacity:5];
    for (NSDictionary *dict in array) {
        STIMNoteModel *model = [[STIMNoteModel alloc] init];
        [model setValuesForKeysWithDictionary:dict];
        [models addObject:model];
    }
    return models;
}

- (NSArray *)getSubItemWithQSExtendedFlag:(STIMNoteExtendedFlagState)qsExtendedFlag {
//    NSArray *array = [[STIMKit sharedInstance] getQTNotesSubItemWithQSExtendedFlag:qsExtendedFlag needConvertToString:YES];
    NSMutableArray *models = [NSMutableArray arrayWithCapacity:5];
//    for (NSDictionary *dict in array) {
//        STIMNoteModel *model = [[STIMNoteModel alloc] init];
//        [model setValuesForKeysWithDictionary:dict];
//    }
    return models;
}

- (NSArray *)getSubItemWithCid:(NSInteger)cid WithType:(STIMNoteType)type WithQState:(STIMNoteState)state {
    NSArray *array = [[STIMKit sharedInstance] getQTNotesSubItemWithCid:cid WithQSType:type WithQSState:state];
    NSMutableArray *models = [NSMutableArray arrayWithCapacity:5];
    for (NSDictionary *dict in array) {
        STIMNoteModel *model = [[STIMNoteModel alloc] init];
        [model setValuesForKeysWithDictionary:dict];
        [models addObject:model];
    }
    return models;
}

- (NSArray *)getSubItemWithCid:(NSInteger)cid WithType:(STIMNoteType)type WithExpectState:(STIMNoteState)state {
    NSArray *array = [[STIMKit sharedInstance] getQTNotesSubItemWithCid:cid WithQSType:type WithExpectQSState:state];
    NSMutableArray *models = [NSMutableArray arrayWithCapacity:5];
    for (NSDictionary *dict in array) {
        STIMNoteModel *model = [[STIMNoteModel alloc] init];
        [model setValuesForKeysWithDictionary:dict];
        [models addObject:model];
    }
    return models;
}

- (NSArray *)getSubItemWithCid:(NSInteger)cid WithState:(STIMNoteState)state{
    NSArray *array = [[STIMKit sharedInstance] getQTNotesSubItemWithCid:cid WithQSState:state];
    NSMutableArray *models = [NSMutableArray arrayWithCapacity:5];
    for (NSDictionary *dict in array) {
        STIMNoteModel *model = [[STIMNoteModel alloc] init];
        [model setValuesForKeysWithDictionary:dict];
        [models addObject:model];
    }
    return models;
}

- (NSArray *)getSubItemWithCid:(NSInteger)cid WithExpectState:(STIMNoteState)state{
    NSArray *array = [[STIMKit sharedInstance] getQTNotesSubItemWithCid:cid WithExpectQSState:state];
    NSMutableArray *models = [NSMutableArray arrayWithCapacity:5];
    for (NSDictionary *dict in array) {
        STIMNoteModel *model = [[STIMNoteModel alloc] init];
        [model setValuesForKeysWithDictionary:dict];
        [models addObject:model];
    }
    return models;
}

- (NSArray *)getSubItemWithState:(STIMNoteState)state {
    
    NSArray *array = [[STIMKit sharedInstance] getQTNotesSubItemWithQSState:state];
    NSMutableArray *models = [NSMutableArray arrayWithCapacity:5];
    for (NSDictionary *dict in array) {
        STIMNoteModel *model = [[STIMNoteModel alloc] init];
        [model setValuesForKeysWithDictionary:dict];
        [models addObject:model];
    }
    return models;
}

- (NSArray *)getSubItemWithExpectState:(STIMNoteState)state {
    
    NSArray *array = [[STIMKit sharedInstance] getQTNotesSubItemWithExpectQSState:state];
    NSMutableArray *models = [NSMutableArray arrayWithCapacity:5];
    for (NSDictionary *dict in array) {
        STIMNoteModel *model = [[STIMNoteModel alloc] init];
        [model setValuesForKeysWithDictionary:dict];
        [models addObject:model];
    }
    return models;
}


/**
 取子项Model

 @param paramDict 查询的参数列表 ，务必对应数据库表结构 AND 条件语句
 @return 查询出来的Model
 */
- (STIMNoteModel *)getQTNoteSubItemWithParmDict:(NSDictionary *)paramDict {
    NSDictionary *subModelDict = [[STIMKit sharedInstance] getQTNoteSubItemWithParmDict:paramDict];
    if (subModelDict.count > 0) {
        STIMNoteModel *model = [[STIMNoteModel alloc] init];
        [model setValuesForKeysWithDictionary:subModelDict];
        return model;
    }
    return [[STIMNoteModel alloc] init];
}

- (NSInteger)getMaxQTNoteSubItemCSid {
    return [[STIMKit sharedInstance] getMaxQTNoteSubItemCSid];
}

- (void)batchSyncToRemoteSubItemsWithMainQid:(NSString *)qid {
    NSArray *needInserts = [[STIMKit sharedInstance] getQTNotesSubItemWithMainQid:qid WithQSExtendedFlag:STIMNoteExtendedFlagStateLocalCreated needConvertToString:YES];
    NSArray *needUpdates = [[STIMKit sharedInstance] getQTNotesSubItemWithMainQid:qid WithQSExtendedFlag:STIMNoteExtendedFlagStateLocalModify needConvertToString:YES];
    [self batchSyncToRemoteSubItemsWithInserts:needInserts updates:needUpdates];
}

@end

@implementation STIMNoteManager (EverNoteAPI)

- (NSMutableDictionary *)requestHeaders {
    NSMutableDictionary *cookieProperties = [NSMutableDictionary dictionary];
    BOOL debug = [[[STIMKit sharedInstance] userObjectForKey:@"QC_Debug"] boolValue];
    NSString *requesTHeaders = [NSString stringWithFormat:@"p_user=%@;q_ckey=%@", [STIMKit getLastUserName], [[STIMKit sharedInstance] thirdpartKeywithValue]];
    if (debug) {
        [cookieProperties setObject:requesTHeaders forKey:@"Cookie"];
    } else {
        [cookieProperties setObject:requesTHeaders forKey:@"Cookie"];
    }
    return cookieProperties;
}

#pragma mark - Main Remote API

- (void)saveToRemoteMainWithMainItem:(STIMNoteModel *)model {
    if (model.q_ExtendedFlag == STIMNoteExtendedFlagStateNoNeedUpdatedd) {
        return ;
    }
    STIMNoteType type = model.q_type;
    NSString *title = model.q_title ? model.q_title : @"";
    NSString *desc = model.q_introduce ? model.q_introduce : @"";
    NSString *content = model.q_content ? model.q_content : @"";
    NSString *urlStr = [NSString stringWithFormat:@"%@saveToMain.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];

    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"type": @(type), @"title":title?title:@"", @"desc":desc?desc:@"", @"content":content?content:@""};
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        if ([infoDic objectForKey:@"ret"] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
            NSDictionary *data = [infoDic objectForKey:@"data"];
            if (data && ![data isKindOfClass:[NSNull class]]) {
                NSInteger qid = [[data objectForKey:@"qid"] integerValue];
                NSInteger version = [[data objectForKey:@"version"] integerValue];
                
                [[STIMKit sharedInstance] updateToMainWithQId:qid WithCid:model.c_id WithQType:type WithQTitle:title WithQDescInfo:desc WithQContent:content WithQTime:version WithQState:model.q_state WithQExtendedFlag:STIMNoteExtendedFlagStateRemoteUpdated];
            }
        }
    }
}

- (void)updateToRemoteMainWithMainItem:(STIMNoteModel *)model {
    if (model.q_ExtendedFlag == STIMNoteExtendedFlagStateNoNeedUpdatedd) {
        return ;
    }
    NSInteger qid = model.q_id;
    NSString *title = model.q_title ? model.q_title : @"";
    NSString *desc = model.q_introduce ? model.q_introduce : @"";
    NSString *content = model.q_content ? model.q_content : @"";
    NSString *urlStr = [NSString stringWithFormat:@"%@updateMain.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];

    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"qid": @(qid), @"title": title?title:@"", @"desc":desc?desc:@"", @"content":content?content:@""};
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
            NSDictionary *dict = [infoDic objectForKey:@"data"];
            if (data && ![data isKindOfClass:[NSNull class]]) {
                NSInteger resultQid = [[dict objectForKey:@"qid"] integerValue];
                NSInteger version = [[dict objectForKey:@"version"] integerValue];
                [[STIMKit sharedInstance] updateToMainItemTimeWithQId:resultQid WithQTime:version WithQExtendedFlag:STIMNoteExtendedFlagStateRemoteUpdated];
            }
        }
    }
}

/*
 {
 data =     {
 qid = 39;
 version = 1500478329217;
 };
 errcode = 0;
 errmsg = "<null>";
 ret = 1;
 }
 */
- (void)deleteToRemoteMainWithQid:(NSInteger)qid {
    
    NSString *urlStr = [NSString stringWithFormat:@"%@deleteMain.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];

    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"qid": @(qid)};
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
            NSDictionary *dict = [infoDic objectForKey:@"data"];
            if (data && ![data isKindOfClass:[NSNull class]]) {
                NSInteger resultQid = [[dict objectForKey:@"qid"] integerValue];
                NSInteger version = [[dict objectForKey:@"version"] integerValue];
                [[STIMKit sharedInstance] deleteToMainWithQid:resultQid];
            }
        }
    }
}

- (void)collectToRemoteMainWithQid:(NSInteger)qid {

    NSString *urlStr = [NSString stringWithFormat:@"%@collectionMain.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];

    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"qid": @(qid)};
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
            NSDictionary *dict = [infoDic objectForKey:@"data"];
            if (data && ![data isKindOfClass:[NSNull class]]) {
                NSInteger resultQid = [[dict objectForKey:@"qid"] integerValue];
                NSInteger version = [[dict objectForKey:@"version"] integerValue];
                [[STIMKit sharedInstance] updateToMainItemTimeWithQId:resultQid WithQTime:version WithQExtendedFlag:STIMNoteExtendedFlagStateRemoteUpdated];
            }
        }
    }
}

- (void)cancelCollectToRemoteMainWithQid:(NSInteger)qid {
    NSString *urlStr = [NSString stringWithFormat:@"%@cancelCollectionMain.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];

    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"qid": @(qid)};
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
            NSDictionary *dict = [infoDic objectForKey:@"data"];
            if (data && ![data isKindOfClass:[NSNull class]]) {
                NSInteger resultQid = [[dict objectForKey:@"qid"] integerValue];
                NSInteger version = [[dict objectForKey:@"version"] integerValue];
                [[STIMKit sharedInstance] updateToMainItemTimeWithQId:resultQid WithQTime:version WithQExtendedFlag:STIMNoteExtendedFlagStateRemoteUpdated];
            }
        }
    }
}

- (void)moveToRemoteBasketMainWithQid:(NSInteger)qid {

    NSString *urlStr = [NSString stringWithFormat:@"%@moveToBasketMain.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];

    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"qid": @(qid)};
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
            NSDictionary *dict = [infoDic objectForKey:@"data"];
            if (data && ![data isKindOfClass:[NSNull class]]) {
                NSInteger resultQid = [[dict objectForKey:@"qid"] integerValue];
                NSInteger version = [[dict objectForKey:@"version"] integerValue];
                [[STIMKit sharedInstance] updateToMainItemTimeWithQId:resultQid WithQTime:version WithQExtendedFlag:STIMNoteExtendedFlagStateRemoteUpdated];
            }
        }
    }
}

- (void)moveOutRemoteBasketMainWithQid:(NSInteger)qid {

    NSString *urlStr = [NSString stringWithFormat:@"%@moveOutBasketMain.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];

    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"qid": @(qid)};
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
            NSDictionary *dict = [infoDic objectForKey:@"data"];
            if (data && ![data isKindOfClass:[NSNull class]]) {
                NSInteger resultQid = [[dict objectForKey:@"qid"] integerValue];
                NSInteger version = [[dict objectForKey:@"version"] integerValue];
                [[STIMKit sharedInstance] updateToMainItemTimeWithQId:resultQid WithQTime:version WithQExtendedFlag:STIMNoteExtendedFlagStateRemoteUpdated];
            }
        }
    }
}

- (void)getCloudRemoteMainWithVersion:(NSInteger)version
                             WithType:(STIMNoteType)type{
    NSString *urlStr = [NSString stringWithFormat:@"%@getCloudMain.qunar",self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];
    
    NSDictionary *paramDict = @{@"version": @(version), @"type":@(type)};
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    
    STIMHTTPRequest *request = [[STIMHTTPRequest alloc] initWithURL:url];
    [request setHTTPMethod:STIMHTTPMethodPOST];
    [request setHTTPRequestHeaders:[self requestHeaders]];
    [request setHTTPBody:data];
    [STIMHTTPClient sendRequest:request complete:^(STIMHTTPResponse *response) {
        if (response.code == 200) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:response.data error:nil];
                if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
                    NSArray *resultArray = [infoDic objectForKey:@"data"];
                    if (data && ![data isKindOfClass:[NSNull class]]) {
                        for (NSDictionary *dict in resultArray) {
                            NSInteger resultQid = [[dict objectForKey:@"qid"] integerValue];
                            NSInteger resultType = [[dict objectForKey:@"type"] integerValue];
                            NSString *resultTitle = [dict objectForKey:@"title"];
                            NSString *resultDesc = [dict objectForKey:@"desc"];
                            NSString *resultContent = [dict objectForKey:@"content"];
                            NSInteger resultVersion = [[dict objectForKey:@"version"] integerValue];
                            NSInteger resultState = [[dict objectForKey:@"state"] integerValue];
                            if ([[STIMKit sharedInstance] checkExitsMainItemWithQid:resultQid WithCId:0]) {
                                [[STIMKit sharedInstance] updateToMainWithQId:resultQid WithCid:0 WithQType:resultType WithQTitle:resultTitle WithQDescInfo:resultDesc WithQContent:resultContent WithQTime:resultVersion WithQState:resultState WithQExtendedFlag:STIMNoteExtendedFlagStateRemoteUpdated];
                            } else {
                                [[STIMKit sharedInstance] insertQTNotesMainItemWithQId:resultQid WithCid:0 WithQType:resultType WithQTitle:resultTitle WithQIntroduce:resultDesc WithQContent:resultContent WithQTime:resultVersion WithQState:resultState WithQExtendedFlag:STIMNoteExtendedFlagStateRemoteUpdated];
                            }
                            dispatch_async(dispatch_get_main_queue(), ^{
                                [[NSNotificationCenter defaultCenter] postNotificationName:QTNoteManagerGetCloudMainSuccessNotification object:nil];
                            });
                        }
                    }
                }
            });
        }
    } failure:^(NSError *error) {
        
    }];
}

- (void)getCloudRemoteMainHistoryWithQId:(NSInteger)qid{
    __block NSMutableArray *result = nil;
    NSString *urlStr = [NSString stringWithFormat:@"%@getCloudMainHistory.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];
    dispatch_async(_loadNoteModelQueue, ^{

        ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
        [request setRequestMethod:@"POST"];
        [request setUseCookiePersistence:NO];
        [request setRequestHeaders:[self requestHeaders]];
        NSDictionary *paramDict = @{@"qid": @(qid)};
        NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
        [request appendPostData:data];
        [request startSynchronous];
        NSError *error = [request error];
        if (([request responseStatusCode] == 200) && !error ) {
            NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
            if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
                NSArray *resultArray = [infoDic objectForKey:@"data"];
                if (data && ![data isKindOfClass:[NSNull class]]) {
                    if (!result) {
                        result = [NSMutableArray arrayWithCapacity:3];
                    }
                    for (NSDictionary *dict in resultArray) {
                        STIMNoteModel *model = [[STIMNoteModel alloc] init];
                        [model setValuesForKeysWithDictionary:dict];
                        [result addObject:model];
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:QTNoteManagerGetCloudMainHistorySuccessNotification object:nil];
                    });
                }
            }
        }
    });
}

- (void)batchSyncToRemoteMainItemsWithInserts:(NSArray *)inserts updates:(NSArray *)updates {
    NSString *urlStr = [NSString stringWithFormat:@"%@syncCloudMainList.qunar", self.baseUrl];
    NSURL *url = [NSURL URLWithString:urlStr];
    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"insert": inserts.count ? inserts : @[], @"update":updates.count ? updates : @[]};
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
            NSArray *resultArray = [infoDic objectForKey:@"data"];
            if (data && ![data isKindOfClass:[NSNull class]]) {
                [[STIMKit sharedInstance] updateToMainItemWithDicts:resultArray];
            }
        }
    }
}


#pragma mark - Sub Remote API

- (void)saveToRemoteSubWithSubModel:(STIMNoteModel *)model{
    if (model.q_ExtendedFlag == STIMNoteExtendedFlagStateNoNeedUpdatedd) {
        return ;
    }
    STIMNoteModel *mainModel = [[STIMNoteModel alloc] init];
    NSDictionary *mainModelDict = [[STIMKit sharedInstance] getQTNotesMainItemWithCid:model.c_id];
    [mainModel setValuesForKeysWithDictionary:mainModelDict];
    STIMVerboseLog(@"mainModel == %@", mainModel);
    
    NSInteger qid = mainModel.q_id;
    STIMPasswordType type = model.qs_type;
    NSString *title = model.qs_title;
    NSString *descInfo = model.qs_introduce;
    NSString *content = model.qs_content;
    NSString *urlStr = [NSString stringWithFormat:@"%@saveToSub.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];

    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"qid": @(qid), @"type": @(type), @"title": title ? title : @"", @"desc": descInfo ? descInfo : @"", @"content" : content ? content : @""};
    STIMVerboseLog(@"paramDict == %@", paramDict);
    STIMVerboseLog(@"%@", url);
    STIMVerboseLog(@"%@", [self requestHeaders]);
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        STIMVerboseLog(@"infoDic == %@", infoDic);
        if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
            NSDictionary *dict = [infoDic objectForKey:@"data"];
            if (data && ![data isKindOfClass:[NSNull class]]) {
                NSInteger qsid = [[dict objectForKey:@"qsid"] integerValue];
                NSInteger versioin = [[dict objectForKey:@"version"] integerValue];
                [[STIMKit sharedInstance] updateToSubWithCid:model.c_id WithQSid:qsid WithCSid:model.cs_id WithQSTitle:model.qs_title WithQSDescInfo:model.qs_introduce WithQSContent:model.qs_content WithQSTime:versioin WithQSState:model.qs_state WithQS_ExtendedFlag:STIMNoteExtendedFlagStateRemoteUpdated];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:QTNoteManagerSaveCloudMainSuccessNotification object:nil];
                });
            }
        }
    }
}

- (void)updateToRemoteSubWithSubModel:(STIMNoteModel *)model {
    if (model.q_ExtendedFlag == STIMNoteExtendedFlagStateNoNeedUpdatedd) {
        return ;
    }
    NSInteger qsid = model.qs_id;
    STIMPasswordType type = model.qs_type;
    NSString *title = model.qs_title;
    NSString *descInfo = model.qs_introduce;
    NSString *content = model.qs_content;
    NSString *urlStr = [NSString stringWithFormat:@"%@updateSub.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];

    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"qsid": @(qsid), @"type": @(type), @"title": title ? title : @"", @"desc": descInfo ? descInfo : @"", @"content" : content ? content : @""};
    STIMVerboseLog(@"paramDict == %@", paramDict);
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
            NSDictionary *dict = [infoDic objectForKey:@"data"];
            if (data && ![data isKindOfClass:[NSNull class]]) {
                NSInteger resultQSid = [[dict objectForKey:@"qsid"] integerValue];
                NSInteger version = [[dict objectForKey:@"version"] integerValue];
                [[STIMKit sharedInstance] updateToSubItemTimeWithCSId:version WithQSTime:resultQSid WithQsExtendedFlag:STIMNoteExtendedFlagStateRemoteUpdated];
            }
        }
    }
}

- (void)deleteToRemoteSubWithQSid:(NSInteger)qsid {
//    deleteSub.qunar
    NSString *urlStr = [NSString stringWithFormat:@"%@deleteSub.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];

    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"qsid": @(qsid)};
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
//            NSDictionary *dict = [infoDic objectForKey:@"data"];
        }
    }
}

- (void)collectionToRemoteSubWithQSid:(NSInteger)qsid {

    NSString *urlStr = [NSString stringWithFormat:@"%@collectionSub.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];

    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"qsid": @(qsid)};
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
            NSDictionary *dict = [infoDic objectForKey:@"data"];
            if (data && ![data isKindOfClass:[NSNull class]]) {
                NSInteger resultQSid = [[dict objectForKey:@"qsid"] integerValue];
                NSInteger version = [[dict objectForKey:@"version"] integerValue];
                [[STIMKit sharedInstance] updateToSubItemTimeWithCSId:version WithQSTime:resultQSid WithQsExtendedFlag:STIMNoteExtendedFlagStateRemoteUpdated];
            }
        }
    }
}

- (void)cancelCollectionToRemoteSubWithQSid:(NSInteger)qsid {

    NSString *urlStr = [NSString stringWithFormat:@"%@cancelCollectionSub.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];

    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"qsid": @(qsid)};
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
            NSDictionary *dict = [infoDic objectForKey:@"data"];
            if (data && ![data isKindOfClass:[NSNull class]]) {
                NSInteger resultQsid = [[dict objectForKey:@"qsid"] integerValue];
                NSInteger version = [[dict objectForKey:@"version"] integerValue];
                [[STIMKit sharedInstance] updateToSubItemTimeWithCSId:resultQsid WithQSTime:version WithQsExtendedFlag:STIMNoteExtendedFlagStateRemoteUpdated];
            }
        }
    }
}

- (void)moveToBasketRemoteSubWithQSid:(NSInteger)qsid {

    NSString *urlStr = [NSString stringWithFormat:@"%@moveToBasketSub.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];

    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"qsid": @(qsid)};
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
            NSDictionary *dict = [infoDic objectForKey:@"data"];
            if (data && ![data isKindOfClass:[NSNull class]]) {
                NSInteger resultQSid = [[dict objectForKey:@"qsid"] integerValue];
                NSInteger version = [[dict objectForKey:@"version"] integerValue];
                [[STIMKit sharedInstance] updateToSubItemTimeWithCSId:resultQSid WithQSTime:version WithQsExtendedFlag:STIMNoteExtendedFlagStateRemoteUpdated];
            }
        }
    }
}

- (void)moveOutRemoteBasketSubWithQSid:(NSInteger)qsid {

    NSString *urlStr = [NSString stringWithFormat:@"%@moveOutBasketSub.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];

    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"qsid": @(qsid)};
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
            NSDictionary *dict = [infoDic objectForKey:@"data"];
            if (data && ![data isKindOfClass:[NSNull class]]) {
                NSInteger resultQSid = [[dict objectForKey:@"qsid"] integerValue];
                NSInteger version = [[dict objectForKey:@"version"] integerValue];
                [[STIMKit sharedInstance] updateToSubItemTimeWithCSId:resultQSid WithQSTime:version WithQsExtendedFlag:STIMNoteExtendedFlagStateRemoteUpdated];
            }
        }
    }
}

- (void)getCloudRemoteSubWithQid:(NSInteger)qid
                             Cid:(NSInteger)cid
                         version:(NSInteger)version
                            type:(STIMPasswordType)type {
    NSString *urlStr = [NSString stringWithFormat:@"%@getCloudSub.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];
    dispatch_async(_loadNoteModelQueue, ^{

        ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
        [request setRequestMethod:@"POST"];
        [request setUseCookiePersistence:NO];
        [request setRequestHeaders:[self requestHeaders]];
        NSMutableDictionary *paramDic = [NSMutableDictionary dictionary];
        [paramDic setSTIMSafeObject:@(version) forKey:@"version"];
        [paramDic setSTIMSafeObject:@(qid) forKey:@"qid"];
        if (type != -1) {
            [paramDic setSTIMSafeObject:@(type) forKey:@"type"];
        }
        NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDic error:nil];
        [request appendPostData:data];
        [request startSynchronous];
        NSError *error = [request error];
        if (([request responseStatusCode] == 200) && !error ) {
            NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
            if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
                NSArray *resultArray = [infoDic objectForKey:@"data"];
                if (data && ![data isKindOfClass:[NSNull class]]) {
                    for (NSDictionary *dict in resultArray) {
                        NSInteger resultQid = [[dict objectForKey:@"qid"] integerValue];
                        NSInteger resultQsid = [[dict objectForKey:@"qsid"] integerValue];
                        NSString *resultTitle = [dict objectForKey:@"title"];
                        NSInteger resultType = [[dict objectForKey:@"type"] integerValue];
                        NSString *resultContent = [dict objectForKey:@"content"];
                        NSString *resultDesc = [dict objectForKey:@"desc"];
                        NSInteger resultState = [[dict objectForKey:@"state"] integerValue];
                        NSInteger resultVersion = [[dict objectForKey:@"version"] integerValue];
                        
                        STIMNoteModel *model = [self getQTNoteSubItemWithParmDict:@{@"qs_id" : @(resultQsid)}];
                        [[STIMKit sharedInstance] insertQTNotesSubItemWithCId:cid WithQSId:resultQsid WithCSId:model.cs_id WithQSType:resultType WithQSTitle:resultTitle WithQSIntroduce:resultDesc WithQSContent:resultContent WithQSTime:resultVersion WithQState:resultState WithQS_ExtendedFlag:STIMNoteExtendedFlagStateRemoteUpdated];

                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[NSNotificationCenter defaultCenter] postNotificationName:QTNoteManagerGetCloudSubSuccessNotification object:nil];
                        });
                    }
                }
            }
        }
    });
}


- (NSArray *)getCloudRemoteSubHistoryWithQSid:(NSInteger)qsid {

    __block NSMutableArray *result = nil;
    NSString *urlStr = [NSString stringWithFormat:@"%@getCloudSubHistory.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];
    dispatch_async(_loadNoteModelQueue, ^{

        ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
        [request setRequestMethod:@"POST"];
        [request setUseCookiePersistence:NO];
        [request setRequestHeaders:[self requestHeaders]];
        NSDictionary *paramDict = @{@"qsid": @(qsid)};
        NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
        [request appendPostData:data];
        [request startSynchronous];
        NSError *error = [request error];
        if (([request responseStatusCode] == 200) && !error ) {
            NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
            if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
                NSArray *resultArray = [infoDic objectForKey:@"data"];
                if (data && ![data isKindOfClass:[NSNull class]]) {
                    if (!result) {
                        result = [NSMutableArray arrayWithCapacity:3];
                    }
                    for (NSDictionary *dict in resultArray) {
                        STIMNoteModel *model = [[STIMNoteModel alloc] init];
                        [model setValuesForKeysWithDictionary:dict];
                        [result addObject:model];
                    }
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:QTNoteManagerGetCloudSubHistorySuccessNotification object:nil];
                    });
                }
            }
        }
    });
    return result;
}

- (void)batchSyncToRemoteSubItemsWithInserts:(NSArray *)inserts updates:(NSArray *)updates {
    NSString *urlStr = [NSString stringWithFormat:@"%@syncCloudSubList.qunar", self.baseUrl];
    __block NSURL *url = [NSURL URLWithString:urlStr];
    ASIHTTPRequest *request = [[ASIHTTPRequest alloc] initWithURL:url];
    [request setRequestMethod:@"POST"];
    [request setUseCookiePersistence:NO];
    [request setRequestHeaders:[self requestHeaders]];
    NSDictionary *paramDict = @{@"insert": inserts.count ? inserts : @[], @"update":updates.count ? updates : @[]};
    NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:paramDict error:nil];
    [request appendPostData:data];
    [request startSynchronous];
    NSError *error = [request error];
    if (([request responseStatusCode] == 200) && !error ) {
        NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:request.responseData error:nil];
        if ([[infoDic objectForKey:@"ret"] integerValue] && [[infoDic objectForKey:@"errcode"] integerValue] == 0) {
            NSArray *resultArray = [infoDic objectForKey:@"data"];
            if (data && ![data isKindOfClass:[NSNull class]]) {
                [[STIMKit sharedInstance] updateToSubItemWithDicts:resultArray];
            }
        }
    }
}

@end

@implementation STIMNoteManager (EncryptMessage)

- (void)receiveEncryptMessage:(NSNotification *)notify {
    NSDictionary *infoDic = notify.object;
    int type = [[infoDic objectForKey:@"type"] intValue];
    NSString *from = [infoDic objectForKey:@"from"];
    BOOL carbon = [[infoDic objectForKey:@"carbon"] boolValue];
    STIMVerboseLog(@"receiveEncryptMessage : %@", infoDic);
    switch (type) {
        case STIMEncryptMessageType_Begin:
        {
            if (carbon != YES) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotifyBeginEncryptChat object:from userInfo:infoDic];
                });
            }
        }
        break;
        case STIMEncryptMessageType_Agree:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotifyAgreeEncryptChat object:from userInfo:infoDic];
            });
        }
        break;
        case STIMEncryptMessageType_Refuse:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotifyRefuseEncryptChat object:from userInfo:infoDic];
            });
        }
        break;
        case STIMEncryptMessageType_Cancel:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotifyCancelEncryptChat object:from userInfo:infoDic];
            });
        }
        break;
        case STIMEncryptMessageType_Close:
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotifyCloseEncryptChat object:from userInfo:infoDic];
            });
        }
        break;
        default:
        break;
    }
}
    
/**
 开始加密会话请求

 @param userId 用户Id
 @param password 加密会话的密码
 */
- (void)beginEncryptionSessionWithUserId:(NSString *)userId
                            WithPassword:(NSString *)password {
    NSDictionary *dict =  @{@"type":@(1),@"pwd":password};
    NSString *passwordBody = [[STIMJSONSerializer sharedInstance] serializeObject:dict];
    [[STIMKit sharedInstance] sendEncryptionChatWithType:STIMEncryptMessageType_Begin WithBody:passwordBody ToJid:userId];
}
    
/**
 同意加密会话请求
 
 @param userId 用户Id
 */
- (void)agreeEncryptSessionWithUserId:(NSString *)userId {
    [[STIMKit sharedInstance] sendEncryptionChatWithType:STIMEncryptMessageType_Agree WithBody:@"同意" ToJid:userId];
}
    
/**
 拒绝加密会话请求
 
 @param userId 用户Id
 */
- (void)refuseEncryptSessionWithUserId:(NSString *)userId {
    [[STIMKit sharedInstance] sendEncryptionChatWithType:STIMEncryptMessageType_Refuse WithBody:@"拒绝" ToJid:userId];
}
    
/**
 取消加密会话请求
 
 @param userId 用户Id
 */
- (void)cancelEncryptSessionWithUserId:(NSString *)userId {
    [[STIMKit sharedInstance] sendEncryptionChatWithType:STIMEncryptMessageType_Cancel WithBody:[NSBundle stimDB_localizedStringForKey:@"Cancel"] ToJid:userId];
}
    
/**
 关闭加密会话
 
 @param userId 用户Id
 */
- (void)closeEncryptSessionWithUserId:(NSString *)userId {
    [[STIMKit sharedInstance] sendEncryptionChatWithType:STIMEncryptMessageType_Close WithBody:@"关闭" ToJid:userId];
}

- (void)getCloudRemoteEncrypt {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [[STIMNoteManager sharedInstance] getCloudRemoteMainWithVersion:0 WithType:STIMNoteTypeChatPwdBox];
        STIMNoteModel *pwdBox = [[STIMNoteManager sharedInstance] getEncrptPwdBox];
        [[STIMNoteManager sharedInstance] getCloudRemoteSubWithQid:pwdBox.q_id Cid:pwdBox.c_id version:0 type:STIMPasswordTypeText];
    });
}

- (STIMNoteModel *)getEncrptPwdBox {
    NSArray *pwdBoxs = [[STIMKit sharedInstance] getQTNotesMainItemWithQType:STIMNoteTypeChatPwdBox];
    if (pwdBoxs.count >= 1) {
        STIMNoteModel *model = [[STIMNoteModel alloc] init];
        NSDictionary *dict = [pwdBoxs objectAtIndex:0];
        [model setValuesForKeysWithDictionary:dict];
        return model;
    }
    return nil;
}

//根据UserId及本地Cid获取 加密会话的密码
-  (NSString *)getChatPasswordWithUserId:(NSString *)userId
                                 WithCid:(NSInteger)cid {
    
    //第一步：内存中获取UserId的加密会话密码
    NSString *memoryPwd = [self getEncryptChatPasswordWithUserId:userId];
    if (memoryPwd) {
        return memoryPwd;
    }
    //第二步：本地获取UserId的加密会话密码
    NSString *password = [self getLocalEncryptChatPasswordWithUserId:userId WithCid:cid];
    //第三步：网络获取UserId的加密会话密码
    if (!password) {
        [[STIMNoteManager sharedInstance] getCloudRemoteMainWithVersion:0 WithType:STIMNoteTypeChatPwdBox];
        STIMNoteModel *pwdBox = [[STIMNoteManager sharedInstance] getEncrptPwdBox];
        [[STIMNoteManager sharedInstance] getCloudRemoteSubWithQid:pwdBox.q_id Cid:pwdBox.c_id version:0 type:STIMPasswordTypeText];
        password =  [self getLocalEncryptChatPasswordWithUserId:userId WithCid:cid];
    }
    //第四步：本地新创建UserId的加密会话密码
    if (!password) {
        //获取内存中密码
        NSString *encrptChatPwd = [[STIMNoteManager sharedInstance] getEncryptChatPasswordWithUserId:userId];
        [self saveEncryptionPasswordWithUserId:userId WithPassword:(encrptChatPwd.length > 0) ? encrptChatPwd : [STIMUUIDTools UUID] WithCid:cid];
        password = [self getLocalEncryptChatPasswordWithUserId:userId WithCid:cid];
    }
    if (![self getEncryptChatPasswordWithUserId:userId]) {
        [self setEncryptChatPasswordWithPassword:password ForUserId:userId];
    }
    return password;
}

//获取本地数据库中的加密会话密码
- (NSString *)getLocalEncryptChatPasswordWithUserId:(NSString *)userId
                                            WithCid:(NSInteger)cid {
    NSString *password = nil;
    STIMNoteModel *model = [[STIMNoteModel alloc] init];
    NSDictionary *pwdDict = [[STIMKit sharedInstance] getQTNotesSubItemWithCid:cid WithUserId:userId];
    if (pwdDict) {
        [model setValuesForKeysWithDictionary:pwdDict];
        NSString *content = model.qs_content;
        if ([[STIMNoteManager sharedInstance] getPasswordWithCid:cid]) {
            NSString *contentJson = [AESCrypt decrypt:content password:[[STIMNoteManager sharedInstance] getPasswordWithCid:cid]];
            if (!contentJson) {
                contentJson = [STIMAES256 decryptForBase64:content password:[[STIMNoteManager sharedInstance] getPasswordWithCid:cid]];
            }
            NSDictionary *contentDic = [[STIMJSONSerializer sharedInstance] deserializeObject:contentJson error:nil];
            password = [contentDic objectForKey:@"P"];
        }
    }
    return password;
}

- (STIMNoteModel *)saveEncryptionPasswordWithUserId:(NSString *)userId
                                     WithPassword:(NSString *)password
                                          WithCid:(NSInteger)cid {
    NSMutableDictionary *contentDic = [NSMutableDictionary dictionary];
    if (userId) {
        [contentDic setObject:userId forKey:@"U"];
    }
    if (password) {
        [contentDic setObject:[NSString stringWithFormat:@"%@", password] forKey:@"P"];
    }
    NSString *contentJson =  [[STIMJSONSerializer sharedInstance] serializeObject:contentDic];
    NSString *content = [STIMAES256 encryptForBase64:contentJson password:[[STIMNoteManager sharedInstance] getPasswordWithCid:cid]];
    STIMNoteModel *model = [[STIMNoteModel alloc] init];
    model.qs_content = content;
    model.c_id = cid;
    model.qs_title = userId;
    model.qs_type = STIMPasswordTypeText;
    model.qs_introduce = @"加密会话密码";
    model.qs_state = STIMNoteStateNormal;
    [self saveNewQTNoteSubItem:model];
    return model;
}

@end
