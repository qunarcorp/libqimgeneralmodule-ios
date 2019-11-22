//
//  UIView+STIMAutoTracker.m
//  STIMAutoTracker
//
//  Created by lilulucas.li on 2019/04/18.
//

#import "UIView+STIMAutoTracker.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "STIMAutoTrackerOperation.h"
#import "NSObject+STIMAutoTracker.h"
#import "STIMAutoTrackerManager.h"

@implementation UIView (STIMAutoTracker)

+ (void)startTracker {
    Method addGestureRecognizerMethod = class_getInstanceMethod(self, @selector(addGestureRecognizer:));
    Method qimAddGestureRecognizerMethod = class_getInstanceMethod(self, @selector(stimDB_addGestureRecognizer:));
    method_exchangeImplementations(addGestureRecognizerMethod, qimAddGestureRecognizerMethod);
}

- (void)stimDB_addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer {
    [self stimDB_addGestureRecognizer:gestureRecognizer];
    //只监听UITapGestureRecognizer事件
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        Ivar targetsIvar = class_getInstanceVariable([UIGestureRecognizer class], "_targets");
        id targetActionPairs = object_getIvar(gestureRecognizer, targetsIvar);

        Class targetActionPairClass = NSClassFromString(@"UIGestureRecognizerTarget");
        Ivar targetIvar = class_getInstanceVariable(targetActionPairClass, "_target");
        Ivar actionIvar = class_getInstanceVariable(targetActionPairClass, "_action");

        for (id targetActionPair in targetActionPairs) {
            id target = object_getIvar(targetActionPair, targetIvar);
            SEL action = (__bridge void *) object_getIvar(targetActionPair, actionIvar);
            if (target && action) {
                Class class = [target class];
                SEL originSelector = action;
                SEL swizzlSelector = NSSelectorFromString(@"stimDB_didTapView");
                BOOL didAddMethod = class_addMethod(class, swizzlSelector, (IMP) stimDB_didTapView, "v@:@@");
                if (didAddMethod) {
                    Method originMethod = class_getInstanceMethod(class, swizzlSelector);
                    Method swizzlMethod = class_getInstanceMethod(class, originSelector);
                    method_exchangeImplementations(originMethod, swizzlMethod);
                    break;
                }
            }
        }
    }
}

void stimDB_didTapView(id self, SEL _cmd, id gestureRecognizer) {
    NSMethodSignature *signture = [[self class] instanceMethodSignatureForSelector:_cmd];
    NSUInteger numberOfArguments = signture.numberOfArguments;
    SEL selector = NSSelectorFromString(@"stimDB_didTapView");
    if (3 == numberOfArguments) {
        ((void (*)(id, SEL, id)) objc_msgSend)(self, selector, gestureRecognizer);
    } else if (2 == numberOfArguments) {
        ((void (*)(id, SEL)) objc_msgSend)(self, selector);
    }

    NSString *aciton = NSStringFromSelector(_cmd);
    NSString *eventId = [NSString stringWithFormat:@"%@&&%@", NSStringFromClass([self class]), aciton];
    [[STIMAutoTrackerManager sharedInstance] addACTTrackerDataWithEventId:eventId withDescription:eventId];
}

@end
