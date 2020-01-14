//
//  STIMEncryptChatView.m
//  STChatIphone
//
//  Created by 李海彬 on 2017/9/5.
//
//

#import "STIMEncryptChat.h"
#import "STIMNoteManager.h"
#import "SCLAlertView.h"
#import "STIMNoteModel.h"
#import "AESCrypt.h"
#import "STIMAES256.h"
#import "STIMKitPublicHeader.h"
#import "STIMJSONSerializer.h"
#import "STIMUUIDTools.h"
#import "UIColor+STIMUtility.h"
#import "STIMPublicRedefineHeader.h"
#import "NSBundle+STIMLibrary.h"

NSString *kNoticeTitle = @"Notice";

@interface STIMEncryptChat ()

@property (nonatomic, copy) NSString *userId;
@property (nonatomic, copy) NSString *pwd;
@property (nonatomic, assign) STIMEncryptChatDirection chatDirection;
@property (nonatomic, assign) STIMEncryptChatState willChangeState;
@property (nonatomic, strong) SCLAlertView *beginAlert;
@property (nonatomic, strong) SCLAlertView *promptAlert;
@property (nonatomic, strong) SCLAlertView *createPwdBoxAlert;
@property (nonatomic, strong) SCLAlertView *vaildPwdAlert;
@property (nonatomic, strong) SCLAlertView *waitingAlert;
@property (nonatomic, strong) SCLAlertView *noticeAlert;
@property (nonatomic, strong) SCLAlertView *closePwdAlert;

@property (nonatomic, strong) NSMutableDictionary *encryptChatLeftTimeDict;
@property (nonatomic, strong) NSMutableDictionary *encryptChatStateDict;

@end

@implementation STIMEncryptChat

+ (instancetype)sharedInstance {
    static STIMEncryptChat *__STIMEncryptChat = nil;
    NSString *qCloudHost = [[STIMKit sharedInstance] qimNav_QCloudHost];
    if (qCloudHost.length <= 0) {
        return nil;
    } else {
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            __STIMEncryptChat = [[STIMEncryptChat alloc] init];
        });
    }
    return __STIMEncryptChat;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        
        [self registerNotify];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (SCLAlertView *)beginAlert {
    _beginAlert = [[SCLAlertView alloc] init];
    [_beginAlert setHorizontalButtons:YES];
    SCLButton *cancelBtn = [_beginAlert addButton:[NSBundle stimDB_localizedStringForKey:@"Cancel"] target:self selector:@selector(dismisssEncryptChatAlert)];
    cancelBtn.buttonFormatBlock = ^NSDictionary* (void)
    {
        NSMutableDictionary *buttonConfig = [[NSMutableDictionary alloc] init];
        
        buttonConfig[@"backgroundColor"] = [UIColor redColor];
        buttonConfig[@"textColor"] = [UIColor whiteColor];
        return buttonConfig;
    };
    STIMEncryptChatState encryptState = [self getEncryptChatStateWithUserId:self.userId];
    if (encryptState == STIMEncryptChatStateDecrypted) {
        [_beginAlert addButton:@"解除解密" target:self selector:@selector(cancelDescrpytChat)];
    } else {
        [_beginAlert addButton:@"解密会话" target:self selector:@selector(decryptChat)];
    }
    [_beginAlert addButton:@"开启加密" target:self selector:@selector(requestStartEncrypt)];
    return _beginAlert;
}

- (SCLAlertView *)promptAlert {
    _promptAlert = [[SCLAlertView alloc] init];
    [_promptAlert setHorizontalButtons:YES];
    SCLButton *button = [_promptAlert addButton:@"拒绝" target:self selector:@selector(refuseEncrypt)];
    button.buttonFormatBlock = ^NSDictionary* (void)
    {
        NSMutableDictionary *buttonConfig = [[NSMutableDictionary alloc] init];
        
        buttonConfig[@"backgroundColor"] = [UIColor redColor];
        buttonConfig[@"textColor"] = [UIColor whiteColor];
        return buttonConfig;
    };
    [_promptAlert addButton:@"同意" target:self selector:@selector(startEncryptChatAction)];
    _promptAlert.soundURL = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/right_answer.mp3", [NSBundle mainBundle].resourcePath]];
    [_promptAlert addTimerToButtonIndex:0 reverse:YES];
    return _promptAlert;
}

