//
//  QIMLocalLog.m
//  qunarChatIphone
//
//  Created by Qunar-Lu on 2017/3/10.
//
//

#import "QIMLocalLog.h"
#import "QIMZipArchive.h"
#import "NSString+QIMUtility.h"
#import "NSDateFormatter+QIMCategory.h"
#import "QIMKitPublicHeader.h"
#import "QIMJSONSerializer.h"
#import "QIMUUIDTools.h"
#import "QIMNetwork.h"
#import "QIMLogFormatter.h"
#import "CocoaLumberjack.h"
#import "QIMPublicRedefineHeader.h"

static NSString *LocalLogsPath = @"Logs";
static NSString *LocalZipLogsPath = @"ZipLogs";

@interface QIMLocalLog ()

@end

@implementation QIMLocalLog

+ (void)load {
    [QIMLocalLog sharedInstance];
}

+ (instancetype)sharedInstance {
    static QIMLocalLog *__localLog = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        __localLog = [[QIMLocalLog alloc] init];
    });
    return __localLog;
}

- (instancetype)init {
    self = [super init];
    if (self) {

        [self startLog];
    }
    return self;
}

- (void)startLog {

    UIDevice *device = [UIDevice currentDevice];
    NSString *lastUserName = [QIMKit getLastUserName];
    [[QIMKit sharedInstance] setCacheName:[[QIMKit sharedInstance] getLastJid]];
    QIMLocalLogType logType = [[[QIMKit sharedInstance] userObjectForKey:@"recordLogType"] integerValue];
    logType = QIMLocalLogTypeOpened;
    [[QIMKit sharedInstance] setUserObject:@(QIMLocalLogTypeOpened) forKey:@"recordLogType"];
    if ([lastUserName containsString:@"dan.liu"] || [lastUserName containsString:@"weiping.he"] || [lastUserName containsString:@"geng.li"] || [lastUserName containsString:@"lilulucas.li"] || [lastUserName containsString:@"ping.xue"] || [lastUserName containsString:@"wenhui.fan"] || [lastUserName containsString:@"ping.yang"]) {

        [self initDDLog];

        QIMLocalLogType logType = [[[QIMKit sharedInstance] userObjectForKey:@"recordLogType"] integerValue];
        if (logType == QIMLocalLogTypeDefault) {
            [[QIMKit sharedInstance] setUserObject:@(QIMLocalLogTypeOpened) forKey:@"recordLogType"];
        }
    }
    QIMLocalLogType newlogType = [[[QIMKit sharedInstance] userObjectForKey:@"recordLogType"] integerValue];
    if (newlogType == QIMLocalLogTypeOpened) {
        [self deleteLocalLog];
        [self initDDLog];
    }
    [self initDDLog];
}

- (void)initDDLog {
    NSString *logPath = [self getLocalLogsPath];
    DDLogFileManagerDefault *logFileManager = [[DDLogFileManagerDefault alloc] initWithLogsDirectory:logPath];
    QIMLogFormatter *logFormatter = [[QIMLogFormatter alloc] init];
    [DDASLLogger sharedInstance].logFormatter = logFormatter;
    DDFileLogger *fileLogger = [[DDFileLogger alloc] initWithLogFileManager:logFileManager];
    fileLogger.logFormatter = logFormatter;
    fileLogger.rollingFrequency = (24 * 60 * 60) * 2;   //2天
    fileLogger.maximumFileSize = 1024 * 1024 * 1; //每个log日志文件2M
    fileLogger.logFileManager.maximumNumberOfLogFiles = 30; //最多保留100个日志
    fileLogger.logFileManager.logFilesDiskQuota = 30 * 1024 * 1024; //15M
    [DDLog addLogger:fileLogger withLevel:DDLogLevelAll];
    [DDLog addLogger:[DDASLLogger sharedInstance]]; // ASL = Apple System Logs
}

- (void)stopLog {
    QIMVerboseLog(@"关闭记录本地日志");
    fclose(stdout);
    fclose(stderr);
}

