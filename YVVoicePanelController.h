//
//  YVVoicePanelController.h
//  语音包列表面板（UITableView）
//

#import <UIKit/UIKit.h>
#import "YVVoiceSender.h"

@interface YVVoicePanelController : UIViewController

/// 当前聊天会话目标
@property (nonatomic, strong) YVChatTarget *target;

/// 便捷弹出
+ (void)presentFromViewController:(UIViewController *)vc;

@end