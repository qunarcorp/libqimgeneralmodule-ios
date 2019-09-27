//
//  QIMRTCSettingStore.m
//  QIMGeneralModule
//
//  Created by qitmac000645 on 2019/9/25.
//

#import "QIMRTCSettingStore.h"

static NSString *const kVideoResolutionKey = @"rtc_video_resolution_key";
static NSString *const kVideoCodecKey = @"rtc_video_codec_info_key";
static NSString *const kBitrateKey = @"rtc_max_bitrate_key";
static NSString *const kAudioOnlyKey = @"rtc_audio_only_key";
static NSString *const kCreateAecDumpKey = @"rtc_create_aec_dump_key";
static NSString *const kUseLevelControllerKey = @"rtc_use_level_controller_key";
static NSString *const kUseManualAudioConfigKey = @"rtc_use_manual_audio_config_key";

@interface QIMRTCSettingStore()
{
    NSUserDefaults *_storage;
}
@end

@implementation QIMRTCSettingStore

+ (void)setDefaultsForVideoResolution:(NSString *)videoResolution
                           videoCodec:(NSData *)videoCodec
                              bitrate:(nullable NSNumber *)bitrate
                            audioOnly:(BOOL)audioOnly
                        createAecDump:(BOOL)createAecDump
                   useLevelController:(BOOL)useLevelController
                 useManualAudioConfig:(BOOL)useManualAudioConfig {
    NSMutableDictionary<NSString *, id> *defaultsDictionary = [@{
                                                                 kAudioOnlyKey : @(audioOnly),
                                                                 kCreateAecDumpKey : @(createAecDump),
                                                                 kUseLevelControllerKey : @(useLevelController),
                                                                 kUseManualAudioConfigKey : @(useManualAudioConfig)
                                                                 } mutableCopy];
    
    if (videoResolution) {
        defaultsDictionary[kVideoResolutionKey] = videoResolution;
    }
    if (videoCodec) {
        defaultsDictionary[kVideoCodecKey] = videoCodec;
    }
    if (bitrate) {
        defaultsDictionary[kBitrateKey] = bitrate;
    }
    [[NSUserDefaults standardUserDefaults] registerDefaults:defaultsDictionary];
}

- (NSUserDefaults *)storage {
    if (!_storage) {
        _storage = [NSUserDefaults standardUserDefaults];
    }
    return _storage;
}

- (NSString *)videoResolution {
    return [self.storage objectForKey:kVideoResolutionKey];
}

- (void)setVideoResolution:(NSString *)resolution {
    [self.storage setObject:resolution forKey:kVideoResolutionKey];
    [self.storage synchronize];
}

- (NSData *)videoCodec {
    return [self.storage objectForKey:kVideoCodecKey];
}

- (void)setVideoCodec:(NSData *)videoCodec {
    [self.storage setObject:videoCodec forKey:kVideoCodecKey];
    [self.storage synchronize];
}

- (nullable NSNumber *)maxBitrate {
    return [self.storage objectForKey:kBitrateKey];
}

- (void)setMaxBitrate:(nullable NSNumber *)value {
    [self.storage setObject:value forKey:kBitrateKey];
    [self.storage synchronize];
}

- (BOOL)audioOnly {
    return [self.storage boolForKey:kAudioOnlyKey];
}

- (void)setAudioOnly:(BOOL)audioOnly {
    [self.storage setBool:audioOnly forKey:kAudioOnlyKey];
    [self.storage synchronize];
}

- (BOOL)createAecDump {
    return [self.storage boolForKey:kCreateAecDumpKey];
}

- (void)setCreateAecDump:(BOOL)createAecDump {
    [self.storage setBool:createAecDump forKey:kCreateAecDumpKey];
    [self.storage synchronize];
}

- (BOOL)useLevelController {
    return [self.storage boolForKey:kUseLevelControllerKey];
}

- (void)setUseLevelController:(BOOL)useLevelController {
    [self.storage setBool:useLevelController forKey:kUseLevelControllerKey];
    [self.storage synchronize];
}

- (BOOL)useManualAudioConfig {
    return [self.storage boolForKey:kUseManualAudioConfigKey];
}

- (void)setUseManualAudioConfig:(BOOL)useManualAudioConfig {
    [self.storage setBool:useManualAudioConfig forKey:kUseManualAudioConfigKey];
    [self.storage synchronize];
}

@end
