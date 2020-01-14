//
//  STIMWebRTCMeetingClient.m
//  STChatIphone
//
//  Created by Qunar-Lu on 2017/3/15.
//
//

#import "STIMWebRTCMeetingClient.h"
#import "STIMWebRTCSocketClient.h"
#import "STIMRTCNSNotification.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreTelephony/CTCallCenter.h>
#import <CoreTelephony/CTCall.h>
#import "STIMRTCView.h"
#import "STIMPublicRedefineHeader.h"
#import "STIMKitPublicHeader.h"
#import "STIMUUIDTools.h"
#import "STIMJSONSerializer.h"
#import "UIView+STIMExtension.h"
#import "STIMNetwork.h"

#import <WebRTC/WebRTC.h>
#import "Masonry.h"
#import "STIMKit+STIMGroup.h"

@interface STIMWebRTCMeetingClient () <STIMWebRTCSocketClientDelegate, RTCPeerConnectionDelegate /*,RTCSessionDescriptionDelegate*/, RTCVideoViewDelegate> {
    RTCConfiguration *_configuration;
    NSMutableArray *_addIceCandidate;
    NSMutableArray *_localIceCandidate;
    BOOL _createRoom;
}

@property(nonatomic, copy) NSString *navServer;
@property(nonatomic, copy) NSString *httpServer;

@property(strong, nonatomic) RTCPeerConnectionFactory *peerConnectionFactory;
@property(nonatomic, strong) RTCMediaConstraints *localPCConstraints;
@property(nonatomic, strong) RTCMediaConstraints *pcConstraints;
@property(nonatomic, strong) RTCMediaConstraints *sdpConstraints;
@property(nonatomic, strong) RTCPeerConnection *localPeerConnection;

@property(nonatomic, strong) RTCVideoTrack *localVideoTrack;
@property(nonatomic, strong) RTCAudioTrack *localAudioTrack;
@property(strong, nonatomic) NSMutableArray *ICEServers;
@property(strong, nonatomic) NSMutableDictionary *peerConnectionDic;
@property(strong, nonatomic) NSMutableArray *roomMembers;
@property(strong, nonatomic) NSMutableDictionary *roomMemberStreams;
@property(strong, nonatomic) NSMutableDictionary *peerConnectionCanDic;
@property(strong, nonatomic) NSMutableDictionary *willSendCanDic;

@property(nonatomic, strong) NSMutableDictionary *remoteVideoTrackDic;

@property(nonatomic, assign) BOOL usingFrontCamera;
@property(nonatomic, strong) RTCCameraVideoCapturer *capturer;
@property(nonatomic, strong) RTCCameraPreviewView *localVideoView;

@end

@implementation STIMWebRTCMeetingClient
static STIMWebRTCMeetingClient *instance = nil;

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[STIMWebRTCMeetingClient alloc] init];
        [instance startEngine];
        instance.usingFrontCamera = YES;
        instance.ICEServers = [NSMutableArray array];
        [instance addNotifications];
    });
    return instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [super allocWithZone:zone];
    });
    return instance;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (RTCMediaConstraints *)defaultPCConstraints {

    NSDictionary *mandatoryConstraints = @{@"OfferToReceiveAudio": @"true", @"OfferToReceiveVideo": @"true"};
    NSDictionary *optionalConstraints = @{@"DtlsSrtpKeyAgreement": @"true", @"googIPv6": @"false"};
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints optionalConstraints:optionalConstraints];
    return constraints;
}

- (RTCMediaConstraints *)defaultLocalPeerConnectionConstraints {
    NSString *value = @"true";
    NSDictionary *mandatoryConstraints = @{@"OfferToReceiveAudio": @"false", @"OfferToReceiveVideo": @"false"};
    NSDictionary *optionalConstraints = @{@"DtlsSrtpKeyAgreement": value, @"googIPv6": @"false"};
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                                                             optionalConstraints:optionalConstraints];
    return constraints;
}

- (RTCMediaConstraints *)defaultSDPConstraints {
    NSDictionary *sdpMandatoryConstraints = @{@"OfferToReceiveAudio": @"true", @"OfferToReceiveVideo": @"true"};
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:sdpMandatoryConstraints optionalConstraints:nil];
    return constraints;
}

- (AVCaptureDevice *)findDeviceForPosition:(AVCaptureDevicePosition)position {
    NSArray<AVCaptureDevice *> *captureDevices = [RTCCameraVideoCapturer captureDevices];
    for (AVCaptureDevice *device in captureDevices) {
        if (device.position == position) {
            return device;
        }
    }
    return captureDevices[0];
}

- (AVCaptureDeviceFormat *)selectFormatForDevice:(AVCaptureDevice *)device {
    NSArray<AVCaptureDeviceFormat *> *formats = [RTCCameraVideoCapturer supportedFormatsForDevice:device];
    int targetWidth = [UIScreen mainScreen].bounds.size.width;
    int targetHeight = [UIScreen mainScreen].bounds.size.height;
    AVCaptureDeviceFormat *selectedFormat = nil;
    int currentDiff = INT_MAX;

    for (AVCaptureDeviceFormat *format in formats) {
        CMVideoDimensions dimension = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
        FourCharCode pixelFormat = CMFormatDescriptionGetMediaSubType(format.formatDescription);
        int diff = abs(targetWidth - dimension.width) + abs(targetHeight - dimension.height);
        if (diff < currentDiff) {
            selectedFormat = format;
            currentDiff = diff;
        } else if (diff == currentDiff && pixelFormat == [_capturer preferredOutputPixelFormat]) {
            selectedFormat = format;
        }
    }

    return selectedFormat;
}

- (NSInteger)selectFpsForFormat:(AVCaptureDeviceFormat *)format {
    Float64 maxFramerate = 0;
    for (AVFrameRateRange *fpsRange in format.videoSupportedFrameRateRanges) {
        maxFramerate = fmax(maxFramerate, fpsRange.maxFrameRate);
    }
    return maxFramerate;
}

- (void)startCapture {
    AVCaptureDevicePosition position = self.usingFrontCamera ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
    AVCaptureDevice *device = [self findDeviceForPosition:position];
    AVCaptureDeviceFormat *format = [self selectFormatForDevice:device];

    if (format == nil) {
        RTCLogError(@"No valid formats for device %@", device);
        NSAssert(NO, @"");

        return;
    }

    NSInteger fps = [self selectFpsForFormat:format];
    [self.capturer startCaptureWithDevice:device format:format fps:fps];
}

/**
 解决前置摄像头录制视频左右颠倒问题
 */