- (SCLAlertView *)createPwdBoxAlert {
    _createPwdBoxAlert = [[SCLAlertView alloc] init];
    [_createPwdBoxAlert setHorizontalButtons:YES];
    SCLTextView *pwdBoxTitleField = [_createPwdBoxAlert addTextField:@"会话密码箱"];
    pwdBoxTitleField.text = @"会话密码箱";
    pwdBoxTitleField.enabled = NO;
    SCLTextView *pwdBoxIntroduceField = [_createPwdBoxAlert addTextField:@"端到端加密会话密码箱"];
    pwdBoxIntroduceField.text = @"端到端加密会话密码箱";
    pwdBoxIntroduceField.enabled = NO;
    SCLTextView *pwdBoxTextField = [_createPwdBoxAlert addTextField:@"输入主密码"];
    SCLTextView *vaildPwdBoxTextField = [_createPwdBoxAlert addTextField:@"验证主密码"];

    pwdBoxTextField.keyboardType = UIKeyboardTypeASCIICapable;
    vaildPwdBoxTextField.keyboardType = UIKeyboardTypeASCIICapable;
    pwdBoxTextField.secureTextEntry = YES;
    vaildPwdBoxTextField.secureTextEntry = YES;
    [_createPwdBoxAlert addButton:[NSBundle stimDB_localizedStringForKey:@"Cancel"] target:self selector:@selector(dismisssEncryptChatAlert)];
    __weak __typeof(self) weakSelf = self;
    [_createPwdBoxAlert addButton:@"创建" validationBlock:^BOOL {
        if (pwdBoxTextField.text.length == 0)
        {
            [weakSelf promptUserWithShakeTextField:pwdBoxTextField];
            NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:@"主密码不能为空" attributes:
                                              @{NSForegroundColorAttributeName:[UIColor redColor],
                                                }];
            pwdBoxTextField.attributedPlaceholder = attrString;
            [pwdBoxTextField becomeFirstResponder];
            return NO;
        } else if (vaildPwdBoxTextField.text.length <= 0 || ![vaildPwdBoxTextField.text isEqualToString:pwdBoxTextField.text]) {
            [weakSelf promptUserWithShakeTextField:vaildPwdBoxTextField];
            NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:@"两次密码不一致，请重新输入" attributes:
                                              @{NSForegroundColorAttributeName:[UIColor redColor],
                                                }];
            vaildPwdBoxTextField.attributedPlaceholder = attrString;
            vaildPwdBoxTextField.text = @"";
            [vaildPwdBoxTextField becomeFirstResponder];
            return NO;
        } else {
            STIMNoteModel *pwdBoxModel = [[STIMNoteModel alloc] init];
            pwdBoxModel.c_id = [[STIMNoteManager sharedInstance] getMaxQTNoteMainItemCid] + 1;
            pwdBoxModel.q_title = pwdBoxTitleField.text;
            pwdBoxModel.q_introduce = pwdBoxIntroduceField.text;
            pwdBoxModel.q_type = STIMNoteTypeChatPwdBox;
            pwdBoxModel.q_state = STIMNoteStateNormal;
            NSString *encryptStr = [STIMAES256 encryptForBase64:pwdBoxModel.q_title password:pwdBoxTextField.text];
            pwdBoxModel.q_content = encryptStr;
            pwdBoxModel.q_time = [[NSDate date] timeIntervalSince1970] * 1000;
            [[STIMNoteManager sharedInstance] saveNewQTNoteMainItem:pwdBoxModel];
            [[STIMNoteManager sharedInstance] setPassword:pwdBoxTextField.text ForCid:pwdBoxModel.c_id];
            if (weakSelf.chatDirection == STIMEncryptChatDirectionReceived) {
                [weakSelf beginEncryptChatWithUserId:weakSelf.userId WithPassword:pwdBoxTextField.text WithCid:pwdBoxModel.c_id WithSendAgree:YES];
            } else {
                [weakSelf beginEncryptChatWithUserId:weakSelf.userId WithPassword:pwdBoxTextField.text WithCid:pwdBoxModel.c_id WithSendAgree:NO];
            }
        }
        return YES;
    } actionBlock:^{
    }];
    return _createPwdBoxAlert;
}

