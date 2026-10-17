//
//  YVVoiceSender.m
//

#import "YVVoiceSender.h"
#import "YVPrivate.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation YVChatTarget
- (NSString *)debugDescription {
    return [NSString stringWithFormat:@"<YVChatTarget chatType=%d peerUid=%@ peerUin=%@ title=%@>",
            _chatType, _peerUid, _peerUin, _title];
}
- (NSString *)description { return [self debugDescription]; }
@end


@implementation YVVoiceSender

#pragma mark - 提取会话目标

+ (YVChatTarget *)targetFromViewController:(UIViewController *)vc {
    YVChatTarget *t = [YVChatTarget new];
    t.sourceVC = vc;
    if (!vc) return t;

    // ── 策略 1：chatContext（AIOChatParameter.AIOChatContext）
    //    绝大多数字段是 Swift 计算属性，用 KVC / 方法调用双路兜底
    id ctx = nil;
    @try { ctx = [vc valueForKey:@"chatContext"]; } @catch (__unused NSException *e) {}

    if (!ctx) {
        // 有些 VC 放在 aioObserver / chatViewModel 里
        for (NSString *k in @[@"aioObserver", @"chatViewModel", @"chatInfo"]) {
            @try {
                id o = [vc valueForKey:k];
                if (o) {
                    @try { ctx = [o valueForKey:@"chatContext"]; } @catch (__unused NSException *e) {}
                    if (ctx) break;
                }
            } @catch (__unused NSException *e) {}
        }
    }

    if (ctx) {
        // chatType
        if ([ctx respondsToSelector:@selector(chatType)]) {
            t.chatType = ((int (*)(id, SEL))objc_msgSend)(ctx, @selector(chatType));
        } else {
            @try { t.chatType = [[ctx valueForKey:@"chatType"] intValue]; } @catch (__unused NSException *e) {}
        }
        // peerUid
        if ([ctx respondsToSelector:@selector(peerUid)]) {
            id v = ((id (*)(id, SEL))objc_msgSend)(ctx, @selector(peerUid));
            if ([v isKindOfClass:[NSString class]]) t.peerUid = v;
        }
        // peerUin
        if ([ctx respondsToSelector:@selector(peerUin)]) {
            id v = ((id (*)(id, SEL))objc_msgSend)(ctx, @selector(peerUin));
            if ([v isKindOfClass:[NSString class]]) t.peerUin = v;
        }
        // chatTitle
        if ([ctx respondsToSelector:@selector(chatTitle)]) {
            id v = ((id (*)(id, SEL))objc_msgSend)(ctx, @selector(chatTitle));
            if ([v isKindOfClass:[NSString class]]) t.title = v;
        }

        // chatInfo (OCContact) 兜底
        if ((!t.peerUid || !t.peerUin) && [ctx respondsToSelector:@selector(chatInfo)]) {
            id info = ((id (*)(id, SEL))objc_msgSend)(ctx, @selector(chatInfo));
            if (info) {
                if (!t.peerUid) {
                    @try {
                        id u = [info valueForKey:@"peerUid"];
                        if ([u isKindOfClass:[NSString class]]) t.peerUid = u;
                    } @catch (__unused NSException *e) {}
                }
                if (t.chatType == 0) {
                    @try { t.chatType = [[info valueForKey:@"chatType"] intValue]; } @catch (__unused NSException *e) {}
                }
            }
        }
    }

    // ── 策略 2：直接读 VC 的 peerUid / peerUin / chatType
    if (!t.peerUid) {
        for (NSString *k in @[@"peerUid", @"peerUIN", @"uin", @"chatUin"]) {
            @try {
                id v = [vc valueForKey:k];
                if ([v isKindOfClass:[NSString class]] && [v length] > 0) { t.peerUid = v; break; }
            } @catch (__unused NSException *e) {}
        }
    }
    if (t.chatType == 0) {
        @try { t.chatType = [[vc valueForKey:@"chatType"] intValue]; } @catch (__unused NSException *e) {}
    }

    // ── 策略 3：标题兜底
    if (!t.title) {
        @try {
            id v = [vc valueForKey:@"_chatTitle"];
            if (!v) v = [vc valueForKey:@"chatTitle"];
            if (!v) v = vc.title;
            if ([v isKindOfClass:[NSString class]]) t.title = v;
        } @catch (__unused NSException *e) {}
    }

    // chatType 缺省：有 peerUid 但没有群标识，默认按 C2C
    if (t.chatType == 0) t.chatType = 1;

    NSLog(@"[YuyiVoice] target = %@", [t debugDescription]);
    return t;
}