- (void)videoMirored {
    AVCaptureSession *session = (AVCaptureSession *) self.localVideoView.captureSession;
    for (AVCaptureVideoDataOutput *output in session.outputs) {
        for (AVCaptureConnection *av in output.connections) {
            //判断是否是前置摄像头状态
            if (_usingFrontCamera) {
                if (av.supportsVideoMirroring) {
                    //镜像设置
                    av.videoMirrored = YES;
                }
            }
        }
    }
}

- (RTCVideoTrack *)createLocalVideoTrack {

    RTCVideoSource *source = [self.peerConnectionFactory videoSource];

#if !TARGET_IPHONE_SIMULATOR
    STIMVerboseLog(@"sss");
    RTCCameraVideoCapturer *capturer = [[RTCCameraVideoCapturer alloc] initWithDelegate:source];
    self.capturer = capturer;
    self.localVideoView.captureSession = capturer.captureSession;
    [self startCapture];
    [self videoMirored];
#else
#if defined(__IPHONE_11_0) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_11_0)
    if (@available(iOS 10, *)) {
        RTCFileVideoCapturer *fileCapturer = [[RTCFileVideoCapturer alloc] initWithDelegate:source];
//        [fileCapturer startCapturingFromFileNamed:@"Screenrecorde.mp4" onError:^(NSError * _Nonnull error) {
//            STIMVerboseLog(@"error : %@", error);
//        }];
    }
#endif
#endif

    return [self.peerConnectionFactory videoTrackWithSource:source trackId:kARDVideoTrackId];
}

- (void)createMediaSenders {
    RTCMediaConstraints *constraints = [self defaultMediaAudioConstraints];
    RTCAudioSource *source = [_peerConnectionFactory audioSourceWithConstraints:constraints];
    RTCAudioTrack *track = [_peerConnectionFactory audioTrackWithSource:source
                                                                trackId:kARDAudioTrackId];
    [self.localPeerConnection addTrack:track streamIds:@[kARDMediaStreamId]];
    _localVideoTrack = [self createLocalVideoTrack];
    if (_localVideoTrack) {
        [self.localPeerConnection addTrack:_localVideoTrack streamIds:@[kARDMediaStreamId]];
    }
//    RTCMediaStream * stream = [_peerConnectionFactory mediaStreamWithStreamId:kARDMediaStreamId];
//
//    [self.roomMemberStreams setObject:stream forKey:@"kaiming.zhang@ejabhost1"];
//    RTCVideoTrack *videoTrack = stream.videoTracks[0];
//    [self.remoteVideoTrackDic setObject:videoTrack forKey:@"kaiming.zhang@ejabhost1"];
//    dispatch_async(dispatch_get_main_queue(), ^{
//        RTCEAGLVideoView *remoteVideoView = [self.rtcMeetingView addRemoteVideoViewWithUserName:@"kaiming.zhang@ejabhost1" WithUserHeader:YES];
//        [videoTrack addRenderer:remoteVideoView];
//    });
}

- (RTCMediaConstraints *)defaultMediaAudioConstraints {
    NSDictionary *mandatoryConstraints = @{};
    RTCMediaConstraints *constraints = [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                                                             optionalConstraints:nil];
    return constraints;
}

- (void)startEngine {
    RTCDefaultVideoDecoderFactory *decoderFactory = [[RTCDefaultVideoDecoderFactory alloc] init];
    RTCDefaultVideoEncoderFactory *encoderFactory = [[RTCDefaultVideoEncoderFactory alloc] init];
    self.peerConnectionFactory = [[RTCPeerConnectionFactory alloc] initWithEncoderFactory:encoderFactory decoderFactory:decoderFactory];
    self.localPCConstraints = [self defaultLocalPeerConnectionConstraints];
    self.pcConstraints = [self defaultPCConstraints];
    self.sdpConstraints = [self defaultSDPConstraints];
}

- (void)stopEngine {
    [self.peerConnectionFactory stopAecDump];
    _peerConnectionFactory = nil;
}

- (BOOL)calling {
    return self.rtcMeetingView != nil;
}

- (RTCMediaConstraints *)defaultPCMe {
    return nil;
}

- (NSArray *)getICEServicesWithService:(NSDictionary *)service {
    NSString *url = [service objectForKey:@"urls"];
    NSString *userName = [service objectForKey:@"username"];
    NSString *credential = [service objectForKey:@"credential"];
    NSMutableArray *ices = [NSMutableArray array];

    RTCIceServer *iceServer = [[RTCIceServer alloc] initWithURLStrings:@[url] username:userName credential:credential];
    [ices addObject:iceServer];
    return ices;
}

- (void)updateICEServers {
//    https://150.242.184.16:8443
//http://150.242.184.16:8080
//    [[STIMKit sharedInstance] qimNav_VideoUrl]
//    NSString *httpUrl = [NSString stringWithFormat:@"http://150.242.184.16:8080/room/getTurnServers?username=%@",  [[[STIMKit sharedInstance] thirdpartKeywithValue] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
//
        NSString *httpUrl = [NSString stringWithFormat:@"%@getTurnServers?username=%@", [[STIMKit sharedInstance] qimNav_VideoUrl], [[[STIMKit sharedInstance] thirdpartKeywithValue] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        NSURL *url = [NSURL URLWithString:httpUrl];
        STIMHTTPRequest *request = [[STIMHTTPRequest alloc] initWithURL:url];
        [STIMHTTPClient sendRequest:request complete:^(STIMHTTPResponse *response) {
            if (response.code == 200) {
                NSDictionary *infoDic = [[STIMJSONSerializer sharedInstance] deserializeObject:response.data error:nil];
                int errorCode = [[infoDic objectForKey:@"error"] intValue];
                if (errorCode == 0) {
                    NSArray *services = [infoDic objectForKey:@"servers"];
                    for (NSDictionary *service in services) {
                        NSArray *ices = [self getICEServicesWithService:service];
                        [self.ICEServers addObjectsFromArray:ices];
                    }
                }
            }
        }                  failure:^(NSError *error) {
            
        }];
}

- (void)addNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hangupEvent) name:kHangUpMeetingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(switchCamera) name:kSwitchMeetingCameraNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(muteButton:) name:kMuteMeetingNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(videoMuteButton:) name:kVideoCaptureMeetingNotification object:nil];
}


#pragma mark - setter and getter

- (NSMutableDictionary *)roomMemberStreams {
    if (!_roomMemberStreams) {
        _roomMemberStreams = [NSMutableDictionary dictionaryWithCapacity:5];
    }
    return _roomMemberStreams;
}

- (void)muteButton:(NSNotification *)notify {
    BOOL isMute = [[notify.object objectForKey:@"isMute"] boolValue];
    [(RTCMediaStreamTrack *) self.localAudioTrack setIsEnabled:!isMute];
}

