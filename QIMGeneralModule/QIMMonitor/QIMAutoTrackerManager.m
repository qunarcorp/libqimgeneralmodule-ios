//
//  QIMAutoTrackerManager.m
//  QIMAutoTracker
//
//  Created by lilulucas.li on 2019/04/18.
//

#import "QIMAutoTrackerManager.h"
#import "UIButton+QIMAutoTracker.h"
#import "UITableView+QIMAutoTracker.h"
#import "UICollectionView+QIMAutoTracker.h"
#import "UIView+QIMAutoTracker.h"

@implementation QIMAutoTrackerManager

+ (instancetype)sharedInstance {
    static id _sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
    });
    return _sharedInstance;
}

#pragma mark - public method
/**
 开始打点
 
 @param successBlock 成功回调
 @param debugBlock 调试模式回调
 */
- (void)startWithCompletionBlockWithSuccess:(QIMAutoTrackerManagerBlock)successBlock debug:(QIMAutoTrackerManagerBlock)debugBlock {
    static dispatch_once_t once;
    dispatch_once(&once, ^ {
        [UIButton startTracker];
        [UITableView startTracker];
        [UICollectionView startTracker];
        [UIView startTracker];
    });
    
    self.successBlock = successBlock;
    self.debugBlock = debugBlock;
}

@end
