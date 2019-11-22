//
//  UICollectionView+STIMAutoTracker.m
//  STIMAutoTracker
//
//  Created by lilulucas.li on 2019/04/18.
//

#import "UICollectionView+STIMAutoTracker.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "STIMAutoTrackerOperation.h"
#import "NSObject+STIMAutoTracker.h"
#import "STIMAutoTrackerManager.h"

@implementation UICollectionView (STIMAutoTracker)

+ (void)startTracker {
    Method setDelegateMethod = class_getInstanceMethod(self, @selector(setDelegate:));
    Method qimSetDelegateMethod = class_getInstanceMethod(self, @selector(stimDB_setDelegate:));
    method_exchangeImplementations(setDelegateMethod, qimSetDelegateMethod);
}

- (void)stimDB_setDelegate:(id <UICollectionViewDelegate>)delegate {

    //只监听UICollectionView
    if (![self isKindOfClass:[UICollectionView class]]) {
        return;
    }

    [self stimDB_setDelegate:delegate];
    if (delegate) {
        Class class = [delegate class];
        SEL originSelector = @selector(collectionView:didSelectItemAtIndexPath:);
        SEL swizzlSelector = NSSelectorFromString(@"stimDB_didSelectItemAtIndexPath");
        BOOL didAddMethod = class_addMethod(class, swizzlSelector, (IMP) stimDB_didSelectItemAtIndexPath, "v@:@@");
        if (didAddMethod) {
            Method originMethod = class_getInstanceMethod(class, swizzlSelector);
            Method swizzlMethod = class_getInstanceMethod(class, originSelector);
            method_exchangeImplementations(originMethod, swizzlMethod);
        }
    }
}

void stimDB_didSelectItemAtIndexPath(id self, SEL _cmd, id collectionView, NSIndexPath *indexpath) {
    SEL selector = NSSelectorFromString(@"stimDB_didSelectItemAtIndexPath");
    ((void (*)(id, SEL, id, NSIndexPath *)) objc_msgSend)(self, selector, collectionView, indexpath);

    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexpath];

    NSString *targetString = NSStringFromClass([self class]);
    NSString *actionString = NSStringFromSelector(_cmd);

    NSString *eventId = [NSString stringWithFormat:@"%@&&%@", targetString, actionString];
    [[STIMAutoTrackerManager sharedInstance] addACTTrackerDataWithEventId:eventId withDescription:eventId];
}

@end