- (void)videoMuteButton:(NSNotification *)notify {
    BOOL videoOpen = [[notify.object objectForKey:@"videoCapture"] boolValue];
    [(RTCMediaStreamTrack *) self.localVideoTrack setIsEnabled:videoOpen];
}

- (void)switchCamera {
    _usingFrontCamera = !_usingFrontCamera;
    [self startCapture];
}


- (BOOL)hasOpenRoom {
    return self.rtcMeetingView != nil;
}

- (RTCSessionDescription *)descriptionWithDescription:(RTCSessionDescription *)description videoFormat:(NSString *)videoFormat {
    NSString *sdpString = description.sdp;
    NSString *lineChar = @"\n";
    NSMutableArray *lines = [NSMutableArray arrayWithArray:[sdpString componentsSeparatedByString:lineChar]];
    NSInteger mLineIndex = -1;
    NSString *videoFormatRtpMap = nil;
    NSString *pattern = [NSString stringWithFormat:@"^a=rtpmap:(\\d+) %@(/\\d+)+[\r]?$", videoFormat];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
    for (int i = 0; (i < lines.count) && (mLineIndex == -1 || !videoFormatRtpMap); ++i) {
        // mLineIndex 和 videoFromatRtpMap 都更新了之后跳出循环
        NSString *line = lines[i];
        if ([line hasPrefix:@"m=video"]) {
            mLineIndex = i;
            continue;
        }

        NSTextCheckingResult *result = [regex firstMatchInString:line options:0 range:NSMakeRange(0, line.length)];
        if (result) {
            videoFormatRtpMap = [line substringWithRange:[result rangeAtIndex:1]];
            continue;
        }
    }

    if (mLineIndex == -1) {
        // 没有m = video line, 所以不能转格式,所以返回原来的description
        return description;
    }

    if (!videoFormatRtpMap) {
        // 没有videoFormat 类型的rtpmap。
        return description;
    }

    NSString *spaceChar = @" ";
    NSArray *origSpaceLineParts = [lines[mLineIndex] componentsSeparatedByString:spaceChar];
    if (origSpaceLineParts.count > 3) {
        NSMutableArray *newMLineParts = [NSMutableArray arrayWithCapacity:origSpaceLineParts.count];
        NSInteger origPartIndex = 0;

        [newMLineParts addObject:origSpaceLineParts[origPartIndex++]];
        [newMLineParts addObject:origSpaceLineParts[origPartIndex++]];
        [newMLineParts addObject:origSpaceLineParts[origPartIndex++]];
        [newMLineParts addObject:videoFormatRtpMap];
        for (; origPartIndex < origSpaceLineParts.count; ++origPartIndex) {
            if (![videoFormatRtpMap isEqualToString:origSpaceLineParts[origPartIndex]]) {
                [newMLineParts addObject:origSpaceLineParts[origPartIndex]];
            }
        }

        NSString *newMLine = [newMLineParts componentsJoinedByString:spaceChar];
        [lines replaceObjectAtIndex:mLineIndex withObject:newMLine];
    } else {
        STIMVerboseLog(@"SDP Media description 格式 错误");
    }
    NSString *mangledSDPString = [lines componentsJoinedByString:lineChar];

    return [[RTCSessionDescription alloc] initWithType:description.type sdp:mangledSDPString];
}

- (void)createRoomById:(NSString *)roomId WithRoomName:(NSString *)roomName {
    [self joinRoomById:roomId WithRoomName:roomName];
    _createRoom = YES;
}

- (void)joinRoomByMessage:(NSDictionary *)message {

    if (message) {
        NSString *roomId = [message objectForKey:@"roomName"];
        
        NSString *roomName = [message objectForKey:@"topic"];
        NSString *navServer = [message objectForKey:@"navServ"];
        NSString *httpServer = [message objectForKey:@"server"];
        self.navServer = navServer;
        self.httpServer = httpServer;
        long long startTime = [[message objectForKey:@"startTime"] longLongValue];
        _createRoom = NO;
        NSDictionary * dic =  [[STIMKit sharedInstance] getGroupCardByGroupId:roomId];
        if (dic && dic.count > 0) {
            roomName = dic[@"Name"];
        }
        self.roomName = roomName;
        self.roomId = roomId;
        // 更新ICE Servers
        [self updateICEServers];

        _addIceCandidate = [NSMutableArray array];
        _localIceCandidate = [NSMutableArray array];
        self.willSendCanDic = [NSMutableDictionary dictionary];
        self.roomMembers = [NSMutableArray array];
        self.remoteVideoTrackDic = [NSMutableDictionary dictionary];
        _configuration = [[RTCConfiguration alloc] init];
        [_configuration setIceServers:self.ICEServers];
        [_configuration setIceTransportPolicy:RTCIceTransportPolicyAll];
        [_configuration setRtcpMuxPolicy:RTCRtcpMuxPolicyRequire];
        [_configuration setTcpCandidatePolicy:RTCTcpCandidatePolicyEnabled];
        [_configuration setBundlePolicy:RTCBundlePolicyMaxBundle];
        [_configuration setContinualGatheringPolicy:RTCContinualGatheringPolicyGatherContinually];
        [_configuration setKeyType:RTCEncryptionKeyTypeECDSA];
        [_configuration setCandidateNetworkPolicy:RTCCandidateNetworkPolicyAll];
        // 1.显示视图
        self.rtcMeetingView = [[STIMRTCView alloc] initWithRoomId:roomId WithRoomName:roomName isJoin:YES];
        self.rtcMeetingView.nickName = roomName;
//        self.rtcMeetingView.headerImage = [[STIMKit sharedInstance] getGroupImageFromLocalByGroupId:self.groupId];
        if ([[STIMKit sharedInstance] getCurrentServerTime] - startTime > 24 * 60 * 60 * 1000) {
            [self.rtcMeetingView showAlertMessage:@"该视频会议房间已经超过一天，不能加入。"];
            return;
        } else {
            [self.rtcMeetingView show];
        }

        self.peerConnectionDic = [NSMutableDictionary dictionary];
        self.roomMembers = [NSMutableArray array];
        self.peerConnectionCanDic = [NSMutableDictionary dictionary];
        self.navServer = navServer;
        self.httpServer = httpServer;
    }
}

