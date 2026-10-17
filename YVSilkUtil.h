//
//  YVSilkUtil.h
//  silk 文件扫描 / 时长估算 / md5
//

#import <Foundation/Foundation.h>

@interface YVVoiceItem : NSObject
@property (nonatomic, copy) NSString *path;        // 完整路径
@property (nonatomic, copy) NSString *name;        // 文件名
@property (nonatomic, assign) unsigned long long fileSize;
@property (nonatomic, assign) double duration;     // 秒
@property (nonatomic, copy) NSString *md5;
@property (nonatomic, copy) NSString *displayTime; // 格式化时长 0:03
@end

@interface YVSilkUtil : NSObject

/// 语音包目录：沙盒 Documents/yuyi-voice
+ (NSString *)voiceDirPath;

/// 确保目录存在（不存在则创建）
+ (BOOL)ensureVoiceDir;

/// 扫描目录下所有 .silk / .slk / .amr 文件
+ (NSArray<YVVoiceItem *> *)scanVoiceFiles;

/// 计算文件 md5
+ (NSString *)md5OfFile:(NSString *)path;

/// 估算 silk 时长（秒）
+ (double)estimateSilkDuration:(NSString *)path fileSize:(unsigned long long)size;

@end
