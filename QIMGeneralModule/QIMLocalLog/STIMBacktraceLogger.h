//
//  STIMBacktraceLogger.h
//  STIMBacktraceLogger
//
//  Created by QTalk on 16/8/27.
//  Copyright © 2016年 QTalk. All rights reserved.
//

#import <Foundation/Foundation.h>

#define QTalkLOG NSLog(@"%@",[STIMBacktraceLogger QTalk_backtraceOfCurrentThread]);
#define QTalkLOG_MAIN NSLog(@"%@",[STIMBacktraceLogger QTalk_backtraceOfMainThread]);
#define QTalkLOG_ALL NSLog(@"%@",[STIMBacktraceLogger QTalk_backtraceOfAllThread]);

@interface STIMBacktraceLogger : NSObject

+ (NSString *)qt_backtraceOfAllThread;

+ (NSString *)qt_backtraceOfCurrentThread;

+ (NSString *)qt_backtraceOfMainThread;

+ (NSString *)qt_backtraceOfNSThread:(NSThread *)thread;

@end