- (SCLAlertView *)vaildPwdAlert {
    _vaildPwdAlert = [[SCLAlertView alloc] init];
    [_vaildPwdAlert setHorizontalButtons:YES];
    
    SCLTextView *vaildPwdBoxTextField = [_vaildPwdAlert addTextField:@"输入主密码"];
    vaildPwdBoxTextField.keyboardType = UIKeyboardTypeASCIICapable;
    vaildPwdBoxTextField.secureTextEntry = YES;
    __weak __typeof(self) weakSelf = self;
    SCLButton *cancelBtn = [_vaildPwdAlert addButton:[NSBundle stimDB_localizedStringForKey:@"Cancel"] target:self selector:@selector(dismisssEncryptChatAlert)];
    cancelBtn.buttonFormatBlock = ^NSDictionary* (void)
    {
        NSMutableDictionary *buttonConfig = [[NSMutableDictionary alloc] init];
        
        buttonConfig[@"backgroundColor"] = [UIColor redColor];
        buttonConfig[@"textColor"] = [UIColor whiteColor];
        return buttonConfig;
    };
    [_vaildPwdAlert addButton:@"验证主密码" validationBlock:^BOOL{
        if (vaildPwdBoxTextField.text.length == 0)
        {
            [weakSelf promptUserWithShakeTextField:vaildPwdBoxTextField];
            NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:@"主密码不能为空，请重新输入" attributes:
                                              @{NSForegroundColorAttributeName:[UIColor redColor],
                                                }];
            vaildPwdBoxTextField.attributedPlaceholder = attrString;
            vaildPwdBoxTextField.text = @"";
            [vaildPwdBoxTextField becomeFirstResponder];
            return NO;
        }
        STIMNoteModel *model = [[STIMNoteManager sharedInstance] getEncrptPwdBox];
        NSString *content = model.q_content;
        
        NSString *vaildPassworBoxPass = [AESCrypt decrypt:content password:vaildPwdBoxTextField.text];
        if (!vaildPassworBoxPass) {
            vaildPassworBoxPass = [STIMAES256 decryptForBase64:content password:vaildPwdBoxTextField.text];
        }
        
        if (!vaildPassworBoxPass) {
            [weakSelf promptUserWithShakeTextField:vaildPwdBoxTextField];
            NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:@"主密码错误，请重新输入" attributes:
                                              @{NSForegroundColorAttributeName:[UIColor redColor],
                                                }];
            vaildPwdBoxTextField.attributedPlaceholder = attrString;
            vaildPwdBoxTextField.text = @"";
            [vaildPwdBoxTextField becomeFirstResponder];
            return NO;
        } else {
            
            [[STIMNoteManager sharedInstance] setPassword:vaildPwdBoxTextField.text ForCid:model.c_id];
            if (weakSelf.willChangeState >= STIMEncryptChatStateEncrypting) {
                [weakSelf beginEncryptChatWithUserId:weakSelf.userId WithPassword:weakSelf.pwd WithCid:model.c_id WithSendAgree:NO];
            }
            else {
                [weakSelf beginEncryptChatWithUserId:weakSelf.userId WithPassword:weakSelf.pwd WithCid:model.c_id WithSendAgree:YES];
            }
        }
        return YES;
    } actionBlock:^{
    }];
    return _vaildPwdAlert;
}

- (SCLAlertView *)waitingAlert {
    
    _waitingAlert = [[SCLAlertView alloc] init];
    _waitingAlert.showAnimationType = SCLAlertViewHideAnimationSlideOutToCenter;
    _waitingAlert.hideAnimationType = SCLAlertViewHideAnimationSlideOutFromCenter;
    _waitingAlert.backgroundType = SCLAlertViewBackgroundTransparent;
    [_waitingAlert addButton:[NSBundle stimDB_localizedStringForKey:@"Cancel"] target:self selector:@selector(cancelEncrypt)];
    [_waitingAlert addTimerToButtonIndex:0 reverse:YES];
    return _waitingAlert;
}

- (SCLAlertView *)closePwdAlert {
    _closePwdAlert = [[SCLAlertView alloc] init];
    [_closePwdAlert setHorizontalButtons:YES];
    SCLButton *cancelBtn = [_closePwdAlert addButton:[NSBundle stimDB_localizedStringForKey:@"Cancel"] target:self selector:@selector(dismisssEncryptChatAlert)];
    cancelBtn.buttonFormatBlock = ^NSDictionary* (void)
    {
        NSMutableDictionary *buttonConfig = [[NSMutableDictionary alloc] init];
        
        buttonConfig[@"backgroundColor"] = [UIColor redColor];
        buttonConfig[@"textColor"] = [UIColor whiteColor];
        return buttonConfig;
    };
    [_closePwdAlert addButton:@"关闭会话" target:self selector:@selector(closeEncrypt)];
    return _closePwdAlert;
}

- (SCLAlertView *)noticeAlert {
    _noticeAlert = [[SCLAlertView alloc] init];
    return _noticeAlert;
}


- (void)promptUserWithShakeTextField:(UITextField *)textField {
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animation];
    animation.keyPath = @"position.x";
    //values 数组定义了表单应该到哪些位置。
    animation.values = @[ @0, @15, @-15, @15, @0 ];
    //设置 keyTimes 属性让我们能够指定关键帧动画发生的时间。它们被指定为关键帧动画总持续时间的一个分数。
    animation.keyTimes = @[ @0, @(1 / 6.0), @(3 / 6.0), @(5 / 6.0), @1 ];
    animation.duration = 0.4;
    animation.additive = YES;
    [textField.layer addAnimation:animation forKey:@"shake"];
}

#pragma mark - Notify

