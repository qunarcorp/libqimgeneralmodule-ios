//
//  QIMAutoTrackerManager.h
//  QIMAutoTracker
//
//  Created by lilulucas.li on 2019/04/18.
//

#import <Foundation/Foundation.h>

static NSString *QIMAutoTrackerEventIDKey = @"DD_TRACKER_EVENTID_KEY";
static NSString *QIMAutoTrackerInfoKey = @"DD_TRACKER_INFO_KEY";

typedef void(^QIMAutoTrackerManagerBlock)(NSDictionary *trackerDictionary);

@interface QIMAutoTrackerManager : NSObject

/**
 是否开启调试模式
 */
@property(nonatomic, assign) BOOL isDebug;

/**
 配置数据
 */
@property(nonatomic, strong) NSArray *configArray;

@property(nonatomic, copy) QIMAutoTrackerManagerBlock successBlock;
@property(nonatomic, copy) QIMAutoTrackerManagerBlock debugBlock;

+ (QIMAutoTrackerManager *)sharedInstance;

- (void)addACTTrackerDataWithEventId:(NSString *)eventId withDescription:(NSString *)description;

- (void)addCATTraceData:(NSDictionary *)catDic;

@end