- (void)answerJoinRoom {

    self.rtcMeetingView.socketClient = [[STIMWebRTCSocketClient alloc] init];
    [self.rtcMeetingView.socketClient setDelegate:self];
    if (!self.navServer || !self.httpServer) {
        [self.rtcMeetingView.socketClient updateSocketHost];
    } else {
        [self.rtcMeetingView.socketClient setNavServerAddress:self.navServer];
        [self.rtcMeetingView.socketClient setHttpsServerAddress:self.httpServer];
    }
    [self initRTCSetting];
    [self.rtcMeetingView.socketClient connectWebRTCRoomServer];
}

- (void)joinRoomById:(NSString *)roomId WithRoomName:(NSString *)roomName {
    _createRoom = NO;
    self.roomName = roomName;
    self.roomId = roomId;
    // 更新ICE Servers
    [self updateICEServers];

    _addIceCandidate = [NSMutableArray array];
    _localIceCandidate = [NSMutableArray array];
    self.willSendCanDic = [NSMutableDictionary dictionary];
    self.roomMembers = [NSMutableArray array];
    self.remoteVideoTrackDic = [NSMutableDictionary dictionary];
    _configuration = [[RTCConfiguration alloc] init];
    [_configuration setIceServers:self.ICEServers];
    [_configuration setIceTransportPolicy:RTCIceTransportPolicyAll];
    [_configuration setRtcpMuxPolicy:RTCRtcpMuxPolicyRequire];
    [_configuration setTcpCandidatePolicy:RTCTcpCandidatePolicyEnabled];
    [_configuration setBundlePolicy:RTCBundlePolicyMaxBundle];
    [_configuration setContinualGatheringPolicy:RTCContinualGatheringPolicyGatherContinually];
    [_configuration setKeyType:RTCEncryptionKeyTypeECDSA];
    [_configuration setCandidateNetworkPolicy:RTCCandidateNetworkPolicyAll];
    // 1.显示视图
    self.rtcMeetingView = [[STIMRTCView alloc] initWithRoomId:roomId WithRoomName:roomName isJoin:NO];
    self.rtcMeetingView.headerImage = [STIMKit defaultGroupHeaderImage];
    self.rtcMeetingView.nickName = roomName;
    [self.rtcMeetingView show];

    self.rtcMeetingView.socketClient = [[STIMWebRTCSocketClient alloc] init];
    [self.rtcMeetingView.socketClient setDelegate:self];

    self.peerConnectionDic = [NSMutableDictionary dictionary];
    self.roomMembers = [NSMutableArray array];
    self.peerConnectionCanDic = [NSMutableDictionary dictionary];
    [self initRTCSetting];
    if (!self.navServer || !self.httpServer) {
        [self.rtcMeetingView.socketClient updateSocketHost];
    } else {
        [self.rtcMeetingView.socketClient setNavServerAddress:self.navServer];
        [self.rtcMeetingView.socketClient setHttpsServerAddress:self.httpServer];
    }
    [self.rtcMeetingView.socketClient connectWebRTCRoomServer];
}

- (void)createPeerConnection {
    // 更新ICE Servers
    if (self.ICEServers.count <= 0) {
        [self updateICEServers];
    }

    //创建PeerConnection
    RTCMediaConstraints *optionalConstraints = [self defaultLocalPeerConnectionConstraints];
    self.localPeerConnection = [self.peerConnectionFactory peerConnectionWithConfiguration:_configuration constraints:optionalConstraints delegate:self];
    STIMVerboseLog(@"self.localPeerConnection : %@", self.localPeerConnection);
}

/**
 *  关于RTC 的设置
 */
- (void)initRTCSetting {

    self.localVideoView = [[RTCCameraPreviewView alloc] init];
    [self.rtcMeetingView.ownImageView addSubview:self.localVideoView];
    [self.localVideoView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.right.bottom.mas_equalTo(0);
    }];

    [self createPeerConnection];
    [self createMediaSenders];
}

- (void)hangupEvent {
    STIMVerboseLog(@"hangupEvent");
    __weak typeof(self) weakSelf = self;
    [self.rtcMeetingView.socketClient leaveRoomComplete:^(BOOL success) {
        [weakSelf.rtcMeetingView.socketClient closeWebRTCRoomServer];
        [weakSelf.rtcMeetingView dismiss];
        [weakSelf cleanCache];
    }];
}

- (void)cleanCache {
    [self.localPeerConnection setDelegate:nil];
    [self.localPeerConnection close];
    for (RTCPeerConnection *connect in self.peerConnectionDic.allValues) {
        [connect setDelegate:nil];
        [connect close];
    }
    // 1.将试图置为nil
    self.rtcMeetingView = nil;

    [self setLocalPeerConnection:nil];
    [self setLocalAudioTrack:nil];
    [self setLocalVideoTrack:nil];
    [self setPeerConnectionDic:nil];
    [self setPeerConnectionCanDic:nil];
    [self setRemoteVideoTrackDic:nil];
    [self setRoomMembers:nil];
    [self setRoomId:nil];
    [self setRoomName:nil];
    [self setGroupId:nil];
}

- (NSString *)getUserNameWithPeerConnection:(RTCPeerConnection *)peerConnection {
    NSString *userName = @"";
    if ([peerConnection isEqual:self.localPeerConnection]) {
        userName = @"我自己";
    } else {
        for (NSString *key in self.peerConnectionDic.allKeys) {
            RTCPeerConnection *pp = [self.peerConnectionDic objectForKey:key];
            if ([pp isEqual:peerConnection]) {
                userName = key;
                break;
            }
        }
    }
    return userName;
}

- (void)setConnectLabelText:(NSString *)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        //[self.rtcMeetingView.connectLabel setStringValue:text];
        [self.rtcMeetingView setContectText:text];
        [self.rtcMeetingView showRoomInfo:text];
    });
}

#pragma mark - RTCPeerConnectionDelegate

