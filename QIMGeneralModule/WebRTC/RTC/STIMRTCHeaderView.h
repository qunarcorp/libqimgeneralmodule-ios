//
//  STIMRTCHeaderView.h
//  STChatIphone
//
//  Created by Qunar-Lu on 2017/3/23.
//
//

#import <UIKit/UIKit.h>

@protocol STIMRTCHeaderViewDidClickDelegate <NSObject>

- (void)didClickUserSTIMRTCHeaderViewWithTag:(NSInteger)tag;

@end

@interface STIMRTCHeaderView : UIView

@property(nonatomic, weak) id <STIMRTCHeaderViewDidClickDelegate> rtcHeaderViewDidClickDelegate;

- (instancetype)initWithinitWithFrame:(CGRect)frame userId:(NSString *)userId;

@end
