//
//  UIButton+QIMAutoTracker.m
//  QIMAutoTracker
//
//  Created by lilulucas.li on 2019/04/18.
//

#import "UIButton+QIMAutoTracker.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <pthread.h>
#import "QIMAutoTrackerOperation.h"
#import "NSObject+QIMAutoTracker.h"

@implementation UIButton (QIMAutoTracker)

+ (void)startTracker {
    Method endTrackingMethod = class_getInstanceMethod(self, @selector(endTrackingWithTouch:withEvent:));
    Method ddEndTrackingMethod = class_getInstanceMethod(self, @selector(dd_endTrackingWithTouch:withEvent:));
    method_exchangeImplementations(endTrackingMethod, ddEndTrackingMethod);
}

- (void)dd_endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    //只监听UIButton
    if (![self isKindOfClass:[UIButton class]]) {
        return;
    }
    
    [self dd_endTrackingWithTouch:touch withEvent:event];
    NSArray *targers = [self.allTargets allObjects];
    if (targers.count > 0) {
        NSArray *actions = [self actionsForTarget:[targers firstObject] forControlEvent:UIControlEventTouchUpInside];
        if (actions.count > 0 &&
            [[actions firstObject] length] > 0) {
            
            NSString *eventId = [NSString stringWithFormat:@"%@&&%@",NSStringFromClass([[targers firstObject] class]),[actions firstObject]];
            if (self.accessibilityIdentifier.length > 0) {
                eventId = [NSString stringWithFormat:@"%@&&%@&&%@",NSStringFromClass([self class]),[actions firstObject], [self accessibilityIdentifier]];
            }
            NSDictionary *infoDictionary = [[targers firstObject] ddInfoDictionary];
            NSLog(@"dd_endTrackingWithTouch : %@", eventId);
            
            __uint64_t tid;
            NSInteger threadID = 0;
            if (pthread_threadid_np(NULL, &tid) == 0) {
                threadID = tid;
            } else {
                threadID = 0;
            }
            NSString *threadName = NSThread.currentThread.name;
            long long reportTime = [[NSDate date] timeIntervalSince1970] * 1000;
            
            NSDictionary *info = @{@"costTime":@(0), @"describtion":eventId, @"isMainThread":@([NSThread isMainThread]), @"reportTime":@(reportTime), @"sql":@[], @"subType":@"click", @"threadId":@(threadID), @"threadName":threadName?threadName:@"", @"type":@"ACT"};
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
            [[QIMAutoTrackerOperation sharedInstance] sendTrackerData:eventId
                                                                info:infoDictionary];
        }
    }
}

@end
