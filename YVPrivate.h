//
//  YVPrivate.h
//  私有类的最小声明（避免依赖完整头文件）
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - OCContact

@interface OCContact : NSObject
@property (nonatomic, assign) int chatType;
@property (nonatomic, retain) NSString *peerUid;
@property (nonatomic, retain) NSString *guildId;
+ (id)Contact;
+ (id)ContactWithChatType:(int)chatType peerUid:(id)peerUid guildId:(id)guildId;
@end

#pragma mark - OCPttElement

@interface OCPttElement : NSObject
@property (retain, nonatomic) NSString *fileName;
@property (retain, nonatomic) NSString *filePath;
@property (retain, nonatomic) NSString *md5HexStr;
@property (nonatomic) long long fileSize;
@property (nonatomic) int duration;        // 毫秒
@property (nonatomic) int formatType;      // 0=AMR 1=SILK
@property (nonatomic) int voiceType;
@property (nonatomic) int autoConvertText;
@property (nonatomic) int voiceChangeType;
@property (nonatomic) BOOL canConvert2Text;
@property (retain, nonatomic) NSNumber *fileId;
@property (retain, nonatomic) NSString *fileUuid;
@property (retain, nonatomic) NSString *text;
+ (id)PttElement;
@end

#pragma mark - QQMsgService

@interface QQMsgService : NSObject
+ (id)getInstance;
- (void)sendMsgWithOCContact:(id)contact
                    msgElems:(id)elems
           msgAttributeInfos:(id)attrs
                    callBack:(id)cb;
- (unsigned long long)sendMsgAndGetMsgIDWithOCContactAndOCMsgElements:(id)contact
                                                             msgElems:(id)elems
                                                    msgAttributeInfos:(id)attrs
                                                             callBack:(id)cb;
@end

#pragma mark - AIOChatContext（Swift）

@interface AIOChatContext : NSObject
- (int)chatType;
- (id)peerUid;
- (id)peerUin;
- (id)chatTitle;
- (id)chatInfo;
@end
