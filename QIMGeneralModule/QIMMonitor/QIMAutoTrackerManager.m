//
//  QIMAutoTrackerManager.m
//  QIMAutoTracker
//
//  Created by lilulucas.li on 2019/04/18.
//

#import "QIMAutoTrackerManager.h"
#import "UIButton+QIMAutoTracker.h"
#import "UITableView+QIMAutoTracker.h"
#import "UICollectionView+QIMAutoTracker.h"
#import "UIView+QIMAutoTracker.h"
#import "QIMAutoTrackerDataManager.h"
#import "QIMJSONSerializer.h"
#import <pthread.h>

@implementation QIMAutoTrackerManager

+ (instancetype)sharedInstance {
    static id _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

#pragma mark - public method
/**
 开始打点
 
 @param successBlock 成功回调
 @param debugBlock 调试模式回调
 */
- (void)startWithCompletionBlockWithSuccess:(QIMAutoTrackerManagerBlock)successBlock debug:(QIMAutoTrackerManagerBlock)debugBlock {
    static dispatch_once_t once;
    dispatch_once(&once, ^ {
        [QIMAutoTrackerDataManager qimDB_sharedLogDBInstanceWithDBFullJid:@"lilulucas.li@ejabhost1"];
//        [UIButton startTracker];
//        [UITableView startTracker];
//        [UICollectionView startTracker];
//        [UIView startTracker];
    });
    
    self.successBlock = successBlock;
    self.debugBlock = debugBlock;
}

- (void)addACTTrackerDataWithEventId:(NSString *)eventId withDescription:(NSString *)description {
    
     /*
     
     "costTime": 0,
     "describtion": "首页-搜索",
     "isMainThread": true,
     "reportTime": 1548233117648,
     "sql": [],
     "subType": "click",
     "threadId": 1,
     "threadName": "main",
     "type": "ACT"
     }
     */
    
    __uint64_t tid;
    NSInteger threadID = 0;
    if (pthread_threadid_np(NULL, &tid) == 0) {
        threadID = tid;
    } else {
        threadID = 0;
    }
    NSString *threadName = NSThread.currentThread.name;
    long long reportTime = [[NSDate date] timeIntervalSince1970] * 1000;
    
    NSDictionary *info = @{@"costTime":@(0), @"eventId":eventId, @"describtion":description, @"isMainThread":@([NSThread isMainThread]), @"reportTime":@(reportTime), @"sql":@[], @"subType":@"click", @"threadId":@(threadID), @"threadName":threadName?threadName:@"", @"type":@"ACT"};
    NSString *infoStr = [[QIMJSONSerializer sharedInstance] serializeObject:info];
    [[QIMAutoTrackerDataManager qimDB_sharedLogDBInstance] qim_insertTraceLogWithType:@"ACT" withSubType:@"click" withReportTime:reportTime withLogInfo:infoStr];
    NSLog(@"这里保存一下数据库 : %@", infoStr);
}

- (void)addCODTraceData:(NSString *)sql {
    
}

@end
