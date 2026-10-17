//
//  Tweak.xm
//  双指长按手势 → 呼出语音包面板
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "YVVoicePanelController.h"
#import "YVVoiceSender.h"
#import "YVSilkUtil.h"

#pragma mark - 双指长按手势

@interface YVTwoFingerLongPressGesture : UILongPressGestureRecognizer
@end

@implementation YVTwoFingerLongPressGesture
@end

#pragma mark - 关联 key

static const void *kYVGestureKey = &kYVGestureKey;

#pragma mark - 手势处理（category 提前声明）

@interface UIViewController (YuyiVoice)
- (void)yv_handleTwoFingerLongPress:(UILongPressGestureRecognizer *)g;
@end

#pragma mark - 手势安装

static void YVInstallGesture(UIViewController *vc) {
    if (!vc) return;
    if (objc_getAssociatedObject(vc, kYVGestureKey)) return;   // 已安装

    YVTwoFingerLongPressGesture *g =
        [[YVTwoFingerLongPressGesture alloc] initWithTarget:vc
                                                     action:@selector(yv_handleTwoFingerLongPress:)];
    g.numberOfTouchesRequired = 2;
    g.minimumPressDuration = 0.45;
    g.allowableMovement = 60;
    g.cancelsTouchesInView = NO;
    g.delaysTouchesBegan = NO;
    g.delaysTouchesEnded = NO;

    [vc.view addGestureRecognizer:g];
    objc_setAssociatedObject(vc, kYVGestureKey, g, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSLog(@"[YuyiVoice] gesture installed on %@", NSStringFromClass([vc class]));
}

#pragma mark - 按名字模糊查找类

static Class YVFindClassContaining(NSString *keyword, NSString *excludeKeyword) {
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return Nil;

    Class *classes = (Class *)malloc(sizeof(Class) * count);
    if (!classes) return Nil;
    objc_getClassList(classes, count);

    Class found = Nil;
    for (int i = 0; i < count; i++) {
        NSString *name = NSStringFromClass(classes[i]);
        if (![name containsString:keyword]) continue;
        if (excludeKeyword && [name containsString:excludeKeyword]) continue;
        found = classes[i];
        NSLog(@"[YuyiVoice] matched class: %@", name);
        break;
    }
    free(classes);
    return found;
}

#pragma mark - Hook viewDidLoad

typedef void (*YVViewDidLoadIMP)(id, SEL);
static YVViewDidLoadIMP orig_viewDidLoad = NULL;

static void YV_viewDidLoad(id self, SEL _cmd) {
    if (orig_viewDidLoad) orig_viewDidLoad(self, _cmd);

    @try {
        YVInstallGesture((UIViewController *)self);
    } @catch (NSException *e) {
        NSLog(@"[YuyiVoice] install gesture failed: %@", e);
    }
}

#pragma mark - 入口

%ctor {
    @autoreleasepool {
        // 主聊天 VC：NTBaseAIO.NTAIOChatBaseViewController
        Class chatVC = YVFindClassContaining(@"NTAIOChatBaseViewController", nil);

        if (!chatVC) {
            // 兜底：找基类
            chatVC = YVFindClassContaining(@"AIOBaseChatViewController", nil);
        }

        if (!chatVC) {
            NSLog(@"[YuyiVoice] ⚠️ 未找到聊天 VC 类，手势不会安装。请检查 QQ 版本或类名。");
            return;
        }

        MSHookMessageEx(chatVC,
                        @selector(viewDidLoad),
                        (IMP)YV_viewDidLoad,
                        (IMP *)&orig_viewDidLoad);

        NSLog(@"[YuyiVoice] ✅ hooked -[%@ viewDidLoad]", NSStringFromClass(chatVC));
    }
}

#pragma mark - 手势处理实现

@implementation UIViewController (YuyiVoice)

- (void)yv_handleTwoFingerLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;

    NSLog(@"[YuyiVoice] two-finger long press on %@", NSStringFromClass([self class]));

    UIImpactFeedbackGenerator *fb =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb impactOccurred];

    // 防止重复弹出
    if ([self.presentedViewController isKindOfClass:[YVVoicePanelController class]]) return;

    [YVVoicePanelController presentFromViewController:self];
}

@end