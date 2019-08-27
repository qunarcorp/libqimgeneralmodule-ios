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

@interface QIMAutoTrackerManager ()

@property(nonatomic, strong) dispatch_queue_t trackerDataManagerQueue;

@end

@implementation QIMAutoTrackerManager

+ (instancetype)sharedInstance {
    static id _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[QIMAutoTrackerManager alloc] init];
//        [UIButton startTracker];
//        [UIView startTracker];
//        [UICollectionView startTracker];
//        [UITableView startTracker];
    });
    return _sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.trackerDataManagerQueue = dispatch_queue_create("trackerDataManager Queue", nil);
    }
    return self;
}

#pragma mark - public method

- (void)addACTTrackerDataWithEventId:(NSString *)eventId withDescription:(NSString *)description {
    dispatch_async(self.trackerDataManagerQueue, ^{
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

        NSDictionary *info = @{@"costTime": @(0), @"eventId": eventId ? eventId : @"", @"describtion": description ? description : @"", @"isMainThread": @([NSThread isMainThread]), @"reportTime": @(reportTime), @"sql": @[], @"subType": @"click", @"threadId": @(threadID), @"threadName": threadName ? threadName : @"", @"type": @"ACT"};
        NSString *infoStr = [[QIMJSONSerializer sharedInstance] serializeObject:info];
        [[QIMAutoTrackerDataManager qimDB_sharedLogDBInstance] qim_insertTraceLogWithType:@"ACT" withSubType:@"click" withReportTime:reportTime withLogInfo:infoStr];
    });
}

- (void)addCATTraceData:(NSDictionary *)catDic {
    dispatch_async(self.trackerDataManagerQueue, ^{
        CGFloat costTime = [[catDic objectForKey:@"costTime"] floatValue];
        long long reportTime = [[NSDate date] timeIntervalSince1970] * 1000;
        NSString *threadName = [catDic objectForKey:@"threadName"];
        BOOL isMainThread = [[catDic objectForKey:@"isMainThread"] boolValue];
        NSString *url = [catDic objectForKey:@"url"];
        NSString *method = [catDic objectForKey:@"method"];
        NSString *methodParams = [catDic objectForKey:@"methodParams"];
        NSString *qckey = [catDic objectForKey:@"q_ckey"];
        NSDictionary *describtion = [catDic objectForKey:@"describtion"];
        NSDictionary *requestHeaders = [catDic objectForKey:@"requestHeaders"];
        NSDictionary *ext = [catDic objectForKey:@"ext"];
        
        NSDictionary *info = @{@"costTime": @(costTime), @"url": url ? url : @"", @"method": @"method", @"methodParams": methodParams ? methodParams : @{}, @"describtion": describtion ? describtion : @"", @"isMainThread": @(isMainThread), @"reportTime": @(reportTime), @"sql": @[], @"subType": @"http", @"threadName": threadName ? threadName : @"", @"type": @"CAT", @"requestHeaders": requestHeaders ? requestHeaders : @"", @"ext" : ext ? ext : @{}};
        NSString *infoStr = [[QIMJSONSerializer sharedInstance] serializeObject:info];
        [[QIMAutoTrackerDataManager qimDB_sharedLogDBInstance] qim_insertTraceLogWithType:@"CAT" withSubType:@"http" withReportTime:reportTime withLogInfo:infoStr];
    });
}

- (void)addCodTraceData:(NSDictionary *)sqlDic {
    dispatch_async(self.trackerDataManagerQueue, ^{

    });
}

@end