- (void)registerNotify {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(beginEncryptChat:) name:kNotifyBeginEncryptChat object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(agreeEncryptChat:) name:kNotifyAgreeEncryptChat object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refuseEncryptChat:) name:kNotifyRefuseEncryptChat object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cancelEncryptChat:) name:kNotifyCancelEncryptChat object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(closeEncryptChat:) name:kNotifyCloseEncryptChat object:nil];
}

/**
 接收到开始加密会话请求
 */
- (void)beginEncryptChat:(NSNotification *)notify {
    BOOL carbon = [[notify.userInfo objectForKey:@"carbon"] boolValue];
    if (carbon == YES) {
        STIMVerboseLog(@"Carbon 过来的接受开始加密会话请求");
        return;
    }
    NSString *content = [notify.userInfo objectForKey:@"content"];
    NSDictionary *contentDic = [[STIMJSONSerializer sharedInstance] deserializeObject:content error:nil];
    STIMVerboseLog(@"接受到加密会话请求 : %@", contentDic);
    self.pwd = [contentDic objectForKey:@"pwd"];
    STIMVerboseLog(@"beginEncryptChat : %@", contentDic);
    self.userId = notify.object;
    [[STIMNoteManager sharedInstance] setEncryptChatPasswordWithPassword:self.pwd ForUserId:self.userId];
    NSDictionary *userInfo = [[STIMKit sharedInstance] getUserInfoByUserId:self.userId];
    NSString *name = [userInfo objectForKey:@"Name"];
    NSString *subTitle = [NSString stringWithFormat:@"【%@】请求与你加密会话，是否同意开启？", name?name:self.userId];
    self.chatDirection = STIMEncryptChatDirectionReceived;
    [[STIMKit sharedInstance] createMessageWithMsg:@"对方发起加密会话请求" extenddInfo:nil userId:notify.object realJid:nil userType:ChatType_SingleChat msgType:STIMMessageType_Time forMsgId:[STIMUUIDTools UUID] msgState:STIMMessageSendState_Success willSave:YES];
    [self.promptAlert showInfo:[[[[UIApplication sharedApplication] delegate] window] rootViewController] title:@"加密会话" subTitle:subTitle closeButtonTitle:nil duration:60.0f];
}

/**
 接收到同意加密会话通知
 */
- (void)agreeEncryptChat:(NSNotification *)notify {
    BOOL carbon = [[notify.userInfo objectForKey:@"carbon"] boolValue];
    if (carbon == YES) {
        STIMVerboseLog(@"Carbon 过来的已在其他设备同意加密会话请求");
        [[STIMKit sharedInstance] createMessageWithMsg:@"已在其他设备同意加密会话请求" extenddInfo:nil userId:notify.object realJid:nil userType:ChatType_SingleChat msgType:STIMMessageType_Time forMsgId:[STIMUUIDTools UUID] msgState:STIMMessageSendState_Success willSave:YES];
        [self handleEncryptWithUserId:notify.object WithState:STIMEncryptChatStateNone];
    } else {
        [[STIMKit sharedInstance] createMessageWithMsg:@"对方同意加密会话请求" extenddInfo:nil userId:notify.object realJid:nil userType:ChatType_SingleChat msgType:STIMMessageType_Time forMsgId:[STIMUUIDTools UUID] msgState:STIMMessageSendState_Success willSave:YES];
        [self handleEncryptWithUserId:notify.object WithState:STIMEncryptChatStateEncrypting];
    }
}

/**
 接收到拒绝加密会话通知
 */
- (void)refuseEncryptChat:(NSNotification *)notify {
    BOOL carbon = [[notify.userInfo objectForKey:@"carbon"] boolValue];
    if (carbon == YES) {
        STIMVerboseLog(@"Carbon 过来的已在其他设备拒绝加密会话请求");
        [[STIMKit sharedInstance] createMessageWithMsg:@"已在其他设备拒绝加密会话请求" extenddInfo:nil userId:notify.object realJid:nil userType:ChatType_SingleChat msgType:STIMMessageType_Time forMsgId:[STIMUUIDTools UUID] msgState:STIMMessageSendState_Success willSave:YES];
        [self handleEncryptWithUserId:notify.object WithState:STIMEncryptChatStateNone];
    } else {
        [[STIMKit sharedInstance] createMessageWithMsg:@"对方拒绝加密会话请求" extenddInfo:nil userId:notify.object realJid:nil userType:ChatType_SingleChat msgType:STIMMessageType_Time forMsgId:[STIMUUIDTools UUID] msgState:STIMMessageSendState_Success willSave:YES];
        [self handleEncryptWithUserId:notify.object WithState:STIMEncryptChatStateNone];
    }
}