// Triggered when the SignalingState changed.
- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeSignalingState:(RTCSignalingState)stateChanged {
    STIMVerboseLog(@"信令状态改变");
    switch (stateChanged) {
        case RTCSignalingStateStable: {
            STIMVerboseLog(@"stateChanged = RTCSignalingStable");
        }
            break;
        case RTCSignalingStateClosed: {
            STIMVerboseLog(@"stateChanged = RTCSignalingClosed");
        }
            break;
        case RTCSignalingStateHaveLocalOffer: {
            STIMVerboseLog(@"stateChanged = RTCSignalingHaveLocalOffer");
        }
            break;
        case RTCSignalingStateHaveLocalPrAnswer: {
            STIMVerboseLog(@"stateChanged = RTCSignalingHaveLocalPrAnswer");
        }
            break;
        case RTCSignalingStateHaveRemoteOffer: {
            STIMVerboseLog(@"stateChanged = RTCSignalingHaveRemoteOffer");
        }
            break;
        case RTCSignalingStateHaveRemotePrAnswer: {
            STIMVerboseLog(@"stateChanged = RTCSignalingHaveRemotePrAnswer");
        }
            break;
        default:
            break;
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didAddStream:(RTCMediaStream *)stream {
    STIMVerboseLog(@"已添加多媒体流");
    STIMVerboseLog(@"Received %lu video tracks and %lu audio tracks",
            (unsigned long) stream.videoTracks.count,
            (unsigned long) stream.audioTracks.count);
    if ([stream.videoTracks count]) {
        if ([peerConnection isEqual:self.localPeerConnection]) {
            STIMVerboseLog(@"");
        } else {
            NSString *userName = [self getUserNameWithPeerConnection:peerConnection];
            STIMVerboseLog(@"userName === %@ : %@", userName, stream);
            [self.roomMemberStreams setObject:stream forKey:userName];
            RTCVideoTrack *videoTrack = stream.videoTracks[0];
            [self.remoteVideoTrackDic setObject:videoTrack forKey:userName];
            dispatch_async(dispatch_get_main_queue(), ^{
                RTCEAGLVideoView *remoteVideoView = [self.rtcMeetingView addRemoteVideoViewWithUserName:userName WithUserHeader:YES];
                [videoTrack addRenderer:remoteVideoView];
            });
        }
    }
}

- (void)addedStreamWithClickUserId:(NSString *)userId {
    if (userId) {
        RTCMediaStream *stream = [self.roomMemberStreams objectForKey:userId];
        if (stream.videoTracks.count) {
            RTCVideoTrack *videoTrack = stream.videoTracks[0];
            dispatch_async(dispatch_get_main_queue(), ^{
                RTCEAGLVideoView *remoteVideoView = [self.rtcMeetingView chooseRemoteVideoViewWithUserName:userId];
                [videoTrack addRenderer:remoteVideoView];
//                [_localVideoTrack addRenderer:videoTrack];
            });
        }
    }
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection didRemoveStream:(RTCMediaStream *)stream {
    STIMVerboseLog(@"Stream was removed.");
}

// Called any time the ICEConnectionState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceConnectionState:(RTCIceConnectionState)newState {
    NSString *user = [self getUserNameWithPeerConnection:peerConnection];
    STIMVerboseLog(@"ICE state changed: %ld", (long) newState);
    switch (newState) {
        case RTCIceConnectionStateNew: {
            STIMVerboseLog(@"user %@ newState = RTCICEConnectionNew", user);
            [self setConnectLabelText:@"连接中..."];
        }
            break;
        case RTCIceConnectionStateChecking: {
            STIMVerboseLog(@"user %@ newState = RTCICEConnectionChecking", user);
            STIMVerboseLog(@"Local ICE LIST %@\r", _localIceCandidate);
            STIMVerboseLog(@"Add ICE LIST %@\r", _addIceCandidate);
        }
            break;
        case RTCIceConnectionStateConnected: {
            STIMVerboseLog(@"user %@ newState = RTCICEConnectionConnected", user);//15:56:56.698 15:56:57.570
            [self setConnectLabelText:@""];
            dispatch_async(dispatch_get_main_queue(), ^{
                //                [self.rtcMeetingView updateButtonState];
            });
            STIMVerboseLog(@"Local ICE LIST %@\r", _localIceCandidate);
            STIMVerboseLog(@"Add ICE LIST %@\r", _addIceCandidate);
        }
            break;
        case RTCIceConnectionStateCompleted: {
            STIMVerboseLog(@"user %@ newState = RTCICEConnectionCompleted", user);//5:56:57.573
            STIMVerboseLog(@"Local ICE LIST RTCIceConnectionStateCompleted %@\r", _localIceCandidate);
            STIMVerboseLog(@"Add ICE LIST RTCIceConnectionStateCompleted %@\r", _addIceCandidate);
        }
            break;
        case RTCIceConnectionStateFailed: {
            STIMVerboseLog(@"user %@ newState = RTCICEConnectionFailed", user);
            [self.rtcMeetingView showAlertMessage:@"连接失败"];
            [self setConnectLabelText:@"连接失败..."];
            //[self hangupEvent];
            STIMVerboseLog(@"Local ICE LIST %@\r", _localIceCandidate);
            STIMVerboseLog(@"Add ICE LIST %@\r", _addIceCandidate);
        }
            break;
        case RTCIceConnectionStateDisconnected: {
            STIMVerboseLog(@"user %@ newState = RTCICEConnectionDisconnected", user);
            [self.rtcMeetingView showAlertMessage:@"连接断开..."];
//            [self setConnectLabelText:@"连接断开..."];
            if ([self.localPeerConnection isEqual:peerConnection]) {
                dispatch_async(dispatch_get_main_queue(), ^{
//                    [self.rtcMeetingView showAlertMessage:@"连接已断开。"];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *userName = [self getUserNameWithPeerConnection:peerConnection];
                    if (userName) {
                        [self.peerConnectionDic removeObjectForKey:userName];
                    }
                });
            }
        }
            break;
        case RTCIceConnectionStateClosed: {
            STIMVerboseLog(@"user %@ newState = RTCICEConnectionClosed", user);
            //            [self setConnectLabelText:@"关闭..."];
            if ([self.localPeerConnection isEqual:peerConnection]) {
                dispatch_async(dispatch_get_main_queue(), ^{
//                    [self.rtcMeetingView showAlertMessage:@"连接已关闭。"];
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *userName = [self getUserNameWithPeerConnection:peerConnection];
                    if (userName) {
                        [self.peerConnectionDic removeObjectForKey:userName];
                    }
                });
            }
        }
            break;
        case RTCIceConnectionStateCount: {
            STIMVerboseLog(@"user %@ newState = RTCICEConnectionMax", user);
            [self setConnectLabelText:@"连接最大数..."];
        }
            break;
    }
}

// Called any time the ICEGatheringState changes.
- (void)peerConnection:(RTCPeerConnection *)peerConnection didChangeIceGatheringState:(RTCIceGatheringState)newState {
    STIMVerboseLog(@"%s", __func__);
    switch (newState) {
        case RTCIceGatheringStateNew: {
            STIMVerboseLog(@"newState = RTCICEGatheringNew");
        }
            break;
        case RTCIceGatheringStateGathering: {
            STIMVerboseLog(@"newState = RTCICEGatheringGathering");
        }
            break;
        case RTCIceGatheringStateComplete: {
            STIMVerboseLog(@"newState = RTCICEGatheringComplete");
        }
            break;
    }
}

// New Ice candidate have been found.
- (void)peerConnection:(RTCPeerConnection *)peerConnection didGenerateIceCandidate:(RTCIceCandidate *)candidate {
    STIMVerboseLog(@"didGenerateIceCandidate %@", candidate);
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([peerConnection isEqual:self.localPeerConnection]) {
            if (self.localPeerConnection.remoteDescription) {
                [self.rtcMeetingView.socketClient sendICECandidateWithEndpointName:[[STIMKit sharedInstance] getLastJid] WithCandidate:candidate.sdp WithSdpMLineIndex:(int) candidate.sdpMLineIndex WithSdpMid:candidate.sdpMid complete:^(BOOL success) {
                    STIMVerboseLog(@"success : %d", success);
                }];
            } else {
                NSString *name = [[STIMKit sharedInstance] getLastJid];
                NSMutableArray *array = [self.willSendCanDic objectForKey:name];
                if (array == nil) {
                    array = [NSMutableArray array];
                    [self.willSendCanDic setObject:array forKey:name];
                }
                [array addObject:candidate];
                [_localIceCandidate addObject:candidate];
            }
        } else {

        }
    });
    STIMVerboseLog(@"新的 Ice candidate 被发现. %@", candidate);
}

