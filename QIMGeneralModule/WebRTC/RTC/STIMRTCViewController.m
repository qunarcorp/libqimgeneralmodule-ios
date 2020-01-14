//
//  RTCViewController.m
//  STChatIphone
//
//  Created by 李海彬 on 2017/5/23.
//
//

#import "STIMRTCViewController.h"
#import "STIMRTCSingleView.h"

@interface STIMRTCViewController ()

@end

@implementation STIMRTCViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:NO];
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)dismiss {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