#pragma mark - 发送

+ (void)sendVoiceItem:(YVVoiceItem *)item
               target:(YVChatTarget *)target
           completion:(void (^)(BOOL, NSString *))completion {

    if (!item || !target) {
        if (completion) completion(NO, @"参数为空");
        return;
    }
    if (!target.peerUid && !target.peerUin) {
        if (completion) completion(NO, @"无法获取当前会话对象，请进入具体聊天后重试");
        return;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // 1) 构造 OCContact
            Class contactCls = objc_getClass("OCContact");
            if (!contactCls) {
                if (completion) completion(NO, @"OCContact 类不存在");
                return;
            }
            id contact = ((id (*)(id, SEL, int, id, id))objc_msgSend)(
                (id)contactCls,
                @selector(ContactWithChatType:peerUid:guildId:),
                target.chatType,
                target.peerUid ?: target.peerUin,
                nil);

            // 2) 构造 OCPttElement
            Class pttCls = objc_getClass("OCPttElement");
            if (!pttCls) {
                if (completion) completion(NO, @"OCPttElement 类不存在");
                return;
            }
            id elem = ((id (*)(id, SEL))objc_msgSend)((id)pttCls, @selector(PttElement));
            if (!elem) {
                if (completion) completion(NO, @"OCPttElement 创建失败");
                return;
            }

            NSString *fileName = item.name;
            NSNumber *sizeNum = @(item.fileSize);
            int durationMs = (int)round(item.duration * 1000.0);

            [elem setValue:fileName forKey:@"fileName"];
            [elem setValue:item.path forKey:@"filePath"];
            [elem setValue:item.md5 forKey:@"md5HexStr"];
            [elem setValue:sizeNum forKey:@"fileSize"];
            [elem setValue:@(durationMs) forKey:@"duration"];
            [elem setValue:@(1) forKey:@"formatType"];       // 1 = SILK
            [elem setValue:@(0) forKey:@"voiceType"];
            [elem setValue:@(0) forKey:@"voiceChangeType"];
            [elem setValue:@(YES) forKey:@"canConvert2Text"];

            NSArray *elems = @[elem];

            // 3) 调用 QQMsgService 发送
            Class svcCls = objc_getClass("QQMsgService");
            if (!svcCls) {
                if (completion) completion(NO, @"QQMsgService 类不存在");
                return;
            }
            id svc = ((id (*)(id, SEL))objc_msgSend)((id)svcCls, @selector(getInstance));
            if (!svc) {
                if (completion) completion(NO, @"QQMsgService 实例获取失败");
                return;
            }

            void (^cb)(id) = ^(id result) {
                NSLog(@"[YuyiVoice] send result: %@", result);
                if (completion) completion(YES, @"已发送");
            };

            if ([svc respondsToSelector:@selector(sendMsgWithOCContact:msgElems:msgAttributeInfos:callBack:)]) {
                ((void (*)(id, SEL, id, id, id, id))objc_msgSend)(
                    svc,
                    @selector(sendMsgWithOCContact:msgElems:msgAttributeInfos:callBack:),
                    contact, elems, nil, [cb copy]);
            } else if ([svc respondsToSelector:@selector(sendMsgAndGetMsgIDWithOCContactAndOCMsgElements:msgElems:msgAttributeInfos:callBack:)]) {
                ((unsigned long long (*)(id, SEL, id, id, id, id))objc_msgSend)(
                    svc,
                    @selector(sendMsgAndGetMsgIDWithOCContactAndOCMsgElements:msgElems:msgAttributeInfos:callBack:),
                    contact, elems, nil, [cb copy]);
            } else {
                if (completion) completion(NO, @"QQMsgService 无可用的发送方法");
            }

        } @catch (NSException *e) {
            NSLog(@"[YuyiVoice] send exception: %@", e);
            if (completion) completion(NO, [NSString stringWithFormat:@"异常: %@", e.reason]);
        }
    });
}

@end