//
//  QIMRTCSettingModel.h
//  QIMGeneralModule
//
//  Created by qitmac000645 on 2019/9/25.
//

#import <Foundation/Foundation.h>
#import <WebRTC/WebRTC.h>
NS_ASSUME_NONNULL_BEGIN

@interface QIMRTCSettingModel : NSObject

/**
 * Returns array of available capture resoultions.
 *
 * The capture resolutions are represented as strings in the following format
 * [width]x[height]
 */
- (NSArray<NSString *> *)availableVideoResolutions;

/**
 * Returns current video resolution string.
 * If no resolution is in store, default value of 640x480 is returned.
 * When defaulting to value, the default is saved in store for consistency reasons.
 */
- (NSString *)currentVideoResolutionSettingFromStore;
- (int)currentVideoResolutionWidthFromStore;
- (int)currentVideoResolutionHeightFromStore;

/**
 * Stores the provided video resolution string into the store.
 *
 * If the provided resolution is no part of the available video resolutions
 * the store operation will not be executed and NO will be returned.
 * @param resolution the string to be stored.
 * @return YES/NO depending on success.
 */
- (BOOL)storeVideoResolutionSetting:(NSString *)resolution;

/**
 * Returns array of available video codecs.
 */
- (NSArray<RTCVideoCodecInfo *> *)availableVideoCodecs;

/**
 * Returns current video codec setting from store if present or default (H264) otherwise.
 */
- (RTCVideoCodecInfo *)currentVideoCodecSettingFromStore;

/**
 * Stores the provided video codec setting into the store.
 *
 * If the provided video codec is not part of the available video codecs
 * the store operation will not be executed and NO will be returned.
 * @param video codec settings the string to be stored.
 * @return YES/NO depending on success.
 */
- (BOOL)storeVideoCodecSetting:(RTCVideoCodecInfo *)videoCodec;

/**
 * Returns current max bitrate setting from store if present.
 */
- (nullable NSNumber *)currentMaxBitrateSettingFromStore;

/**
 * Stores the provided bitrate value into the store.
 *
 * @param bitrate NSNumber representation of the max bitrate value.
 */
- (void)storeMaxBitrateSetting:(nullable NSNumber *)bitrate;

/**
 * Returns current audio only setting from store if present or default (NO) otherwise.
 */
- (BOOL)currentAudioOnlySettingFromStore;

/**
 * Stores the provided audio only setting into the store.
 *
 * @param setting the boolean value to be stored.
 */
- (void)storeAudioOnlySetting:(BOOL)audioOnly;

/**
 * Returns current create AecDump setting from store if present or default (NO) otherwise.
 */
- (BOOL)currentCreateAecDumpSettingFromStore;

/**
 * Stores the provided create AecDump setting into the store.
 *
 * @param setting the boolean value to be stored.
 */
- (void)storeCreateAecDumpSetting:(BOOL)createAecDump;

/**
 * Returns current setting whether to use level controller from store if present or default (NO)
 * otherwise.
 */
- (BOOL)currentUseLevelControllerSettingFromStore;

/**
 * Stores the provided use level controller setting into the store.
 *
 * @param setting the boolean value to be stored.
 */
- (void)storeUseLevelControllerSetting:(BOOL)useLevelController;

/**
 * Returns current setting whether to use manual audio config from store if present or default (YES)
 * otherwise.
 */
- (BOOL)currentUseManualAudioConfigSettingFromStore;

/**
 * Stores the provided use manual audio config setting into the store.
 *
 * @param setting the boolean value to be stored.
 */
- (void)storeUseManualAudioConfigSetting:(BOOL)useManualAudioConfig;

@end

NS_ASSUME_NONNULL_END
