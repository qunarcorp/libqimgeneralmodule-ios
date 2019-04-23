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
@property (nonatomic, assign) BOOL isDebug;

/**
 配置数据
 */
@property (nonatomic, strong) NSArray *configArray;

@property (nonatomic, copy) QIMAutoTrackerManagerBlock successBlock;
@property (nonatomic, copy) QIMAutoTrackerManagerBlock debugBlock;

+ (QIMAutoTrackerManager *)sharedInstance;

/**
 开始打点
 
 @param successBlock 成功回调
 @param debugBlock 调试模式回调
 */
- (void)startWithCompletionBlockWithSuccess:(QIMAutoTrackerManagerBlock)successBlock debug:(QIMAutoTrackerManagerBlock)debugBlock;

- (void)addACTTrackerData:(NSString *)eventId;

@end