//接收取消加密会话通知
- (void)cancelEncryptChat:(NSNotification *)notify {
    BOOL carbon = [[notify.userInfo objectForKey:@"carbon"] boolValue];
    if (carbon == YES) {
        STIMVerboseLog(@"Carbon 过来的已在其他设备取消加密会话");
        [[STIMKit sharedInstance] createMessageWithMsg:@"已在其他设备取消加密会话" extenddInfo:nil userId:notify.object realJid:nil userType:ChatType_SingleChat msgType:STIMMessageType_Time forMsgId:[STIMUUIDTools UUID] msgState:STIMMessageSendState_Success willSave:YES];
        [self handleEncryptWithUserId:notify.object WithState:STIMEncryptChatStateNone];
    } else {
        [[STIMKit sharedInstance] createMessageWithMsg:@"对方已取消加密会话" extenddInfo:nil userId:notify.object realJid:nil userType:ChatType_SingleChat msgType:STIMMessageType_Time forMsgId:[STIMUUIDTools UUID] msgState:STIMMessageSendState_Success willSave:YES];
        [self handleEncryptWithUserId:notify.object WithState:STIMEncryptChatStateNone];
    }
}

//接收到结束加密会话通知
- (void)closeEncryptChat:(NSNotification *)notify {
    BOOL carbon = [[notify.userInfo objectForKey:@"carbon"] boolValue];
    if (carbon == YES) {
        STIMVerboseLog(@"Carbon 过来的已在其他设备关闭加密会话");
        [[STIMKit sharedInstance] createMessageWithMsg:@"已在其他设备关闭加密会话" extenddInfo:nil userId:notify.object realJid:nil userType:ChatType_SingleChat msgType:STIMMessageType_Time forMsgId:[STIMUUIDTools UUID] msgState:STIMMessageSendState_Success willSave:YES];
        [self handleEncryptWithUserId:notify.object WithState:STIMEncryptChatStateNone];
    } else {
        [[STIMKit sharedInstance] createMessageWithMsg:@"对方已关闭加密会话" extenddInfo:nil userId:notify.object realJid:nil userType:ChatType_SingleChat msgType:STIMMessageType_Time forMsgId:[STIMUUIDTools UUID] msgState:STIMMessageSendState_Success willSave:YES];
        [self handleEncryptWithUserId:notify.object WithState:STIMEncryptChatStateNone];
    }
}

#pragma - mark Action

- (void)dismisssEncryptChatAlert {
    self.userId = nil;
    self.pwd = nil;
    [_beginAlert hideView];;
    [_promptAlert hideView];
    [_createPwdBoxAlert hideView];
    [_vaildPwdAlert hideView];
    [_waitingAlert hideView];
    [_closePwdAlert hideView];
}

/**
 做一些加密相关的操作
 */
- (void)doSomeEncryptChatWithUserId:(NSString *)userId {
    self.userId = userId;
    STIMEncryptChatState encryptState = [self getEncryptChatStateWithUserId:userId];
    switch (encryptState) {
        case STIMEncryptChatStateNone:
        case STIMEncryptChatStateDecrypted: {
            [self.beginAlert showCustom:[[[[UIApplication sharedApplication] delegate] window] rootViewController] image:[UIImage imageNamed:@"explore_tab_passwordBox"] color:[UIColor stimDB_colorWithHex:0x22B573 alpha:1.0] title:[NSBundle stimDB_localizedStringForKey:@"Reminder"] subTitle:@"加密会话操作" closeButtonTitle:nil duration:0.0f];
        }
            break;
        case STIMEncryptChatStateEncrypting: {
            //close加密
            [self.closePwdAlert showWarning:[[[[UIApplication sharedApplication] delegate] window] rootViewController] title:[NSBundle stimDB_localizedStringForKey:@"Reminder"] subTitle:@"加密会话操作" closeButtonTitle:nil duration:0];
        }
            break;
            break;
        default:
            break;
    }
}

/**
 同意加密会话请求
 */