/** New data channel has been opened. */
- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didOpenDataChannel:(RTCDataChannel *)dataChannel {

    NSString *userName = [self getUserNameWithPeerConnection:peerConnection];
    STIMVerboseLog(@"New data channel has been opened. %@", userName);
}

- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection {
    STIMVerboseLog(@"WARNING: Renegotiation needed but unimplemented.");
}

#pragma mark - WebRTC Socket Delegate


- (void)receveRemoteVideoWithUserName:(NSString *)user WithStream:(NSArray *)streams WithFinishHandle:(void(^)(void))handle{
    RTCPeerConnection *peerConnection = [self.peerConnectionDic objectForKey:user];
    if (peerConnection == nil) {
        peerConnection = [self.peerConnectionFactory peerConnectionWithConfiguration:_configuration constraints:self.pcConstraints delegate:self];
        [self.peerConnectionDic setObject:peerConnection forKey:user];
    }
    __weak __typeof(self) weakSelf = self;
    [peerConnection offerForConstraints:self.pcConstraints completionHandler:^(RTCSessionDescription *_Nullable sdp, NSError *_Nullable error) {
        STIMVerboseLog(@"receveRemoteVideoWithUserName: %@, SDP : %@", user, sdp);
        RTCLogError(@"receveRemoteVideoWithUserName : %@, Error : %@", user, error);
        dispatch_async(dispatch_get_main_queue(), ^{
            RTCSessionDescription *sdpH264 = [weakSelf descriptionWithDescription:sdp videoFormat:@"VP8"];
            [peerConnection setLocalDescription:sdpH264 completionHandler:^(NSError *_Nullable error) {
                if (error) {
                    handle();
                    STIMVerboseLog(@"setLocalDescription Error : %@", error);
                } else {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        RTCPeerConnection *peerConnection = [weakSelf.peerConnectionDic objectForKey:user];
                        NSString *stream = nil;
                        if (streams.count > 0) {
                            stream = [[streams objectAtIndex:0] objectForKey:@"id"];
                        }
                        if (stream == nil) {
                            stream = @"webcam";
                        }
                        NSString *sender = [NSString stringWithFormat:@"%@_%@", user, stream];
                        [weakSelf.rtcMeetingView.socketClient receiveVideoFromWithSender:sender WithOfferSdp:peerConnection.localDescription.sdp complete:^(NSDictionary *result) {
                            NSString *sdpAnswer = [result objectForKey:@"sdpAnswer"];
                            RTCSessionDescription *remoteSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:sdpAnswer];
                            
                            [peerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError *_Nullable error) {
                                if (error) {
//                                    handle();
                                    STIMVerboseLog(@"remoteSdpremoteSdpremoteSdpremoteSdpremoteSdpremoteSdp");
                                } else {
                                    
//                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        RTCPeerConnection *peerConnection = [weakSelf.peerConnectionDic objectForKey:user];
                                        NSArray *list = [weakSelf.peerConnectionCanDic objectForKey:user];
                                        for (RTCIceCandidate *can in list) {
                                            [peerConnection addIceCandidate:can];
                                        }
                                        [weakSelf.peerConnectionCanDic removeObjectForKey:user];
//                                    });
                                }
                            }];
                            handle();
                        }];
                    });
                }
            }];
        });
    }];
}

- (void)receveRemoteVideoWithUserName:(NSString *)user WithStream:(NSArray *)streams {
    [self receveRemoteVideoWithUserName:user WithStream:streams WithFinishHandle:^{
        
    }];
}

// Connected Server
- (void)webRTCSocketClientDidConnected:(STIMWebRTCSocketClient *)client {
    __weak STIMWebRTCMeetingClient *mySelf = self;
    [mySelf.rtcMeetingView.socketClient joinRoom:mySelf.roomId WithTopic:mySelf.roomName WithNickName:[[STIMKit sharedInstance] getLastJid] complete:^(NSDictionary *resultDic) {
        NSDictionary *result = [resultDic objectForKey:@"result"];
        if (result) {
            NSArray *userList = [result objectForKey:@"value"];
            [mySelf.roomMembers addObjectsFromArray:userList];
            if (_createRoom) {
                // 发送创建房间的Xmpp消息
                NSMutableDictionary *messageDic = [NSMutableDictionary dictionary];
                [messageDic setObject:mySelf.rtcMeetingView.roomId ? mySelf.rtcMeetingView.roomId : [[STIMKit sharedInstance] getLastJid] forKey:@"roomName"];
                [messageDic setObject:mySelf.rtcMeetingView.roomName ? mySelf.rtcMeetingView.roomName : [STIMUUIDTools UUID] forKey:@"topic"];
                [messageDic setObject:@(600) forKey:@"ttl"];
                [messageDic setObject:[mySelf.rtcMeetingView.socketClient getRTCServerAdress] forKey:@"navServ"];
                [messageDic setObject:@([[STIMKit sharedInstance] getCurrentServerTime]) forKey:@"createTime"];
                [messageDic setObject:[[STIMKit sharedInstance] getLastJid] forKey:@"creator"];
                [messageDic setObject:@([[STIMKit sharedInstance] getCurrentServerTime]) forKey:@"startTime"];
                [messageDic setObject:[mySelf.rtcMeetingView.socketClient getServerAdress] forKey:@"server"];
                NSString *extendInfo = [[STIMJSONSerializer sharedInstance] serializeObject:messageDic];
                STIMMessageModel *msg = [[STIMKit sharedInstance] sendMessage:@"[当前客户端不支持音视频]" WithInfo:extendInfo ToGroupId:mySelf.groupId WithMsgType:STIMMessageTypeWebRtcMsgTypeVideoGroup];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationMessageUpdate object:mySelf.groupId userInfo:@{@"message": msg}];
                });
            }
            //判断房间里是否有人先接受再发送
            if (userList.count > 0) {
//                for (NSDictionary *value in userList) {
//                    NSString *user = [value objectForKey:@"id"];
//                    NSArray *streams = [value objectForKey:@"streams"];
//                    NSNumber *plat = [value objectForKey:@"plat"];
//                    //                                                [self.userPlatDic setObject:plat?@(plat.intValue):@(-1) forKey:user];
////                    [self receveRemoteVideoWithUserName:user WithStream:streams];
//                    [self sendReceveRemoteVideoMesWithListWithUserList:<#(NSArray *)#> FinishHandler:<#^(void)handler#>]
//                }
                [mySelf sendReceveRemoteVideoMesWithListWithUserList:userList FinishHandler:^{
                    [mySelf sendOfferConstrainsWithUserList:userList];
                }];
            }
            else{
                [mySelf sendOfferConstrainsWithUserList:userList];
            }
            
            
        } else {
            NSDictionary *errorDic = [resultDic objectForKey:@"error"];
            int errorCode = [[errorDic objectForKey:@"code"] intValue];
            NSString *errorMsg = [errorDic objectForKey:@"message"];
            [mySelf.rtcMeetingView showAlertMessage:[NSString stringWithFormat:@"加入房间失败，%d:%@", errorCode, errorMsg]];
        }
    }];
}

