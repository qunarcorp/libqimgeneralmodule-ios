//
//  QIMVideoEncoderFactory.h
//  QIMGeneralModule
//
//  Created by qitmac000645 on 2019/9/25.
//

#import <Foundation/Foundation.h>
//#import <WebRTC/RTCVideoCodecFactory.h>
#import <WebRTC/WebRTC.h>
NS_ASSUME_NONNULL_BEGIN

@interface QIMVideoEncoderFactory : NSObject<RTCVideoEncoderFactory>
@property(nonatomic, retain) RTCVideoCodecInfo* preferredCodec;

@end

NS_ASSUME_NONNULL_END
