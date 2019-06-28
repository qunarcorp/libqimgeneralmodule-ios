//
//  NSObject+QIMAutoTracker.m
//  QIMAutoTracker
//
//  Created by lilulucas.li on 2019/04/18.
//

#import "NSObject+QIMAutoTracker.h"
#import <objc/runtime.h>

static void *ddInfoDictionaryPropertyKey = &ddInfoDictionaryPropertyKey;

@implementation NSObject (QIMAutoTracker)

- (NSDictionary *)ddInfoDictionary {
    return objc_getAssociatedObject(self, ddInfoDictionaryPropertyKey);
}

- (void)setDdInfoDictionary:(NSDictionary *)ddInfoDictionary {
    if (ddInfoDictionary) {
        objc_setAssociatedObject(self, ddInfoDictionaryPropertyKey, ddInfoDictionary, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

- (void)configInfoData:(id)obj {
    if (nil == obj) {
        return;
    }
    if ([obj isKindOfClass:[NSDictionary class]]) {
        self.ddInfoDictionary = obj;
    } else {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];

        unsigned count;
        objc_property_t *properties = class_copyPropertyList([obj class], &count);

        for (int i = 0; i < count; i++) {
            NSString *key = [NSString stringWithUTF8String:property_getName(properties[i])];
            if (key.length > 0 &&
                    [obj valueForKey:key]) {
                [dict setObject:[obj valueForKey:key] forKey:key];
            }
        }

        free(properties);

        if (dict) {
            self.ddInfoDictionary = dict;
        }
    }
}

@end
