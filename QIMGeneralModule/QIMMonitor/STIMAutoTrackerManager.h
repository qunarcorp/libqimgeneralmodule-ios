//
//  STIMAutoTrackerManager.h
//  STIMAutoTracker
//
//  Created by lihaibin.lilucas.li on 2019/04/18.
//

#import <Foundation/Foundation.h>

static NSString *STIMAutoTrackerEventIDKey = @"DD_TRACKER_EVENTID_KEY";
static NSString *STIMAutoTrackerInfoKey = @"DD_TRACKER_INFO_KEY";

typedef void(^STIMAutoTrackerManagerBlock)(NSDictionary *trackerDictionary);

@interface STIMAutoTrackerManager : NSObject

/**
 是否开启调试模式
 */
@property(nonatomic, assign) BOOL isDebug;

/**
 配置数据
 */
@property(nonatomic, strong) NSArray *configArray;

@property(nonatomic, copy) STIMAutoTrackerManagerBlock successBlock;
@property(nonatomic, copy) STIMAutoTrackerManagerBlock debugBlock;

+ (STIMAutoTrackerManager *)sharedInstance;

- (void)addACTTrackerDataWithEventId:(NSString *)eventId withDescription:(NSString *)description;

- (void)addCATTraceData:(NSDictionary *)catDic;

@end
