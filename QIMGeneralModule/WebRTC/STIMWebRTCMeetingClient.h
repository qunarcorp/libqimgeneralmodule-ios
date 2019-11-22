//
//  STIMWebRTCMeetingClient.h
//  qunarChatIphone
//
//  Created by Qunar-Lu on 2017/3/15.
//
//

#import <Foundation/Foundation.h>

@class STIMRTCView;

@interface STIMWebRTCMeetingClient : NSObject

@property(nonatomic, strong) STIMRTCView *rtcMeetingView;
@property(strong, nonatomic) NSString *roomId;
@property(strong, nonatomic) NSString *roomName;
@property(strong, nonatomic) NSString *groupId;

+ (instancetype)sharedInstance;

- (void)startEngine;

- (void)stopEngine;

- (void)createRoomById:(NSString *)roomId WithRoomName:(NSString *)roomName;

- (void)joinRoomById:(NSString *)roomId WithRoomName:(NSString *)roomName;

- (void)joinRoomByMessage:(NSDictionary *)message;

- (BOOL)hasOpenRoom;

- (void)answerJoinRoom;

- (void)addedStreamWithClickUserId:(NSString *)userId;


@end
