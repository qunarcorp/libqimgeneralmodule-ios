//
//  UITableView+QIMAutoTracker.m
//  QIMAutoTracker
//
//  Created by lilulucas.li on 2019/04/18.
//

#import "UITableView+QIMAutoTracker.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "QIMAutoTrackerOperation.h"
#import "NSObject+QIMAutoTracker.h"
#import "QIMAutoTrackerManager.h"

@implementation UITableView (QIMAutoTracker)

+ (void)startTracker {
    Method setDelegateMethod = class_getInstanceMethod(self, @selector(setDelegate:));
    Method qimSetDelegateMethod = class_getInstanceMethod(self, @selector(qim_setDelegate:));
    method_exchangeImplementations(setDelegateMethod, qimSetDelegateMethod);
}

- (void)qim_setDelegate:(id <UITableViewDelegate>)delegate {

    //只监听UITableView
    if (![self isKindOfClass:[UITableView class]]) {
        return;
    }

    [self qim_setDelegate:delegate];

    if (delegate) {
        Class class = [delegate class];
        SEL originSelector = @selector(tableView:didSelectRowAtIndexPath:);
        SEL swizzlSelector = NSSelectorFromString(@"qim_didSelectRowAtIndexPath");
        BOOL didAddMethod = class_addMethod(class, swizzlSelector, (IMP) qim_didSelectRowAtIndexPath, "v@:@@");
        if (didAddMethod) {
            Method originMethod = class_getInstanceMethod(class, swizzlSelector);
            Method swizzlMethod = class_getInstanceMethod(class, originSelector);
            method_exchangeImplementations(originMethod, swizzlMethod);
        }
    }
}

void qim_didSelectRowAtIndexPath(id self, SEL _cmd, id tableView, NSIndexPath *indexpath) {
    SEL selector = NSSelectorFromString(@"qim_didSelectRowAtIndexPath");
    ((void (*)(id, SEL, id, NSIndexPath *)) objc_msgSend)(self, selector, tableView, indexpath);

    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexpath];

    NSString *targetString = NSStringFromClass([self class]);
    NSString *actionString = NSStringFromSelector(_cmd);

    NSString *eventId = [NSString stringWithFormat:@"%@&&%@&&%ld-%ld", targetString, actionString, indexpath.section, indexpath.row];
    if (cell.accessibilityIdentifier.length > 0) {
        eventId = [NSString stringWithFormat:@"%@&&%@&&%@&&%ld-%ld", targetString, actionString, cell.accessibilityIdentifier, indexpath.section, indexpath.row];
    }
    [[QIMAutoTrackerManager sharedInstance] addACTTrackerDataWithEventId:eventId withDescription:eventId];
}

@end
