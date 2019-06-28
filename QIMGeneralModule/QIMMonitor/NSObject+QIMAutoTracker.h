//
//  NSObject+QIMAutoTracker.h
//  QIMAutoTracker
//
//  Created by lilulucas.li on 2019/04/18.
//

#import <Foundation/Foundation.h>

@interface NSObject (QIMAutoTracker)

@property(nonatomic, strong) NSDictionary *ddInfoDictionary;

- (void)configInfoData:(id)obj;

@end
