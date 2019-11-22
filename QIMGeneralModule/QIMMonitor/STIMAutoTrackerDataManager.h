//
//  STIMAutoTrackerDataManager.h
//  STIMGeneralModule
//
//  Created by lilu on 2019/4/22.
//  Copyright © 2019 STIM. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface STIMAutoTrackerDataManager : NSObject

+ (instancetype)stIMDB_sharedLogDBInstanceWithDBFullJid:(NSString *)dbOwnerFullJid;

+ (instancetype)stIMDB_sharedLogDBInstance;

- (NSArray *)stimDB_getTraceLogWithReportTime:(long long)reportTime;

- (void)stimDB_insertTraceLogWithType:(NSString *)type withSubType:(NSString *)subtype withReportTime:(long long)reportTime withLogInfo:(NSString *)logInfo;

- (void)stimDB_deleteTraceLog;

@end

NS_ASSUME_NONNULL_END
