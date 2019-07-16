//
//  QIMAutoTrackerOperation.h
//  QIMAutoTracker
//
//  Created by lilulucas.li on 2019/04/18.
//

#import <Foundation/Foundation.h>

@interface QIMAutoTrackerOperation : NSObject

+ (QIMAutoTrackerOperation *)sharedInstance;

/**
 发送日志
 
 @param eventId 事件id
 @param info 日志内容
 */
- (void)sendTrackerData:(NSString *)eventId info:(NSDictionary *)info;

- (void)uploadTracerData;

@end
