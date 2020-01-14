//
//  STIMAutoTrackerOperation.m
//  STIMAutoTracker
//
//  Created by lihaibin.lilucas.li on 2019/04/18.
//

#import "STIMAutoTrackerOperation.h"
#import "STIMAutoTrackerManager.h"
#import "NSObject+STIMAutoTracker.h"
#import "STIMAutoTrackerDataManager.h"
#import "STIMKitPublicHeader.h"
#import "STIMJSONSerializer.h"
#import "STIMDataController.h"

@implementation STIMAutoTrackerOperation

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
            eventId.length > 0 ? eventId : @"", STIMAutoTrackerEventIDKey,
            info ? info : [[NSDictionary alloc] init], STIMAutoTrackerInfoKey, nil];

    if ([STIMAutoTrackerManager sharedInstance].configArray.count > 0 &&
            eventId.length > 0) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(DD_TRACKER_EVENTID_KEY == %@)", eventId];
        NSArray *filtered = [[STIMAutoTrackerManager sharedInstance].configArray filteredArrayUsingPredicate:predicate];
        if ([filtered count] > 0) {
            if ([STIMAutoTrackerManager sharedInstance].successBlock) {
                [STIMAutoTrackerManager sharedInstance].successBlock(trackerDictionary);
            }
        }
    }

    if ([STIMAutoTrackerManager sharedInstance].isDebug &&
            [STIMAutoTrackerManager sharedInstance].debugBlock) {
        [STIMAutoTrackerManager sharedInstance].debugBlock(trackerDictionary);
    }
}

- (void)uploadTracerData {
    if ([[STIMKit sharedInstance] qimNav_UploadLog].length > 0) {
        long long reportTime = [[NSDate date] timeIntervalSince1970] * 1000;
        NSArray *traceLogs = [[STIMAutoTrackerDataManager stIMDB_sharedLogDBInstance] stimDB_getTraceLogWithReportTime:reportTime];
        if (traceLogs.count > 0) {
            NSMutableDictionary *oldNavConfigUrlDict = [[STIMKit sharedInstance] userObjectForKey:@"QC_CurrentNavDict"];
            NSLog(@"本地找到的oldNavConfigUrlDict : %@", oldNavConfigUrlDict);
            NSString *navUrl = [oldNavConfigUrlDict objectForKey:@"NavUrl"];
            NSString *uid = [STIMKit getLastUserName];
            NSString *domain = [[STIMKit sharedInstance] getDomain];
            NSMutableDictionary *result = [NSMutableDictionary dictionaryWithCapacity:3];
            if (uid.length && domain.length) {
                NSDictionary *userInfo = @{@"uid": uid, @"domain": domain, @"nav": navUrl};
                [result setObject:userInfo forKey:@"user"];

                NSMutableDictionary *deviceInfo = [NSMutableDictionary dictionaryWithCapacity:3];
                /*
                 "os": "iOS",
                 "osBrand": "iPhoneXMax",
                 "osModel": "iPhoneXMax",
                 "osVersion": 26,
                 "versionCode": 218,
                 "versionName": "3.1.0",
                 "plat": "qtalk",
                 "ip": "127.0.0.1",
                 "lat": "39.983605",
                 "lgt": "116.312536",
                 "net": "WIFI"
                 */
                NSString *os = @"iOS";
                NSString *osBrand = [[STIMKit sharedInstance] deviceName];
                NSString *osModel = [[STIMKit sharedInstance] deviceName];
                NSString *osVersion = [[STIMKit sharedInstance] SystemVersion];
                NSString *versionCode = [[STIMKit sharedInstance] AppBuildVersion];
                NSString *versionName = [[STIMKit sharedInstance] AppVersion];
                NSString *plat = [STIMKit getSTIMProjectTitleName];
                
                long long dbSize = [[STIMDataController getInstance] sizeOfDBPath];
                long long dbWalSize = [[STIMDataController getInstance] sizeOfDBWALPath];
                NSString *dbSizeStr = [[STIMDataController getInstance] transfromTotalSize:dbSize];
                NSString *dbWalSizeStr = [[STIMDataController getInstance] transfromTotalSize:dbWalSize];
                
                NSString *allDBSize = [NSString stringWithFormat:@"DBDataSize : %@, DBDataWalSize : %@", dbSizeStr, dbWalSizeStr];

                [deviceInfo setObject:os forKey:@"os"];
                [deviceInfo setObject:osBrand forKey:@"osBrand"];
                [deviceInfo setObject:osModel forKey:@"osModel"];
                [deviceInfo setObject:osVersion forKey:@"osVersion"];
                [deviceInfo setObject:versionCode forKey:@"versionCode"];
                [deviceInfo setObject:versionName forKey:@"versionName"];
                [deviceInfo setObject:plat forKey:@"plat"];
                [deviceInfo setObject:allDBSize ? allDBSize : @"" forKey:@"DBSize"];

                [result setObject:deviceInfo forKey:@"device"];

                [result setObject:traceLogs forKey:@"infos"];

                NSData *data = [[STIMJSONSerializer sharedInstance] serializeObject:result error:nil];
                [[STIMKit sharedInstance] sendTPPOSTRequestWithUrl:[[STIMKit sharedInstance] qimNav_UploadLog] withRequestBodyData:data withSuccessCallBack:^(NSData *responseData) {
                    NSLog(@"清除本地日志上报数据");
                    [[STIMAutoTrackerDataManager stIMDB_sharedLogDBInstance] stimDB_deleteTraceLog];
                }                              withFailedCallBack:^(NSError *error) {

                }];
            }
        }
    }
}

@end

