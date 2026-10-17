//
//  YVSilkUtil.m
//

#import "YVSilkUtil.h"
#import <CommonCrypto/CommonDigest.h>

@implementation YVVoiceItem
@end

@implementation YVSilkUtil

+ (NSString *)voiceDirPath {
    NSString *docs = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    return [docs stringByAppendingPathComponent:@"yuyi-voice"];
}

+ (BOOL)ensureVoiceDir {
    NSString *dir = [self voiceDirPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if ([fm fileExistsAtPath:dir isDirectory:&isDir]) {
        return isDir;
    }
    NSError *err = nil;
    BOOL ok = [fm createDirectoryAtPath:dir
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:&err];
    if (!ok) {
        NSLog(@"[YuyiVoice] create dir failed: %@", err);
    } else {
        NSLog(@"[YuyiVoice] created dir: %@", dir);
    }
    return ok;
}

+ (NSArray<YVVoiceItem *> *)scanVoiceFiles {
    [self ensureVoiceDir];

    NSString *dir = [self voiceDirPath];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSError *err = nil;
    NSArray<NSString *> *all = [fm contentsOfDirectoryAtPath:dir error:&err];
    if (err) {
        NSLog(@"[YuyiVoice] list dir error: %@", err);
        return @[];
    }

    NSSet *exts = [NSSet setWithObjects:@"silk", @"slk", @"amr", nil];
    NSMutableArray<YVVoiceItem *> *result = [NSMutableArray array];

    for (NSString *name in all) {
        if ([name hasPrefix:@"."]) continue;
        NSString *ext = [[name pathExtension] lowercaseString];
        if (![exts containsObject:ext]) continue;

        NSString *full = [dir stringByAppendingPathComponent:name];
        NSDictionary *attrs = [fm attributesOfItemAtPath:full error:nil];
        if (!attrs || [attrs[NSFileType] isEqual:NSFileTypeDirectory]) continue;

        unsigned long long size = [attrs[NSFileSize] unsignedLongLongValue];

        YVVoiceItem *item = [YVVoiceItem new];
        item.path = full;
        item.name = name;
        item.fileSize = size;
        item.duration = [self estimateSilkDuration:full fileSize:size];
        item.md5 = [self md5OfFile:full];

        int sec = (int)round(item.duration);
        item.displayTime = [NSString stringWithFormat:@"%d:%02d", sec / 60, sec % 60];

        [result addObject:item];
    }

    [result sortUsingComparator:^NSComparisonResult(YVVoiceItem *a, YVVoiceItem *b) {
        return [a.name compare:b.name options:NSNumericSearch];
    }];

    NSLog(@"[YuyiVoice] scanned %lu voice file(s) in %@", (unsigned long)result.count, dir);
    return result;
}

+ (NSString *)md5OfFile:(NSString *)path {
    NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!fh) return @"";

    CC_MD5_CTX ctx;
    CC_MD5_Init(&ctx);

    while (YES) {
        @autoreleasepool {
            NSData *chunk = [fh readDataOfLength:64 * 1024];
            if (chunk.length == 0) break;
            CC_MD5_Update(&ctx, chunk.bytes, (CC_LONG)chunk.length);
        }
    }
    [fh closeFile];

    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &ctx);

    NSMutableString *hex = [NSMutableString stringWithCapacity:32];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [hex appendFormat:@"%02x", digest[i]];
    }
    return hex;
}

+ (double)estimateSilkDuration:(NSString *)path fileSize:(unsigned long long)size {
    // silk 格式：#!SILK_V3 头之后为帧数据。
    // QQ 默认 silk 每帧 20ms，单帧约 20~40 字节（随码率变化）。
    // 这里用「文件大小 / 平均帧字节数 * 20ms」粗估，误差在可接受范围。
    // 更精确的做法是解析帧头，但 silk 变长编码解析成本高，这里用经验值。

    NSData *head = [NSData dataWithContentsOfFile:path
                                         options:NSDataReadingMappedIfSafe
                                           error:nil];
    if (!head || head.length < 10) return 0.0;

    const unsigned char *bytes = head.bytes;
    NSUInteger dataOffset = 10; // 默认跳过 "#!SILK_V3" (9字节) + 0x02

    // 检测 AMR 头
    if (head.length > 6 && memcmp(bytes, "#!AMR", 5) == 0) {
        // AMR-NB: 每帧 20ms，帧头 1 字节 + 负载
        // 平均每帧约 20 字节
        double frames = (double)(size - 6) / 20.0;
        return frames * 0.02;
    }

    // 检测 SILK 头
    if (head.length > 9 && memcmp(bytes, "#!SILK_V3", 9) == 0) {
        dataOffset = 10;
    }

    if (size <= dataOffset) return 0.0;

    unsigned long long payload = size - dataOffset;

    // QQ silk 常见码率约 24kbps~48kbps，平均每帧 20ms 约 25 字节
    const double avgBytesPerFrame = 25.0;
    const double frameMs = 20.0;

    double frames = (double)payload / avgBytesPerFrame;
    double seconds = frames * (frameMs / 1000.0);

    // 合理范围限制：0.5s ~ 60s
    if (seconds < 0.5) seconds = 0.5;
    if (seconds > 60.0) seconds = 60.0;

    return seconds;
}

@end