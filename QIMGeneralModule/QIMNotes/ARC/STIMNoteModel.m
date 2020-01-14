//
//  STIMNoteModel.m
//  STChatIphone
//
//  Created by 李海彬 on 2017/7/18.
//
//

#import "STIMNoteModel.h"
#import "NSObject+STIMRuntime.h"

@implementation STIMNoteModel

- (instancetype)init {
    self = [super init];
    if (self) {
        [self addObserver];
    }
    return self;
}

- (void)addObserver {
    [self addObserver:self forKeyPath:@"qs_content" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"qs_content"]) {
        if (change[@"new"] && !([change[@"new"] isEqual:[NSNull null]])) {
            
            switch (self.qs_type) {
                case STIMPasswordTypeText:
                case STIMPasswordTypeURL:
                case STIMPasswordTypeEmail:
                case STIMPasswordTypeAddress:
                case STIMPasswordTypeDateTime:
                case STIMPasswordTypeYearMonth:
                case STIMPasswordTypeOnePassword:
                case STIMPasswordTypePassword:
                case STIMPasswordTypeTelphone:
                    if (self.pwdDelegate && [self.pwdDelegate respondsToSelector:@selector(updatePasswordModel)]) {
                        [self.pwdDelegate updatePasswordModel];
                    }
                    break;
//                case STIMNoteTypeTodoList:
//                if (self.todoDelegate && [self.todoDelegate respondsToSelector:@selector(updateTodoListModel)]) {
//                    [self.todoDelegate updateTodoListModel];
//                }
//                    break;
//                case STIMNoteTypeEverNote:
//                    if (self.noteDelegate && [self.noteDelegate respondsToSelector:@selector(updateEverNoteModel)]) {
//                        [self.noteDelegate updateEverNoteModel];
//                    }
//                    break;
                default:
                    break;
            }
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"qs_content"];
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    
}

- (void)setValue:(id)value forKey:(NSString *)key {
    if ([key isEqualToString:@"id"]) {
        key = @"id";
        [super setValue:value forKey:key];
    } else {
        [super setValue:value forKey:key];
    }
}

- (NSString *)description {
    return [self stimDB_properties_aps];
}

@end
