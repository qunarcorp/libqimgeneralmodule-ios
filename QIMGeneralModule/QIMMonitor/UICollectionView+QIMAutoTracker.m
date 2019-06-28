//
//  UICollectionView+QIMAutoTracker.m
//  QIMAutoTracker
//
//  Created by lilulucas.li on 2019/04/18.
//

#import "UICollectionView+QIMAutoTracker.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import "QIMAutoTrackerOperation.h"
#import "NSObject+QIMAutoTracker.h"
#import "QIMAutoTrackerManager.h"

@implementation UICollectionView (QIMAutoTracker)

+ (void)startTracker {
    Method setDelegateMethod = class_getInstanceMethod(self, @selector(setDelegate:));
    Method qimSetDelegateMethod = class_getInstanceMethod(self, @selector(qim_setDelegate:));
    method_exchangeImplementations(setDelegateMethod, qimSetDelegateMethod);
}

- (void)qim_setDelegate:(id <UICollectionViewDelegate>)delegate {

    //只监听UICollectionView
    if (![self isKindOfClass:[UICollectionView class]]) {
        return;
    }

    [self qim_setDelegate:delegate];
    if (delegate) {
        Class class = [delegate class];
        SEL originSelector = @selector(collectionView:didSelectItemAtIndexPath:);
        SEL swizzlSelector = NSSelectorFromString(@"qim_didSelectItemAtIndexPath");
        BOOL didAddMethod = class_addMethod(class, swizzlSelector, (IMP) qim_didSelectItemAtIndexPath, "v@:@@");
        if (didAddMethod) {
            Method originMethod = class_getInstanceMethod(class, swizzlSelector);
            Method swizzlMethod = class_getInstanceMethod(class, originSelector);
            method_exchangeImplementations(originMethod, swizzlMethod);
        }
    }
}

void qim_didSelectItemAtIndexPath(id self, SEL _cmd, id collectionView, NSIndexPath *indexpath) {
    SEL selector = NSSelectorFromString(@"qim_didSelectItemAtIndexPath");
    ((void (*)(id, SEL, id, NSIndexPath *)) objc_msgSend)(self, selector, collectionView, indexpath);

    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexpath];

    NSString *targetString = NSStringFromClass([self class]);
    NSString *actionString = NSStringFromSelector(_cmd);

    NSString *eventId = [NSString stringWithFormat:@"%@&&%@", targetString, actionString];
    [[QIMAutoTrackerManager sharedInstance] addACTTrackerDataWithEventId:eventId withDescription:eventId];
}

@end
