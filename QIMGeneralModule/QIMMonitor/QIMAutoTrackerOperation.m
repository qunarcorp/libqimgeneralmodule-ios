//
//  QIMAutoTrackerOperation.m
//  QIMAutoTracker
//
//  Created by lilulucas.li on 2019/04/18.
//

#import "QIMAutoTrackerOperation.h"
#import "QIMAutoTrackerManager.h"
#import "NSObject+QIMAutoTracker.h"

@implementation QIMAutoTrackerOperation

+ (instancetype)sharedInstance {
    static id _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

/**
 发送日志
 
 @param eventId 日志id
 @param info 日志内容
 */
- (void)sendTrackerData:(NSString *)eventId info:(NSDictionary *)info {
    NSDictionary *trackerDictionary = [[NSDictionary alloc] initWithObjectsAndKeys:
                                       eventId.length > 0 ? eventId : @"", QIMAutoTrackerEventIDKey,
                                       info ? info : [[NSDictionary alloc] init], QIMAutoTrackerInfoKey, nil];
    
    if ([QIMAutoTrackerManager sharedInstance].configArray.count > 0 &&
        eventId.length > 0) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(DD_TRACKER_EVENTID_KEY == %@)",eventId];
        NSArray *filtered = [[QIMAutoTrackerManager sharedInstance].configArray filteredArrayUsingPredicate:predicate];
        if ([filtered count] > 0) {
            if ([QIMAutoTrackerManager sharedInstance].successBlock) {
                [QIMAutoTrackerManager sharedInstance].successBlock(trackerDictionary);
            }
        }
    }
    
    if ([QIMAutoTrackerManager sharedInstance].isDebug &&
        [QIMAutoTrackerManager sharedInstance].debugBlock) {
        [QIMAutoTrackerManager sharedInstance].debugBlock(trackerDictionary);
    }
}

@end

