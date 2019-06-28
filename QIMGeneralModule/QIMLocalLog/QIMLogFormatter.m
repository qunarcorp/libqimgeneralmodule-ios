//
//  QIMLogFormatter.m
//  QIMGeneralModule
//
//  Created by 李露 on 2018/9/5.
//  Copyright © 2018年 QIM. All rights reserved.
//

#import "QIMLogFormatter.h"

@implementation QIMLogFormatter

- (NSString *)formatLogMessage:(DDLogMessage *)logMessage {
    NSString *logLevel; // 日志等级
    switch (logMessage->_flag) {
        case DDLogFlagError    :
            logLevel = @"Error";
            break;
        case DDLogFlagWarning  :
            logLevel = @"Warning";
            break;
        case DDLogFlagInfo     :
            logLevel = @"Info";
            break;
        case DDLogFlagDebug    :
            logLevel = @"Debug";
            break;
        default                :
            logLevel = @"Verbose";
            break;
    }

    NSString *dateAndTime = [logMessage.timestamp descriptionWithLocale:[NSLocale currentLocale]]; // 日期和时间
//    NSString *logFileName = logMessage -> _fileName; // 文件名
    NSString *threadName = logMessage->_threadID;
    NSString *logFunction = logMessage->_function; // 方法名
//    NSUInteger logLine = logMessage -> _line;        // 行号
    NSString *logMsg = logMessage->_message;         // 日志消息

    // 日志格式：日期和时间 文件名 方法名 : 行数 <日志等级> 日志消息
    return [NSString stringWithFormat:@"%@ 【Thread-%@】 %@ : %@", dateAndTime, threadName, logFunction, logMsg];
}

@end
