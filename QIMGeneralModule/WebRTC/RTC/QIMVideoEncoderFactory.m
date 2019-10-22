//
//  QIMVideoEncoderFactory.m
//  QIMGeneralModule
//
//  Created by qitmac000645 on 2019/9/25.
//

#import "QIMVideoEncoderFactory.h"
//#import <WebRTC/RTCvideoen>
#import <WebRTC/RTCVideoEncoderVP8.h>
#import <WebRTC/RTCVideoEncoderVP9.h>
@implementation QIMVideoEncoderFactory
@synthesize preferredCodec;

- (id<RTCVideoEncoder>)createEncoder:(RTCVideoCodecInfo *)info {
    if ([info.name isEqualToString:kRTCVideoCodecH264Name]) {
        return [[RTCVideoEncoderH264 alloc] initWithCodecInfo:info];
    } else if ([info.name isEqualToString:kRTCVideoCodecVp8Name]) {
        return [RTCVideoEncoderVP8 vp8Encoder];
    } else if ([info.name isEqualToString:kRTCVideoCodecVp9Name]) {
        return [RTCVideoEncoderVP9 vp9Encoder];
    }
    
    return nil;
}

- (NSArray<RTCVideoCodecInfo *> *)supportedCodecs {
    NSMutableArray<RTCVideoCodecInfo *> *codecs = [NSMutableArray array];
    
    NSDictionary<NSString *, NSString *> *constrainedHighParams = @{
                                                                    @"profile-level-id" : kRTCLevel31ConstrainedHigh,
                                                                    @"level-asymmetry-allowed" : @"1",
                                                                    @"packetization-mode" : @"1",
                                                                    };
    RTCVideoCodecInfo *constrainedHighInfo =
    [[RTCVideoCodecInfo alloc] initWithName:kRTCVideoCodecH264Name
                                 parameters:constrainedHighParams];
    [codecs addObject:constrainedHighInfo];
    
    NSDictionary<NSString *, NSString *> *constrainedBaselineParams = @{
                                                                        @"profile-level-id" : kRTCLevel31ConstrainedBaseline,
                                                                        @"level-asymmetry-allowed" : @"1",
                                                                        @"packetization-mode" : @"1",
                                                                        };
    RTCVideoCodecInfo *constrainedBaselineInfo =
    [[RTCVideoCodecInfo alloc] initWithName:kRTCVideoCodecH264Name
                                 parameters:constrainedBaselineParams];
    [codecs addObject:constrainedBaselineInfo];
    
    RTCVideoCodecInfo *vp8Info =
    [[RTCVideoCodecInfo alloc] initWithName:kRTCVideoCodecVp8Name parameters:nil];
    [codecs addObject:vp8Info];
    
    RTCVideoCodecInfo *vp9Info =
    [[RTCVideoCodecInfo alloc] initWithName:kRTCVideoCodecVp9Name parameters:nil];
    [codecs addObject:vp9Info];
    
    NSMutableArray<RTCVideoCodecInfo *> *orderedCodecs = [NSMutableArray array];
    NSUInteger index = [codecs indexOfObject:self.preferredCodec];
    if (index != NSNotFound) {
        [orderedCodecs addObject:[codecs objectAtIndex:index]];
        [codecs removeObjectAtIndex:index];
    }
    [orderedCodecs addObjectsFromArray:codecs];
    
    return [orderedCodecs copy];
}

@end
