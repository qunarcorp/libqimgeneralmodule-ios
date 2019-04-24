//
//  QIMAutoTrackerDataManager.m
//  QIMGeneralModule
//
//  Created by lilu on 2019/4/22.
//  Copyright © 2019 QIM. All rights reserved.
//

#import "QIMAutoTrackerDataManager.h"
#import "Database.h"
#import "QIMJSONSerializer.h"

@interface QIMAutoTrackerDataManager ()

@property (nonatomic, copy) NSString *logDBPath;

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
        BOOL isSuccess = [DatabaseManager OpenByFullPath:_logDBPath];
        if (isSuccess == NO) {
            [[NSFileManager defaultManager] removeItemAtPath:_logDBPath error:nil];
            [DatabaseManager OpenByFullPath:_logDBPath];
        }
        if (notCheckCreateDataBase) {
            __block BOOL result = NO;
            [[self dbInstance] syncUsingTransaction:^(Database *database) {
                result = [self qim_createLogDB:database];
            }];
            if (result) {
                NSLog(@"创建TraceLog文件成功");
            } else {
                NSLog(@"创建TraceLog文件失败");
            }
        }
    }
    return self;
}

- (DatabaseOperator *) dbInstance {
    return [DatabaseManager GetInstance:self.logDBPath];
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
    NSLog(@"用户数据库路径为 %@", logDBPath);
    return logDBPath;
}

- (BOOL)qim_createLogDB:(Database *)database {
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
        [[self dbInstance] syncUsingTransaction:^(Database *database) {
            NSString *sql = @"Insert Into IM_TRACE_LOG(type, subType, reportTime, content) values(:type, :subType, :reportTime, :content)";
            
            NSMutableArray *param = [[NSMutableArray alloc] init];
            [param addObject:type?type:@":NULL"];
            [param addObject:subtype?subtype:@":NULL"];
            [param addObject:@(reportTime)];
            [param addObject:logInfo?logInfo:@":NULL"];
            [database executeNonQuery:sql withParameters:param];
        }];
    });
}

- (NSArray *)qim_getTraceLogWithReportTime:(long long)reportTime {
    __block NSMutableArray *result = nil;
    [[self dbInstance] syncUsingTransaction:^(Database *database) {
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
        [[self dbInstance] syncUsingTransaction:^(Database *database) {
            NSString *sql = @"delete from IM_TRACE_LOG";
            [database executeNonQuery:sql withParameters:nil];
        }];
    });
}

@end
