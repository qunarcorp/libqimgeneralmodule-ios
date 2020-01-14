//
//  NSObject+STIMAutoTracker.h
//  STIMAutoTracker
//
//  Created by lihaibin.lilucas.li on 2019/04/18.
//

#import <Foundation/Foundation.h>

@interface NSObject (STIMAutoTracker)

@property(nonatomic, strong) NSDictionary *ddInfoDictionary;

- (void)configInfoData:(id)obj;

@end
