//
//  STIMNoteModel.h
//  STChatIphone
//
//  Created by 李海彬 on 2017/7/18.
//
//

#import <Foundation/Foundation.h>
#import "STIMNoteManager.h"

@protocol STIMPasswordModelUpdateDelegate <NSObject>

- (void)updatePasswordModel;

@end

@protocol TodoListModelUpdateDelegate <NSObject>

- (void)updateTodoListModel;

@end

@protocol STIMEverNoteModelUpdateDelegate <NSObject>

- (void)updateEverNoteModel;

@end

@interface STIMNoteModel : NSObject

@property (nonatomic, weak) id <STIMPasswordModelUpdateDelegate> pwdDelegate;

@property (nonatomic, weak) id <TodoListModelUpdateDelegate> todoDelegate;

@property (nonatomic, weak) id <STIMEverNoteModelUpdateDelegate> noteDelegate;

@property (nonatomic, copy) NSString *privateKey;

@property (nonatomic) NSInteger q_id;

@property (nonatomic) NSInteger qs_id;

@property (nonatomic) NSInteger c_id;

@property (nonatomic) NSInteger cs_id;

@property (nonatomic) STIMNoteType q_type;

@property (nonatomic, copy) NSString *q_title;

@property (nonatomic, copy) NSString *q_introduce;

@property (nonatomic, copy) NSString *q_content;

@property (nonatomic) NSInteger q_time;

@property (nonatomic) STIMNoteState q_state;

@property (nonatomic) STIMNoteExtendedFlagState q_ExtendedFlag;

@property (nonatomic) STIMPasswordType qs_type;

@property (nonatomic, copy) NSString *qs_title;

@property (nonatomic, copy) NSString *qs_introduce;

@property (nonatomic, copy) NSString *qs_content;

@property (nonatomic) NSInteger qs_time;

@property (nonatomic) STIMNoteState qs_state;

@property (nonatomic) STIMNoteExtendedFlagState qs_ExtendedFlag;

@end
