//
//  Tweak.x
//  在「语音快捷键条」上长按 → 振动 + 弹出语音包面板
//
//  目标类：NTAIOChat.NTAIOShortcutBarItemAudioViewController
//  运行时名：_TtC9NTAIOChat40NTAIOShortcutBarItemAudioViewController
//  继承链：NTAIOShortcutBarItemAudioViewController
//            -> NTAIOShortBarItemBaseViewController
//            -> AIOLib.AIOShortBarItemBaseViewController
//            -> UIViewController
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>
#import "YVVoicePanelController.h"
#import "YVVoiceSender.h"
#import "YVSilkUtil.h"

#pragma mark - 关联 key

static const void *kYVLongPressKey = &kYVLongPressKey;

#pragma mark - 手势回调声明

@interface UIViewController (YuyiVoice)
- (void)yv_handleAudioItemLongPress:(UILongPressGestureRecognizer *)g;
@end

#pragma mark - 安装长按手势

static void YVInstallLongPress(UIViewController *vc) {
    if (!vc || !vc.isViewLoaded) return;
    if (objc_getAssociatedObject(vc, kYVLongPressKey)) return;   // 已装过

    UILongPressGestureRecognizer *g =
        [[UILongPressGestureRecognizer alloc] initWithTarget:vc
                                                      action:@selector(yv_handleAudioItemLongPress:)];
    g.minimumPressDuration = 0.45;
    g.numberOfTouchesRequired = 1;
    g.allowableMovement = 30;
    g.cancelsTouchesInView = NO;

    [vc.view addGestureRecognizer:g];
    objc_setAssociatedObject(vc, kYVLongPressKey, g, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    NSLog(@"[YuyiVoice] long-press installed on %@ (view=%@)",
          NSStringFromClass([vc class]), NSStringFromClass([vc.view class]));
}

#pragma mark - 按关键字查找类

static Class YVFindClassContaining(NSString *keyword, NSString *mustNotContain) {
    int count = objc_getClassList(NULL, 0);
    if (count <= 0) return Nil;

    Class *classes = (Class *)malloc(sizeof(Class) * count);
    if (!classes) return Nil;
    objc_getClassList(classes, count);

    Class found = Nil;
    for (int i = 0; i < count; i++) {
        NSString *name = NSStringFromClass(classes[i]);
        if (![name containsString:keyword]) continue;
        if (mustNotContain && [name containsString:mustNotContain]) continue;
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
        YVInstallLongPress((UIViewController *)self);
    } @catch (NSException *e) {
        NSLog(@"[YuyiVoice] install failed: %@", e);
    }
}

#pragma mark - 入口

%ctor {
    @autoreleasepool {
        // 主目标：语音快捷键条 VC
        Class audioVC = YVFindClassContaining(@"NTAIOShortcutBarItemAudioViewController", nil);

        if (!audioVC) {
            NSLog(@"[YuyiVoice] ⚠️ 未找到 NTAIOShortcutBarItemAudioViewController");
            return;
        }

        MSHookMessageEx(audioVC,
                        @selector(viewDidLoad),
                        (IMP)YV_viewDidLoad,
                        (IMP *)&orig_viewDidLoad);

        NSLog(@"[YuyiVoice] ✅ hooked -[%@ viewDidLoad]", NSStringFromClass(audioVC));

        // 子类可能重写 viewDidLoad 而不调 super，需单独挂
        //   RobotAIOChat.NTRobotAIOShortcutBarItemAudioViewController
        //   BaseTempAIO.NTTempAIOShortcutBarItemAudioViewController
        NSArray *subclassKeys = @[@"NTRobotAIOShortcutBarItemAudioViewController",
                                  @"NTTempAIOShortcutBarItemAudioViewController"];
        for (NSString *key in subclassKeys) {
            Class sub = YVFindClassContaining(key, nil);
            if (!sub) continue;
            MSHookMessageEx(sub,
                            @selector(viewDidLoad),
                            (IMP)YV_viewDidLoad,
                            (IMP *)&orig_viewDidLoad);
            NSLog(@"[YuyiVoice] ✅ hooked -[%@ viewDidLoad] (subclass)", NSStringFromClass(sub));
        }
    }
}

#pragma mark - 长按处理

@implementation UIViewController (YuyiVoice)

- (void)yv_handleAudioItemLongPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;

    NSLog(@"[YuyiVoice] long press on %@", NSStringFromClass([self class]));

    // 振动反馈
    UIImpactFeedbackGenerator *fb =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [fb prepare];
    [fb impactOccurred];

    // 防重复
    if ([self.presentedViewController isKindOfClass:[YVVoicePanelController class]]) return;

    // 从当前 VC 向上找聊天 VC，取会话信息
    [YVVoicePanelController presentFromViewController:self];
}

@end