- (void)startEncryptChatAction {
    
    BOOL sendAgree = (self.willChangeState == STIMEncryptChatStateEncrypting) ? NO : YES;
    STIMNoteModel *encryptPwdBox = [[STIMNoteManager sharedInstance] getEncrptPwdBox];
    if (encryptPwdBox == nil) {
        //本地无加密会话密码箱时，创建
        [self.createPwdBoxAlert showEdit:[[[[UIApplication sharedApplication] delegate] window] rootViewController] title:[NSBundle stimDB_localizedStringForKey:@"Reminder"] subTitle:@"       **密码箱能够帮助你存储难记的密码，我们只帮助你记录用主密码加密过的信息。切记，一定要记住你的密码箱的主密码，它是开启密码箱的钥匙，如果丢失了主密码，我们是无能力帮你恢复您记录的数据的。不要遗失您的主密码！！！" closeButtonTitle:nil duration:0];
    } else {
        
        NSString *encryptBoxPassword = [[STIMNoteManager sharedInstance] getPasswordWithCid:encryptPwdBox.c_id];
        //主密码不存在
        if (!encryptBoxPassword) {
            [self.vaildPwdAlert showEdit:[[[[UIApplication sharedApplication] delegate] window] rootViewController] title:@"验证" subTitle:@"请输入主密码来开启加密会话" closeButtonTitle:nil duration:0];
        } else {
            //内存中读取会话密码
            NSString *mainPwd = [[STIMNoteManager sharedInstance] getEncryptChatPasswordWithUserId:self.userId];
            if (mainPwd == nil) {
                NSString *pwd = [[STIMNoteManager sharedInstance] getChatPasswordWithUserId:self.userId WithCid:encryptPwdBox.c_id];
                [self beginEncryptChatWithUserId:self.userId WithPassword:pwd WithCid:encryptPwdBox.c_id WithSendAgree:sendAgree];
            } else {
                [self beginEncryptChatWithUserId:self.userId WithPassword:mainPwd WithCid:encryptPwdBox.c_id WithSendAgree:sendAgree];
            }
        }
    }
}

/**
 请求对方开始加密会话
 */
- (void)requestStartEncrypt {
    self.chatDirection = STIMEncryptChatDirectionSent;
    self.willChangeState = STIMEncryptChatStateEncrypting;
    [self startEncryptChatAction];
}

/**
 拒绝加密会话请求
 */
- (void)refuseEncrypt {
    [[STIMKit sharedInstance] createMessageWithMsg:@"拒绝加密会话请求" extenddInfo:nil userId:self.userId realJid:nil userType:ChatType_SingleChat msgType:STIMMessageType_Time forMsgId:[STIMUUIDTools UUID] msgState:STIMMessageSendState_Success willSave:YES];
    [[STIMNoteManager sharedInstance] refuseEncryptSessionWithUserId:self.userId];
    [self handleEncryptWithUserId:self.userId WithState:STIMEncryptChatStateNone];
}

/**
 取消发送加密会话请求
 */
- (void)cancelEncrypt {
    [[STIMKit sharedInstance] createMessageWithMsg:@"取消加密会话请求" extenddInfo:nil userId:self.userId realJid:nil userType:ChatType_SingleChat msgType:STIMMessageType_Time forMsgId:[STIMUUIDTools UUID] msgState:STIMMessageSendState_Success willSave:YES];
    [[STIMNoteManager sharedInstance] cancelEncryptSessionWithUserId:self.userId];
    [self handleEncryptWithUserId:self.userId WithState:STIMEncryptChatStateNone];
}

//关闭加密会话
- (void)closeEncrypt {
    [[STIMKit sharedInstance] createMessageWithMsg:@"关闭加密会话请求" extenddInfo:nil userId:self.userId realJid:nil userType:ChatType_SingleChat msgType:STIMMessageType_Time forMsgId:[STIMUUIDTools UUID] msgState:STIMMessageSendState_Success willSave:YES];
    [[STIMNoteManager sharedInstance] closeEncryptSessionWithUserId:self.userId];
    [self handleEncryptWithUserId:self.userId WithState:STIMEncryptChatStateNone];
}

- (void)cancelDescrpytChat {
    //解除解密
    [self handleEncryptWithUserId:self.userId WithState:STIMEncryptChatStateNone];
}

/**
 本地解密会话
 */
- (void)decryptChat {
    self.willChangeState = STIMEncryptChatStateDecrypted;
    //1.获取内存中的会话密码
    NSString *chatPwd = [[STIMNoteManager sharedInstance] getEncryptChatPasswordWithUserId:self.userId];
    if (chatPwd) {
        //2.存在则直接开启解密会话
        self.willChangeState = STIMEncryptChatStateNone;
        [self setEncryptChatStateWithUserId:self.userId WithState:STIMEncryptChatStateDecrypted];
        [self handleEncryptWithUserId:self.userId WithState:STIMEncryptChatStateDecrypted];
    } else {
        // 3.否则验证用户主密码，解析数据库
        [self.vaildPwdAlert showEdit:[[[[UIApplication sharedApplication] delegate] window] rootViewController] title:@"验证" subTitle:@"请输入主密码来解密会话" closeButtonTitle:nil duration:0];
        [self setEncryptChatStateWithUserId:self.userId WithState:STIMEncryptChatStateDecrypted];
    }
}

