//
//  QIMVideoDecoderFactory.m
//  QIMGeneralModule
//
//  Created by qitmac000645 on 2019/9/25.
//

#import "QIMVideoDecoderFactory.h"

@implementation QIMVideoDecoderFactory

- (id<RTCVideoDecoder>)createDecoder:(RTCVideoCodecInfo *)info {
    if ([info.name isEqualToString:@"H264"]) {
        return [[RTCVideoDecoderH264 alloc] init];
    } else if ([info.name isEqualToString:@"VP8"]) {
        return [RTCVideoDecoderVP8 vp8Decoder];
    } else if ([info.name isEqualToString:@"VP9"]) {
        return [RTCVideoDecoderVP9 vp9Decoder];
    }
    
    return nil;
}

- (NSArray<RTCVideoCodecInfo *> *)supportedCodecs {
    return @[
             [[RTCVideoCodecInfo alloc] initWithName:@"H264" parameters:nil],
             [[RTCVideoCodecInfo alloc] initWithName:@"VP8" parameters:nil],
             [[RTCVideoCodecInfo alloc] initWithName:@"VP9" parameters:nil]
             ];
}
@end
