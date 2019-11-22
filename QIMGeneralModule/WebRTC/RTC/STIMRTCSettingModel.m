//
//  STIMRTCSettingModel.m
//  STIMGeneralModule
//
//  Created by qitmac000645 on 2019/9/25.
//

#import "STIMRTCSettingModel.h"
#import "STIMVideoEncoderFactory.h"
#import "STIMRTCSettingStore.h"

@interface STIMRTCSettingModel()
@property(nonatomic , strong) STIMRTCSettingStore * settingsStore;
@end
@implementation STIMRTCSettingModel

- (NSArray<NSString *> *)availableVideoResolutions {
    NSMutableSet<NSArray<NSNumber *> *> *resolutions =
    [[NSMutableSet<NSArray<NSNumber *> *> alloc] init];
    for (AVCaptureDevice *device in [RTCCameraVideoCapturer captureDevices]) {
        for (AVCaptureDeviceFormat *format in
             [RTCCameraVideoCapturer supportedFormatsForDevice:device]) {
            CMVideoDimensions resolution =
            CMVideoFormatDescriptionGetDimensions(format.formatDescription);
            NSArray<NSNumber *> *resolutionObject = @[ @(resolution.width), @(resolution.height) ];
            [resolutions addObject:resolutionObject];
        }
    }
    
    NSArray<NSArray<NSNumber *> *> *sortedResolutions =
    [[resolutions allObjects] sortedArrayUsingComparator:^NSComparisonResult(
                                                                             NSArray<NSNumber *> *obj1, NSArray<NSNumber *> *obj2) {
        return obj1.firstObject > obj2.firstObject;
    }];
    
    NSMutableArray<NSString *> *resolutionStrings = [[NSMutableArray<NSString *> alloc] init];
    for (NSArray<NSNumber *> *resolution in sortedResolutions) {
        NSString *resolutionString =
        [NSString stringWithFormat:@"%@x%@", resolution.firstObject, resolution.lastObject];
        [resolutionStrings addObject:resolutionString];
    }
    
    return [resolutionStrings copy];
}

- (NSString *)currentVideoResolutionSettingFromStore {
    [self registerStoreDefaults];
    return [[self settingsStore] videoResolution];
}

- (BOOL)storeVideoResolutionSetting:(NSString *)resolution {
    if (![[self availableVideoResolutions] containsObject:resolution]) {
        return NO;
    }
    [[self settingsStore] setVideoResolution:resolution];
    return YES;
}

- (NSArray<RTCVideoCodecInfo *> *)availableVideoCodecs {
    NSArray<RTCVideoCodecInfo *> *supportedCodecs =
    [[[STIMVideoEncoderFactory alloc] init] supportedCodecs];
    return supportedCodecs;
}

- (RTCVideoCodecInfo *)currentVideoCodecSettingFromStore {
    [self registerStoreDefaults];
    NSData *codecData = [[self settingsStore] videoCodec];
    return [NSKeyedUnarchiver unarchiveObjectWithData:codecData];
}

- (BOOL)storeVideoCodecSetting:(RTCVideoCodecInfo *)videoCodec {
    if (![[self availableVideoCodecs] containsObject:videoCodec]) {
        return NO;
    }
    NSData *codecData = [NSKeyedArchiver archivedDataWithRootObject:videoCodec];
    [[self settingsStore] setVideoCodec:codecData];
    return YES;
}

- (nullable NSNumber *)currentMaxBitrateSettingFromStore {
    [self registerStoreDefaults];
    return [[self settingsStore] maxBitrate];
}

- (void)storeMaxBitrateSetting:(nullable NSNumber *)bitrate {
    [[self settingsStore] setMaxBitrate:bitrate];
}

- (BOOL)currentAudioOnlySettingFromStore {
    return [[self settingsStore] audioOnly];
}

- (void)storeAudioOnlySetting:(BOOL)audioOnly {
    [[self settingsStore] setAudioOnly:audioOnly];
}

- (BOOL)currentCreateAecDumpSettingFromStore {
    return [[self settingsStore] createAecDump];
}

- (void)storeCreateAecDumpSetting:(BOOL)createAecDump {
    [[self settingsStore] setCreateAecDump:createAecDump];
}

- (BOOL)currentUseLevelControllerSettingFromStore {
    return [[self settingsStore] useLevelController];
}

- (void)storeUseLevelControllerSetting:(BOOL)useLevelController {
    [[self settingsStore] setUseLevelController:useLevelController];
}

- (BOOL)currentUseManualAudioConfigSettingFromStore {
    return [[self settingsStore] useManualAudioConfig];
}

- (void)storeUseManualAudioConfigSetting:(BOOL)useManualAudioConfig {
    [[self settingsStore] setUseManualAudioConfig:useManualAudioConfig];
}

#pragma mark - Testable

- (STIMRTCSettingStore *)settingsStore {
    if (!_settingsStore) {
        _settingsStore = [[STIMRTCSettingStore alloc] init];
        [self registerStoreDefaults];
    }
    return _settingsStore;
}

- (int)currentVideoResolutionWidthFromStore {
    NSString *resolution = [self currentVideoResolutionSettingFromStore];
    
    return [self videoResolutionComponentAtIndex:0 inString:resolution];
}

- (int)currentVideoResolutionHeightFromStore {
    NSString *resolution = [self currentVideoResolutionSettingFromStore];
    return [self videoResolutionComponentAtIndex:1 inString:resolution];
}

#pragma mark -

- (NSString *)defaultVideoResolutionSetting {
    return [self availableVideoResolutions].firstObject;
}

- (RTCVideoCodecInfo *)defaultVideoCodecSetting {
    return [self availableVideoCodecs].firstObject;
}

- (int)videoResolutionComponentAtIndex:(int)index inString:(NSString *)resolution {
    if (index != 0 && index != 1) {
        return 0;
    }
    NSArray<NSString *> *components = [resolution componentsSeparatedByString:@"x"];
    if (components.count != 2) {
        return 0;
    }
    return components[index].intValue;
}

- (void)registerStoreDefaults {
    NSString *defaultVideoResolutionSetting = [self defaultVideoResolutionSetting];
    BOOL audioOnly = (defaultVideoResolutionSetting.length == 0);
    
    // The iOS simulator doesn't provide any sort of camera capture
    // support or emulation (http://goo.gl/rHAnC1) so don't bother
    // trying to open a local stream.
#if TARGET_IPHONE_SIMULATOR
    audioOnly = YES;
#endif
    
    NSData *codecData = [NSKeyedArchiver archivedDataWithRootObject:[self defaultVideoCodecSetting]];
    [STIMRTCSettingStore setDefaultsForVideoResolution:[self defaultVideoResolutionSetting]
                                         videoCodec:codecData
                                            bitrate:nil
                                          audioOnly:audioOnly
                                      createAecDump:NO
                                 useLevelController:NO
                               useManualAudioConfig:YES];
}

@end