- (void)handleEncryptWithUserId:(NSString *)userId WithState:(STIMEncryptChatState)state {
    if (userId) {
        self.userId = userId;
    }
    [self setEncryptChatStateWithUserId:userId WithState:state];
    if (self.delegate && [self.delegate respondsToSelector:@selector(reloadBaseViewWithUserId:WithEncryptChatState:)]) {
        [self.delegate reloadBaseViewWithUserId:userId WithEncryptChatState:state];
    }
    [self dismisssEncryptChatAlert];
}


/**
 双方正式建立连接，开始加密会话
 */
- (void)beginEncryptChatWithUserId:(NSString *)userId
                      WithPassword:(NSString *)pwd
                           WithCid:(NSInteger )cid
                     WithSendAgree:(BOOL)agree {
    NSString *chatPwd = [[STIMNoteManager sharedInstance] getChatPasswordWithUserId:userId WithCid:cid];
    if (chatPwd == nil) {
        chatPwd = [[STIMNoteManager sharedInstance] saveEncryptionPasswordWithUserId:userId WithPassword:pwd WithCid:cid].qs_content;
    }
    //同意对方的加密会话请求
    if (agree) {
        
        if (chatPwd == nil) {
            [[STIMKit sharedInstance] createMessageWithMsg:@"拒绝加密会话请求" extenddInfo:nil userId:self.userId realJid:nil userType:ChatType_SingleChat msgType:STIMMessageType_Time forMsgId:[STIMUUIDTools UUID] msgState:STIMMessageSendState_Success willSave:YES];
            [[STIMNoteManager sharedInstance] refuseEncryptSessionWithUserId:userId];
        } else {
            [[STIMKit sharedInstance] createMessageWithMsg:@"同意加密会话请求" extenddInfo:nil userId:self.userId realJid:nil userType:ChatType_SingleChat msgType:STIMMessageType_Time forMsgId:[STIMUUIDTools UUID] msgState:STIMMessageSendState_Success willSave:YES];
            [[STIMNoteManager sharedInstance] agreeEncryptSessionWithUserId:userId];
        }
        [self handleEncryptWithUserId:userId WithState:STIMEncryptChatStateEncrypting];
    } else {
        //请求对方
        if (self.willChangeState == STIMEncryptChatStateEncrypting) {
            [[STIMNoteManager sharedInstance] beginEncryptionSessionWithUserId:userId WithPassword:chatPwd];
            self.willChangeState = STIMEncryptChatStateNone;
            [self.waitingAlert showWaiting:[[[[UIApplication sharedApplication] delegate] window] rootViewController] title:@"Waiting..." subTitle:@"正在请求对方开启加密会话..." closeButtonTitle:nil duration:60.0f];
            [[STIMKit sharedInstance] createMessageWithMsg:@"发起加密会话请求" extenddInfo:nil userId:self.userId realJid:nil userType:ChatType_SingleChat msgType:STIMMessageType_Time forMsgId:[STIMUUIDTools UUID] msgState:STIMMessageSendState_Success willSave:YES];
        } else {
            self.willChangeState = STIMEncryptChatStateNone;
            [self handleEncryptWithUserId:userId WithState:STIMEncryptChatStateDecrypted];
        }
    }
}

#pragma mark - EncryptChatState

- (void)setEncryptChatStateWithUserId:(NSString *)userId
                            WithState:(STIMEncryptChatState)state {
    if (self.encryptChatStateDict == nil) {
        self.encryptChatStateDict = [NSMutableDictionary dictionaryWithCapacity:5];
    }
    if (userId) {
        //Yes为加密会话开启中, No为未开启加密会话
        [self.encryptChatStateDict setObject:@(state) forKey:userId];
    }
}

- (STIMEncryptChatState)getEncryptChatStateWithUserId:(NSString *)userId {
    STIMEncryptChatState isEncryptChat = STIMEncryptChatStateNone;
    if (userId) {
        self.userId = userId;
        isEncryptChat = [[self.encryptChatStateDict objectForKey:userId] integerValue];
    }
    return isEncryptChat;
}

#pragma mark - Setter SecurityTime

