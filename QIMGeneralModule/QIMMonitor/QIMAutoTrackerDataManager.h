//
//  QIMAutoTrackerDataManager.h
//  QIMGeneralModule
//
//  Created by lilu on 2019/4/22.
//  Copyright © 2019 QIM. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QIMAutoTrackerDataManager : NSObject

+ (instancetype)qimDB_sharedLogDBInstanceWithDBFullJid:(NSString *)dbOwnerFullJid;

+ (instancetype)qimDB_sharedLogDBInstance;

- (NSArray *)qim_getTraceLogWithReportTime:(long long)reportTime;

- (void)qim_insertTraceLogWithType:(NSString *)type withSubType:(NSString *)subtype withReportTime:(long long)reportTime withLogInfo:(NSString *)logInfo;

- (void)qim_deleteTraceLog;

@end

NS_ASSUME_NONNULL_END