- (NSString *)getLogFilePath {
    NSString *logDirectory = [self getLocalLogsPath];

    NSArray *logArray = [self allLogFilesAtPath:logDirectory];
    NSString *logFilePath = nil;
    if (logArray.count > 0) {
        NSString *lastLogFilePath = [logArray lastObject];
        NSDictionary *logFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:lastLogFilePath error:nil];
        if (logFileAttributes != nil) {
            NSDate *fileModDate = [logFileAttributes objectForKey:NSFileModificationDate]; //修改时间
            NSNumber *theFileSize = [logFileAttributes objectForKey:NSFileSize]; //文件字节数
            CGFloat overSizeFileFlag = theFileSize.longLongValue / 1024 / 1024;
            NSTimeInterval timeIntervalSinceNow = [fileModDate timeIntervalSinceNow];
            //如果最后一个log文件超过两小时或文件Size>5M就重新创建一个日志文件
            if (fabs(fabs(timeIntervalSinceNow) / (3600 * 2)) >= 1 || overSizeFileFlag >= 5) {
                logFilePath = [self createNewLogFileWithDirectory:logDirectory];
            } else {
                logFilePath = lastLogFilePath;
            }
        }
    } else {
        logFilePath = [self createNewLogFileWithDirectory:logDirectory];
    }
    if (logFilePath.length <= 0 || !logFilePath) {
        logFilePath = [self createNewLogFileWithDirectory:logDirectory];
    }
    return logFilePath;
}

- (void)redirectNSLogToDocumentFolder {

    NSString *logFilePath = [self getLogFilePath];
    // 将log输入到文件
    QIMVerboseLog(@"本地日志路径 : %@", logFilePath);
    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stdout);
    freopen([logFilePath cStringUsingEncoding:NSASCIIStringEncoding], "a+", stderr);
}

- (NSArray *)allLogFilesAtPath:(NSString *)dirPath {
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:10];
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSArray *tempArray = [fileMgr contentsOfDirectoryAtPath:dirPath error:nil];
    for (NSString *fileName in tempArray) {
        BOOL flag = YES;
        NSString *fullPath = [dirPath stringByAppendingPathComponent:fileName];
        if ([fileMgr fileExistsAtPath:fullPath isDirectory:&flag]) {
            if (!flag) {
                [array addObject:fullPath];
            }
        }
    }
    return array;
}

- (NSArray *)allLogFileAttributes {
    NSString *dirPath = [self getLocalLogsPath];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:10];
    NSFileManager *fileMgr = [NSFileManager defaultManager];
    NSArray *tempArray = [fileMgr contentsOfDirectoryAtPath:dirPath error:nil];
    for (NSString *fileName in tempArray) {
        BOOL flag = YES;
        NSString *fullPath = [dirPath stringByAppendingPathComponent:fileName];
        if ([fileMgr fileExistsAtPath:fullPath isDirectory:&flag]) {
            if (!flag) {
                NSDictionary *logFileAttributeDict = [[NSFileManager defaultManager] attributesOfItemAtPath:fullPath error:nil];
                [array addObject:@{@"LogFilePath": fullPath, @"logFileAttribute": logFileAttributeDict}];
            }
        }
    }
    return array;
}

- (NSString *)createNewLogFileWithDirectory:(NSString *)logDirectory {
    NSDate *date = [NSDate date];
    NSDateFormatter *dateFormatter = [NSDateFormatter qim_defaultDateFormatter];
    NSString *dateStr = [dateFormatter stringFromDate:date];
    NSString *newFileName = [dateStr stringByAppendingString:@".log"];
    NSString *newLogFilePath = [logDirectory stringByAppendingPathComponent:newFileName];
    if (newLogFilePath.length) {
        return newLogFilePath;
    }
    return nil;
}

- (void)deleteLocalLog {
    NSString *logDirectory = [self getLocalLogsPath];
    NSArray *logArray = [self allLogFilesAtPath:logDirectory];
    for (NSString *logFilePath in logArray) {
        NSDictionary *logFileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:logFilePath error:nil];
        NSDate *fileModDate = [logFileAttributes objectForKey:NSFileModificationDate]; //修改时间
        NSTimeInterval timeIntervalSinceNow = [fileModDate timeIntervalSinceNow];
        if (fabs(fabs(timeIntervalSinceNow) / (3600 * 24 * 1.5)) >= 1) { //删除间隔超过一天半的日志
            NSError *error = nil;
            BOOL removeSuccess = [[NSFileManager defaultManager] removeItemAtPath:logFilePath error:&error];
            if (removeSuccess) {
                QIMVerboseLog(@"删除旧日志<%@>成功", logFilePath);
            } else {
                QIMVerboseLog(@"<删除旧日志失败, 失败原因 : %@>", error);
            }
        }
    }
}