- (void)sendReceveRemoteVideoMesWithListWithUserList:(NSArray *)userList FinishHandler:(void(^)(void))handler{
    
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_queue_t queue = dispatch_get_global_queue(0, 0);
    dispatch_group_async(group, queue, ^{
        
        for (NSDictionary *value in userList) {
            dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
            NSString *user = [value objectForKey:@"id"];
            NSArray *streams = [value objectForKey:@"streams"];
            NSNumber *plat = [value objectForKey:@"plat"];
            //                                                [self.userPlatDic setObject:plat?@(plat.intValue):@(-1) forKey:user];
    //        [self receveRemoteVideoWithUserName:user WithStream:streams];
            [self receveRemoteVideoWithUserName:user WithStream:streams WithFinishHandle:^{
                dispatch_semaphore_signal(semaphore);
            }];
            dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        }
    });
    
    dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 执行下面的判断代码
            dispatch_async(dispatch_get_main_queue(), ^{
                handler();
            });
    });
}

- (void)sendOfferConstrainsWithUserList:(NSArray *)userList{
    __weak STIMWebRTCMeetingClient *mySelf = self;
    [self.localPeerConnection offerForConstraints:self.sdpConstraints completionHandler:^(RTCSessionDescription *_Nullable sdp, NSError *_Nullable error) {
        RTCLogError(@"offerForConstraints : %@", error);
        if (error == nil) {
            dispatch_async(dispatch_get_main_queue(), ^{
                RTCSessionDescription *sdpH264 = [mySelf descriptionWithDescription:sdp videoFormat:@"VP8"];
                [mySelf.localPeerConnection setLocalDescription:sdpH264 completionHandler:^(NSError *_Nullable error) {
                    if (error) {
                        STIMVerboseLog(@"error : %@", error);
                    }
                }];
                [mySelf.rtcMeetingView.socketClient publishVideoWithOfferSdp:sdp.sdp doLoopback:NO complete:^(NSDictionary *result) {
                    if (result) {
                        NSString *sdpAnswer = [result objectForKey:@"sdpAnswer"];
                        RTCSessionDescription *remoteSdp = [[RTCSessionDescription alloc] initWithType:RTCSdpTypeAnswer sdp:sdpAnswer];
                        [mySelf.localPeerConnection setRemoteDescription:remoteSdp completionHandler:^(NSError *_Nullable error) {
                            if (error) {
                                STIMVerboseLog(@"error2 : %@", error);
                            } else {
                                dispatch_async(dispatch_get_main_queue(), ^{
                                    // 这里切了次线程 莫名其妙的 好使了
                                    // 感觉 Webrtc的所有对象初始化放到主线程比较好使 没有任何原因 不知道为什么
                                    NSString *myUserName = [[STIMKit sharedInstance] getLastJid];
                                    for (RTCIceCandidate *candidate in  [mySelf.willSendCanDic objectForKey:myUserName]) {
                                        [mySelf.rtcMeetingView.socketClient sendICECandidateWithEndpointName:myUserName WithCandidate:candidate.sdp WithSdpMLineIndex:candidate.sdpMLineIndex WithSdpMid:candidate.sdpMid complete:^(BOOL success) {
                                            if (success) {
                                                STIMVerboseLog(@"RTCIceCandidate RTCIceCandidate success");
                                            } else {
                                                STIMVerboseLog(@"fafaf");
                                            }
                                            
                                        }];
                                    }
                                    [mySelf.willSendCanDic removeObjectForKey:myUserName];
                                    NSArray *list = [mySelf.peerConnectionCanDic objectForKey:myUserName];
                                    for (RTCIceCandidate *can in list) {
                                        [mySelf.localPeerConnection addIceCandidate:can];
                                    }
                                    [mySelf.peerConnectionCanDic removeObjectForKey:myUserName];
                                    if (userList.count <= 0) {
                                        for (NSDictionary *value in userList) {
                                            NSString *user = [value objectForKey:@"id"];
                                            NSArray *streams = [value objectForKey:@"streams"];
                                            NSNumber *plat = [value objectForKey:@"plat"];
                                            //                                                [self.userPlatDic setObject:plat?@(plat.intValue):@(-1) forKey:user];
                                            [self receveRemoteVideoWithUserName:user WithStream:streams];
                                            
                                        }
                                    }
                                });
                            }
                        }];
                    }
                }];
            });
        }
    }];
}

// Closed
- (void)webRTCSocketClient:(STIMWebRTCSocketClient *)client didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    [self.rtcMeetingView showAlertMessage:[NSString stringWithFormat:@"视频会议连接被关闭，[%ld]%@", (long) code, reason]];
}

//
- (void)webRTCSocketClient:(STIMWebRTCSocketClient *)client didFailWithError:(NSError *)error {
    [self.rtcMeetingView showAlertMessage:[NSString stringWithFormat:@"连接视频会议服务器失败，%@", error]];
}

