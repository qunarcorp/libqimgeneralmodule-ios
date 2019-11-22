//
//  UIButton+STIMAutoTracker.m
//  STIMAutoTracker
//
//  Created by lilulucas.li on 2019/04/18.
//

#import "UIButton+STIMAutoTracker.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <pthread.h>
#import "STIMAutoTrackerOperation.h"
#import "NSObject+STIMAutoTracker.h"
#import "STIMAutoTrackerManager.h"

@implementation UIButton (STIMAutoTracker)

+ (void)startTracker {
    Method endTrackingMethod = class_getInstanceMethod(self, @selector(endTrackingWithTouch:withEvent:));
    Method qimEndTrackingMethod = class_getInstanceMethod(self, @selector(stimDB_endTrackingWithTouch:withEvent:));
    method_exchangeImplementations(endTrackingMethod, qimEndTrackingMethod);
}

- (void)stimDB_endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event {
    //只监听UIButton
    if (![self isKindOfClass:[UIButton class]]) {
        return;
    }

    [self stimDB_endTrackingWithTouch:touch withEvent:event];
    NSArray *targers = [self.allTargets allObjects];
    if (targers.count > 0) {
        NSArray *actions = [self actionsForTarget:[targers firstObject] forControlEvent:UIControlEventTouchUpInside];
        if (actions.count > 0 &&
                [[actions firstObject] length] > 0) {

            NSString *eventId = [NSString stringWithFormat:@"%@&&%@", NSStringFromClass([[targers firstObject] class]), [actions firstObject]];
            if (self.accessibilityIdentifier.length > 0) {
                eventId = [NSString stringWithFormat:@"%@&&%@&&%@", NSStringFromClass([self class]), [actions firstObject], [self accessibilityIdentifier]];
            }
            [[STIMAutoTrackerManager sharedInstance] addACTTrackerDataWithEventId:eventId withDescription:eventId];
        }
    }
}

@end