- (NSString *)getLocalLogsPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *logDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:LocalLogsPath];
    BOOL isDir;
    if (![[NSFileManager defaultManager] fileExistsAtPath:logDirectory isDirectory:&isDir]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:logDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return logDirectory;
}

- (NSString *)getLocalZipLogsPath {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *logDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:LocalZipLogsPath];
    if (![[NSFileManager defaultManager] fileExistsAtPath:logDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:logDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    return logDirectory;
}

//合并数据库，本地日志等
- (NSData *)allLogData {

    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotifySubmitLog object:@{@"promotMessage":@"准备打包日志文件，请勿关闭应用程序！"}];
    });
    NSMutableArray *logArray = [NSMutableArray arrayWithCapacity:5];

    NSString *libraryPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];

    //UserDefault文件
    NSString *userDefaultPath = [libraryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/%@.plist", @"Preferences", [[NSBundle mainBundle] bundleIdentifier]]];
    [logArray addObject:userDefaultPath];

    [[QIMKit sharedInstance] qimDB_dbCheckpoint];

    //App
    NSString *appPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/APP/"]];
    [logArray addObject:appPath];

    //缓存Path
    NSString *cachePath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0] stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@/", [[QIMKit sharedInstance] getLastJid]]];
    [logArray addObject:cachePath];


    //数据库文件
    NSString *dbPath = [[QIMKit sharedInstance] getDBPathWithUserXmppId:[[QIMKit sharedInstance] getLastJid]];
    [logArray addObject:dbPath];

    //数据库文件shm文件
    NSString *dbSHMPath = [NSString stringWithFormat:@"%@%@", dbPath, @"-shm"];
    [logArray addObject:dbSHMPath];

    //数据库文件wal文件
    NSString *dbWALPath = [NSString stringWithFormat:@"%@%@", dbPath, @"-wal"];
    [logArray addObject:dbWALPath];

    //数据库Version文件
    NSString *dbVersionPath = [[dbPath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"DBVersion"];
    [logArray addObject:dbVersionPath];
    
    //本地日志
    NSArray *allLocalLogs = [self allLogFilesAtPath:[self getLocalLogsPath]];
    for (NSString *logPath in allLocalLogs) {
        [logArray addObject:logPath];
    }
    NSString *zipFileName = [NSString stringWithFormat:@"%@-log.zip", [[QIMKit sharedInstance] getLastJid]];

    NSString *zipFilePath = [[QIMZipArchive sharedInstance] zipFiles:logArray ToFile:[[QIMLocalLog sharedInstance] getLocalZipLogsPath] ToZipFileName:zipFileName WithZipPassword:@"lilulucas.li"];
    NSData *logData = [NSData dataWithContentsOfFile:zipFilePath];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotifySubmitLog object:@{@"promotMessage":@"打包完成，准备上传日志文件, ，请勿关闭应用程序！"}];
    });
    return logData;
}

- (void)submitFeedBackWithContent:(NSString *)content WithLogSelected:(BOOL)selected {
    QIMVerboseLog(@"提交反馈");
    if (selected) {
        [self submitFeedBackWithContent:content withUserInitiative:YES];
    } else {
        [self sendFeedBackWithLogFileUrl:nil WithContent:content withUserInitiative:YES];
    }
}

//提交反馈
- (void)submitFeedBackWithContent:(NSString *)content withUserInitiative:(BOOL)initiative {
    QIMVerboseLog(@"提交日志");
    [[QIMKit sharedInstance] qim_uploadFileWithFileData:[[QIMLocalLog sharedInstance] allLogData] WithPathExtension:@"zip" WithCallback:^(NSString *logFileUrl) {
        if (logFileUrl.length) {
            if (![logFileUrl qim_hasPrefixHttpHeader]) {
                logFileUrl = [NSString stringWithFormat:@"%@/%@", [[QIMKit sharedInstance] qimNav_InnerFileHttpHost], logFileUrl];
            }
            [self sendFeedBackWithLogFileUrl:logFileUrl WithContent:content withUserInitiative:initiative];
        }
    }];
}

