//
//  YVVoiceSender.h
//  从「当前聊天界面」提取会话信息 + 发送 silk 语音
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "YVSilkUtil.h"

@interface YVChatTarget : NSObject
@property (nonatomic, assign) int chatType;     // 1=C2C 2=群 ...
@property (nonatomic, copy) NSString *peerUid;
@property (nonatomic, copy) NSString *peerUin;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, weak) UIViewController *sourceVC;
- (NSString *)debugDescription;
@end

@interface YVVoiceSender : NSObject

/// 从任意 VC 出发（含快捷键条子 VC）尽力找到聊天 VC
+ (UIViewController *)chatViewControllerFrom:(UIViewController *)vc;

/// 从聊天 VC 里尽力提取会话目标（多策略兜底）
+ (YVChatTarget *)targetFromViewController:(UIViewController *)vc;

/// 发送一条 silk 语音给指定目标
+ (void)sendVoiceItem:(YVVoiceItem *)item
               target:(YVChatTarget *)target
           completion:(void (^)(BOOL ok, NSString *msg))completion;

@end