//Participant joined event
//Event sent by server to all other participants in the room as a result of a new user joining in.
//
//Method: participantJoined
//Parameters:
//
//id: the new participant’s id (username)
- (void)participantJoinedWithUserName:(NSString *)userName {
    NSString *user = userName;
    RTCPeerConnection *peerConnection = [self.peerConnectionFactory peerConnectionWithConfiguration:_configuration constraints:self.pcConstraints delegate:self];
    [self.peerConnectionDic setObject:peerConnection forKey:user];

    [peerConnection offerForConstraints:self.pcConstraints completionHandler:^(RTCSessionDescription *_Nullable sdp, NSError *_Nullable error) {
        RTCSessionDescription *sdpH264 = [self descriptionWithDescription:sdp videoFormat:@"VP8"];
        [peerConnection setLocalDescription:sdpH264 completionHandler:^(NSError *_Nullable error) {
            if (error) {
                STIMVerboseLog(@"participantJoinedWithUserName Error : %@", error);
            }
        }];
    }];
}

//Participant published event
//Event sent by server to all other participants in the room as a result of a user publishing her local media stream.
//
//Method: participantPublished
//Parameters:
//
//id: publisher’s username
//streams: list of stream identifiers that the participant has opened to connect with the room. As only webcam is supported, will always be [{"id":"webcam"}].
- (void)participantPublishedWithUserName:(NSString *)userName WithStreams:(NSArray *)streams {
    STIMVerboseLog(@"%s", __func__);
    [self receveRemoteVideoWithUserName:userName WithStream:streams];
}

//Participant unpublished event
//Event sent by server to all other participants in the room as a result of a user having stopped publishing her local media stream.
//
//Method: participantUnpublished
//Parameters:
//
//name - publisher’s username
- (void)participantUnpublishedWithUserName:(NSString *)userName {
    STIMVerboseLog(@"%s", __func__);
    // 会议成员取消了 输入流
}

//Receive ICE Candidate event
//Server event that carries info about an ICE candidate gathered on the server side. This information is required to implement the trickle ICE mechanism. Will be received by the client whenever a new candidate is gathered for the local peer on the server.
//
//Method: iceCandidate
//Parameters:
//
//endpointName: the name of the peer whose ICE candidate was found
//candidate: the candidate attribute information
//sdpMLineIndex: the index (starting at zero) of the m-line in the SDP this candidate is associated with
//sdpMid: media stream identification, “audio” or “video”, for the m-line this candidate is associated with
- (void)addIceCandidateWithUserName:(NSString *)userName WithCandidate:(NSString *)candidate WithSdpMLineIndex:(int)sdpMLineIndex WithSdpMid:(NSString *)sdpMid {

    RTCIceCandidate *cand = [[RTCIceCandidate alloc] initWithSdp:candidate sdpMLineIndex:sdpMLineIndex sdpMid:sdpMid];
    if ([userName isEqualToString:[[STIMKit sharedInstance] getLastJid]]) {
        if ([self.localPeerConnection remoteDescription]) {
            [self.localPeerConnection addIceCandidate:cand];
        } else {
            STIMVerboseLog(@"");
            NSMutableArray *list = [self.peerConnectionCanDic objectForKey:[[STIMKit sharedInstance] getLastJid]];
            if (list == nil) {
                list = [NSMutableArray array];
                [self.peerConnectionCanDic setObject:list forKey:[[STIMKit sharedInstance] getLastJid]];
            }
            [list addObject:cand];
        }
        [_addIceCandidate addObject:cand];
    } else {
        RTCPeerConnection *peerConnection = [self.peerConnectionDic objectForKey:userName];
        if ([peerConnection remoteDescription]) {
            [peerConnection addIceCandidate:cand];
        } else {
            STIMVerboseLog(@"");
            NSMutableArray *list = [self.peerConnectionCanDic objectForKey:userName];
            if (list == nil) {
                list = [NSMutableArray array];
                [self.peerConnectionCanDic setObject:list forKey:userName];
            }
            [list addObject:cand];
        }
        [_addIceCandidate addObject:cand];
    }
    STIMVerboseLog(@"Add ICE Candidate %@", self.peerConnectionCanDic);
}

//Participant left event
//Event sent by server to all other participants in the room as a consequence of an user leaving the room.
//
//Method: participantLeft
//Parameters:
//
//name: username of the participant that has disconnected
- (void)participantLeftWithUserName:(NSString *)userName {
    STIMVerboseLog(@"participantLeftWithUserName : %@", userName);
    RTCPeerConnection *connection = [self.peerConnectionDic objectForKey:userName];
    [connection setDelegate:nil];
    [connection close];
    [self.peerConnectionDic removeObjectForKey:userName];
    [self.peerConnectionCanDic removeObjectForKey:userName];
    [self.willSendCanDic removeObjectForKey:userName];
    [self.rtcMeetingView removeRemoteVideoViewWithUserName:userName];
    if (self.peerConnectionDic.count <= 0) {
        [self hangupEvent];
    }
}

//Participant evicted event
//Event sent by server to a participant in the room as a consequence of a server-side action requiring the participant to leave the room.
//
//Method: participantEvicted
//Parameters: NONE
- (void)participantLeft {
    STIMVerboseLog(@"%s", __func__);
}

//Message sent event
//Broadcast event that propagates a written message to all room participants.
//
//Method: sendMessage
//Parameters:
//
//room: current room name
//name: username of the text message source
//message: the text message
- (void)receiveMessage:(NSString *)message WithUserName:(NSString *)userName WithRoomName:(NSString *)roomName {
    STIMVerboseLog(@"%s", __func__);
}

//Media error event
//Event sent by server to all participants affected by an error event intercepted on a media pipeline or media element.
//
//Method: mediaError
//Parameters:
//
//error: description of the error
- (void)mediaError:(NSString *)error {
    STIMVerboseLog(@"%s", __func__);
}

#pragma mark - RTCEAGLVideoViewDelegate

- (void)videoView:(RTCEAGLVideoView *)videoView didChangeVideoSize:(CGSize)size {
    if (videoView == self.localVideoView) {
        STIMVerboseLog(@"local size === %@", NSStringFromCGSize(size));
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.rtcMeetingView setLocalVideoViewSize:size];
            [self.rtcMeetingView updateVideoView];
        });
    }
}

-(void)changeView{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.rtcMeetingView.ownImageView removeAllSubviews];

//        [self.rtcView.masterView removeAllSubviews];
//        [self.rtcView.otherView removeAllSubviews];
//        [self.rtcView.masterView addSubview:self.localVideoView];
//        [self.rtcView.otherView addSubview:self.remoteVideoView];
//        [self updateMakeConstraints];
//        self.rtcView.isRemoteVideoFront = NO;
    });
}

@end

