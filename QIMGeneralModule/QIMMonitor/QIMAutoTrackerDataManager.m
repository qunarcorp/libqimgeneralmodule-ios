//
//  QIMAutoTrackerDataManager.m
//  QIMGeneralModule
//
//  Created by lilu on 2019/4/22.
//  Copyright © 2019 QIM. All rights reserved.
//

#import "QIMAutoTrackerDataManager.h"
#import "QIMDataBase.h"
#import "QIMDataBasePool.h"
#import "QIMJSONSerializer.h"

@interface QIMAutoTrackerDataManager ()

@property(nonatomic, strong) QIMDataBasePool *dataBasePool;

@property(nonatomic, copy) NSString *logDBPath;

@end

static dispatch_queue_t _traceLoggingQueue;

@implementation QIMAutoTrackerDataManager

static QIMAutoTrackerDataManager *__manager = nil;
static dispatch_once_t _onceTraceDBToken;

+ (instancetype)qimDB_sharedLogDBInstanceWithDBFullJid:(NSString *)dbOwnerFullJid {
    dispatch_once(&_onceTraceDBToken, ^{
        __manager = [[QIMAutoTrackerDataManager alloc] initWithUserId:dbOwnerFullJid];
    });
    return __manager;
}

+ (instancetype)qimDB_sharedLogDBInstance {
//    NSAssert(__manager != nil, @"请先执行qimDB_sharedLogDBInstanceWithDBFullJid:");
    return __manager;
}

- (instancetype)initWithUserId:(NSString *)userFullJid {
    self = [super init];
    if (self) {
        _traceLoggingQueue = dispatch_queue_create("com.qunar.autoTraceLogQueue", 0);
        NSString *logdbPath = [self getLogDBPathWithUserXmppId:userFullJid];
        _logDBPath = logdbPath;
        BOOL notCheckCreateDataBase = [[NSFileManager defaultManager] fileExistsAtPath:_logDBPath] == NO;
        _dataBasePool = [QIMDataBasePool databasePoolWithPath:_logDBPath];
        [self reCreateDB];
    }
    return self;
}

- (void)reCreateDB {
    BOOL notCheckCreateDataBase = [[NSFileManager defaultManager] fileExistsAtPath:_logDBPath] == NO;
    NSArray *paths = [_logDBPath pathComponents];
    NSString *dbValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"dbVersion"];
    NSString *currentValue = [NSString stringWithFormat:@"%@_%lld", [paths objectAtIndex:paths.count - 2], [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"] longLongValue]];
    if (notCheckCreateDataBase || [currentValue isEqualToString:dbValue] == NO) {
        NSLog(@"autoTracker reCreateDB");
        __block BOOL result = NO;
        [_dataBasePool inDatabase:^(QIMDataBase *_Nonnull db) {
            result = [self qim_createLogDB:db];
        }];
        if (result) {
            NSLog(@"创建autoTracker DB文件成功");
            [[NSUserDefaults standardUserDefaults] setObject:currentValue forKey:@"dbVersion"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        } else {
            NSLog(@"创建autoTracker DB文件失败");
        }
    } else {
        NSLog(@"autoTracker notCheckCreateDataBase : %d, [currentValue isEqualToString:dbValue] : %d", notCheckCreateDataBase, [currentValue isEqualToString:dbValue]);
    }
}

- (id)dbInstance {
    return _dataBasePool;
}

- (NSString *)getLogDBPathWithUserXmppId:(NSString *)userJid {

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *logDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"QIMTraceLogs"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:logDirectory]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:logDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *logDBPath = [logDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@/", [userJid lowercaseString]]];
    if (![[NSFileManager defaultManager] fileExistsAtPath:logDBPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:logDBPath withIntermediateDirectories:YES attributes:nil error:nil];
    }
    logDBPath = [logDBPath stringByAppendingPathComponent:@"logs.dat"];
    NSLog(@"用户日志上报TraceLog数据库路径为 %@", logDBPath);
    return logDBPath;
}

- (BOOL)qim_createLogDB:(QIMDataBase *)database {
    BOOL result = NO;
    result = [database executeNonQuery:@"CREATE TABLE IF NOT EXISTS IM_TRACE_LOG(\
              type                TEXT,\
              subType             TEXT,\
              reportTime          TEXT,\
              content             TEXT);" withParameters:nil];
    if (result) {
        result = [database executeNonQuery:@"CREATE INDEX IF NOT EXISTS IX_IM_TRACE_LOG_TYPE ON \
                  IM_TRACE_LOG(type);"
                            withParameters:nil];
        result = [database executeNonQuery:@"CREATE INDEX IF NOT EXISTS IX_IM_TRACE_LOG_SUBTYPE ON \
                  IM_TRACE_LOG(subType);"
                            withParameters:nil];
    }
    return result;
}

- (void)qim_insertTraceLogWithType:(NSString *)type withSubType:(NSString *)subtype withReportTime:(long long)reportTime withLogInfo:(NSString *)logInfo {
    dispatch_async(_traceLoggingQueue, ^{
        [[self dbInstance] syncUsingTransaction:^(QIMDataBase *_Nonnull db, BOOL *_Nonnull rollback) {
            NSString *sql = @"Insert Into IM_TRACE_LOG(type, subType, reportTime, content) values(:type, :subType, :reportTime, :content)";

            NSMutableArray *param = [[NSMutableArray alloc] init];
            [param addObject:type ? type : @":NULL"];
            [param addObject:subtype ? subtype : @":NULL"];
            [param addObject:@(reportTime)];
            [param addObject:logInfo ? logInfo : @":NULL"];
            [db executeNonQuery:sql withParameters:param];
        }];
    });
}

- (NSArray *)qim_getTraceLogWithReportTime:(long long)reportTime {
    __block NSMutableArray *result = nil;
    [[self dbInstance] inDatabase:^(QIMDataBase *_Nonnull database) {
        NSString *sql = @"select content from IM_TRACE_LOG order by reportTime desc";
        DataReader *reader = [database executeReader:sql withParameters:nil];
        while ([reader read]) {
            if (!result) {
                result = [[NSMutableArray alloc] init];
            }
            NSString *traceInfo = [reader objectForColumnIndex:0];
            if (traceInfo.length > 0) {
                NSDictionary *traceInfoDic = [[QIMJSONSerializer sharedInstance] deserializeObject:traceInfo error:nil];
                [result addObject:traceInfoDic];
            }
        }
    }];
    return result;
}

- (void)qim_deleteTraceLog {
    dispatch_async(_traceLoggingQueue, ^{
        [[self dbInstance] syncUsingTransaction:^(QIMDataBase *_Nonnull database, BOOL *_Nonnull rollback) {
            NSString *sql = @"delete from IM_TRACE_LOG";
            [database executeNonQuery:sql withParameters:nil];
        }];
    });
}

@end