- (void)sendFeedBackWithLogFileUrl:(NSString *)logFileUrl WithContent:(NSString *)content withUserInitiative:(BOOL)initiative {
    NSString *title = [NSString stringWithFormat:@"【IOS】来自：%@的反馈日志", [[QIMKit sharedInstance] getLastJid]];
    NSMutableDictionary *requestDic = [NSMutableDictionary dictionary];
    [requestDic setObject:@"qchat@qunar.com" forKey:@"from"];
    [requestDic setObject:@"QChat Team" forKey:@"from_name"];
    [requestDic setObject:@[@"lilulucas.li@qunar.com", @"kaiming.zhang@qunar.com"] forKey:@"tos"];
    [requestDic setObject:title forKey:@"subject"];
    NSString *systemVersion = [[QIMKit sharedInstance] SystemVersion];
    NSString *appVersion = [[QIMKit sharedInstance] AppBuildVersion];
    NSMutableDictionary *oldNavConfigUrlDict = [[QIMKit sharedInstance] userObjectForKey:@"QC_CurrentNavDict"];
    QIMVerboseLog(@"本地找到的oldNavConfigUrlDict : %@", oldNavConfigUrlDict);
    NSString *platName = @"Startalk";
    if ([QIMKit getQIMProjectType] == QIMProjectTypeQChat) {
        platName = @"QChat";
    } else if ([QIMKit getQIMProjectType] == QIMProjectTypeQTalk) {
        platName = @"QTalk";
    } else {
        platName = @"Startalk";
    }
    
    NSString *eventName = [NSString stringWithFormat:@"反馈内容：%@\n平台：%@\n用户ID：%@\n导航地址: %@\n日志地址 : %@\n设备信息：%@\n设备系统版本：%@\nApp版本:%@", content, platName, [[QIMKit sharedInstance] getLastJid], [oldNavConfigUrlDict objectForKey:QIMNavUrlKey], logFileUrl, [[[QIMKit sharedInstance] deviceName] stringByReplacingOccurrencesOfString:@" " withString:@""], systemVersion, appVersion];
    
    [requestDic setObject:eventName forKey:@"body"];
    [requestDic setObject:[platName lowercaseString] forKey:@"plat"];
    [requestDic setObject:@"日志反馈" forKey:@"alt_body"];
    [requestDic setObject:@"true" forKey:@"is_html"];
    NSData *requestData = [[QIMJSONSerializer sharedInstance] serializeObject:requestDic error:nil];
    NSURL *requestUrl = [NSURL URLWithString:@"https://qim.qunar.com/package/newapi/nck/sendmail.qunar"];

    NSMutableDictionary *requestHeader = [NSMutableDictionary dictionaryWithCapacity:1];
    [requestHeader setObject:@"application/json;" forKey:@"Content-type"];

    QIMHTTPRequest *request = [[QIMHTTPRequest alloc] initWithURL:requestUrl];
    [request setHTTPMethod:QIMHTTPMethodPOST];
    [request setHTTPBody:requestData];
    [request setTimeoutInterval:10];
    request.HTTPRequestHeaders = requestHeader;
    [QIMHTTPClient sendRequest:request complete:^(QIMHTTPResponse *response) {
        if (response.code == 200) {
            QIMVerboseLog(@"提交日志成功");
            if (initiative == YES) {
                [[QIMLocalLog sharedInstance] deleteLocalLog];
                NSDictionary *responseDic = [[QIMJSONSerializer sharedInstance] deserializeObject:response.data error:nil];
                BOOL ret = [[responseDic objectForKey:@"ret"] boolValue];
                NSInteger errcode = [[responseDic objectForKey:@"errcode"] integerValue];
                if (ret && errcode == 0) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:kNotifySubmitLog object:@{@"promotMessage":@"反馈成功，非常感谢！"}];
                    });
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[NSNotificationCenter defaultCenter] postNotificationName:kNotifySubmitLog object:@{@"promotMessage":@"反馈失败，请稍后重试！"}];
                    });
                }
            }
        }
    }                  failure:^(NSError *error) {
        QIMVerboseLog(@"提交日志失败 : %@", error);
        if (initiative == YES) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kNotifySubmitLog object:@{@"promotMessage":@"反馈失败，请稍后重试！"}];
            });
        }
    }];
}

@end
