//
//  QIMRTCSettingStore.h
//  QIMGeneralModule
//
//  Created by qitmac000645 on 2019/9/25.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QIMRTCSettingStore : NSObject
+ (void)setDefaultsForVideoResolution:(NSString *)videoResolution
                           videoCodec:(NSData *)videoCodec
                              bitrate:(nullable NSNumber *)bitrate
                            audioOnly:(BOOL)audioOnly
                        createAecDump:(BOOL)createAecDump
                   useLevelController:(BOOL)useLevelController
                 useManualAudioConfig:(BOOL)useManualAudioConfig;

@property(nonatomic) NSString *videoResolution;
@property(nonatomic) NSData *videoCodec;

/**
 * Returns current max bitrate number stored in the store.
 */
- (nullable NSNumber *)maxBitrate;

/**
 * Stores the provided value as maximum bitrate setting.
 * @param value the number to be stored
 */
- (void)setMaxBitrate:(nullable NSNumber *)value;

@property(nonatomic) BOOL audioOnly;
@property(nonatomic) BOOL createAecDump;
@property(nonatomic) BOOL useLevelController;
@property(nonatomic) BOOL useManualAudioConfig;

@end

NS_ASSUME_NONNULL_END