- (void)setEncryptChatLeaveTimeWithUserId:(NSString *)userId
                                 WithTime:(NSTimeInterval)leftTime {
    STIMEncryptChatState state = [self getEncryptChatStateWithUserId:userId];
    if (state == STIMEncryptChatStateNone) {
        return;
    }
    
    if (self.encryptChatLeftTimeDict == nil) {
        self.encryptChatLeftTimeDict = [NSMutableDictionary dictionaryWithCapacity:5];
    }
    if (userId) {
        self.userId = userId;
        if (leftTime <= 0 && leftTime > [NSDate timeIntervalSinceReferenceDate]) {
            [self.encryptChatLeftTimeDict removeObjectForKey:userId];
        } else {
            NSInteger securitySettingTime = [[[STIMKit sharedInstance] userObjectForKey:@"securityMinute"] integerValue];
            if (securitySettingTime == 0) {
                //15分钟安全时间
                [[STIMKit sharedInstance] setUserObject:@(15 * 60) forKey:@"securityMinute"];
                securitySettingTime = [[[STIMKit sharedInstance] userObjectForKey:@"securityMinute"] integerValue];
            }
            NSString *noticeSubTitle = @"加密会话";
            if (state == STIMEncryptChatStateDecrypted) {
                noticeSubTitle = @"解密会话";
            }
            NSString *securitySettingMinuteTimeStr = [self timeFormatted:(int)securitySettingTime];
            [self.noticeAlert showNotice:[[[[UIApplication sharedApplication] delegate] window] rootViewController] title:kNoticeTitle subTitle:[NSString stringWithFormat:@"%@将在%@内自动关闭，不要离开太久喔～", noticeSubTitle, securitySettingMinuteTimeStr] closeButtonTitle:nil duration:1.5f];
            [self.encryptChatLeftTimeDict setObject:@(leftTime) forKey:userId];
        }
    }
}

- (NSTimeInterval)getEncryptChatLeaveTimeWithUserId:(NSString *)userId {
    NSTimeInterval leftTime = [[self.encryptChatLeftTimeDict objectForKey:userId] doubleValue];
    if (leftTime <= 0) {
        leftTime = [NSDate timeIntervalSinceReferenceDate];
    }
    return leftTime;
}

#pragma mark - Encrypt Message

- (NSString *)encryptMessageWithMsgType:(NSInteger)msgType WithOriginBody:(NSString *)body WithOriginExtendInfo:(NSString *)extendInfo WithUserId:(NSString *)userId {
    NSMutableDictionary *msgDict = [NSMutableDictionary dictionary];
    [msgDict setObject:@(msgType) forKey:@"MsgType"];
    [msgDict setObject:body forKey:@"Content"];
    if (extendInfo) {
        [msgDict setObject:extendInfo forKey:@"ExtendInfo"];
    }
    NSString *msgJson = [[STIMJSONSerializer sharedInstance] serializeObject:msgDict];
    NSString *encryptMsg = [STIMAES256 encryptForBase64:msgJson password:[[STIMNoteManager sharedInstance] getEncryptChatPasswordWithUserId:userId]];
    return encryptMsg;
}

#pragma mark - DeCrypt Message

- (NSInteger)getMessageTypeWithEncryptMsg:(STIMMessageModel *)msg WithUserId:(NSString *)userId {
    NSDictionary *deMessage = [self decryptMessageWithMsgType:msg WithUserId:userId];
    NSInteger msgType = [[deMessage objectForKey:@"MsgType"] integerValue];
    return msgType;
}

- (NSString *)getMessageBodyWithEncryptMsg:(STIMMessageModel *)msg WithUserId:(NSString *)userId {
    NSDictionary *deMessage = [self decryptMessageWithMsgType:msg WithUserId:userId];
    NSString *msgBody = [deMessage objectForKey:@"Content"];
    return msgBody;
}

- (NSString *)getMessageExtendInfoWithEncryptMsg:(STIMMessageModel *)msg WithUserId:(NSString *)userId {
    NSDictionary *deMessage = [self decryptMessageWithMsgType:msg WithUserId:userId];
    NSString *msgExtendInfo = [deMessage objectForKey:@"ExtendInfo"];
    return msgExtendInfo;
}

- (NSDictionary *)decryptMessageWithMsgType:(STIMMessageModel *)msg WithUserId:(NSString *)userId {
    NSString *msgBody = msg.message;
    NSString *extendInfo = msg.extendInformation;
    NSString *decryptContent = msgBody;
    if (extendInfo) {
        decryptContent = extendInfo;
    }
    STIMNoteModel *model = [[STIMNoteManager sharedInstance] getEncrptPwdBox];
    NSString *pwd = [[STIMNoteManager sharedInstance] getChatPasswordWithUserId:userId WithCid:model.c_id];
//    NSString *pwd = [[STIMNoteManager sharedInstance] getEncryptChatPasswordWithUserId:userId];
    if (pwd) {
        NSString *contentJson = [AESCrypt decrypt:decryptContent password:pwd];
        if (!contentJson) {
            contentJson = [STIMAES256 decryptForBase64:decryptContent password:pwd];
        }
        NSDictionary *contentDic = [[STIMJSONSerializer sharedInstance] deserializeObject:contentJson error:nil];
        return contentDic;
    }
    return nil;
}

//转换成时分秒
- (NSString *)timeFormatted:(int)totalSeconds
{
    
    int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    if (seconds != 0) {
        return [NSString stringWithFormat:@"%02d分钟%02d秒", minutes, seconds];
    } else {
        return [NSString stringWithFormat:@"%02d分钟", minutes];
    }
}

@end
