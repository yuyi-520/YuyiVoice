# YuyiVoice — QQ 语音包面板 Tweak

聊天界面**双指长按** → 弹出本地 silk 语音包面板，点右侧按钮一键发送给当前聊天对象。

> ✅ 已在本机（Linux + Theos + ld64.lld）**实际编译通过**，产出：
> `packages/com.yuyi.voicepack_1.0.0_iphoneos-arm64.deb`（19.5 KB，arm64）

---

## 功能

- **双指长按**聊天界面呼出面板（0.45s，不干扰原有滑动/点击）
- 自动检查并创建沙盒 `Documents/yuyi-voice` 目录
- 扫描目录下 `.silk` / `.slk` / `.amr` 文件，按文件名自然排序
- 每行显示：文件名 · 时长 · 文件大小
- 右侧「发送」按钮 → 构造 `OCPttElement` 发给当前会话
- 面板内右上角 ↻ 刷新列表

## 目录结构

```
YuyiVoice/
├── Makefile                       # Theos 配置（已适配 Linux 构建）
├── control                        # deb 包元信息
├── YuyiVoice.plist                # MobileLoader 过滤：com.tencent.mqq
├── Tweak.x                        # 双指长按手势 hook（ObjC，非 ObjC++）
├── YVCompat.c                     # Linux 链接补丁：___isPlatformVersionAtLeast
├── YVPrivate.h                    # QQ 私有类最小声明
├── YVSilkUtil.h/.m                # 目录管理 + 文件扫描 + md5 + 时长估算
├── YVVoiceSender.h/.m             # 会话目标提取 + silk 发送
├── YVVoicePanelController.h/.m    # 面板 UI
├── scripts/ldwrap.py              # 旧式 ld 参数 → ld64.lld 转换器
├── .github/workflows/build.yml    # CI：macOS 上自动打包 deb
└── packages/                      # 编译产物（已含一个可用的 deb）
```

---

## 编译

### 方式 A：本地 Linux（已验证可行）

```bash
# 依赖
apt install -y clang lld-18 libssl-dev libplist-dev pkg-config \
               git make fakeroot dpkg-dev

# Theos
git clone --recursive --depth 1 https://github.com/theos/theos.git ~/theos
git clone --depth 1 https://github.com/theos/sdks.git /tmp/sdks
cp -r /tmp/sdks/iPhoneOS16.5.sdk ~/theos/sdks/

# ldid（Linux 需自行编译）
git clone --depth 1 https://github.com/ProcursusTeam/ldid.git /tmp/ldid-src
cd /tmp/ldid-src && make CXX=clang++ && cp ldid /usr/local/bin/

# 构建
export THEOS=~/theos
umask 022                     # 关键：umask 077 会导致 DEBIAN 权限错误
make package FINALPACKAGE=1 DEBUG=0
```

### 方式 B：macOS / GitHub Actions（推荐）

直接 push 到 GitHub，CI 会自动打包（见 `.github/workflows/build.yml`），
产物在 Actions → Artifacts，打 `v*` tag 还会自动发 Release。

### 方式 C：本地 macOS

```bash
brew install ldid
export THEOS=~/theos
make package FINALPACKAGE=1 DEBUG=0
```

---

## 安装

```bash
scp packages/com.yuyi.voicepack_*.deb root@device:/tmp/
ssh root@device "dpkg -i /tmp/com.yuyi.voicepack_*.deb && killall -9 QQ"
```

**rootless（Dopamine / palera1n rootless）** 需要额外编译：

```bash
make package THEOS_PACKAGE_SCHEME=rootless FINALPACKAGE=1
```

---

## 使用

1. 把 silk 文件放进 QQ 沙盒：

```bash
# 定位沙盒
find /var/mobile/Containers/Data/Application -maxdepth 2 -name "Documents" \
     -path "*mqq*" 2>/dev/null

# 拷贝
mkdir -p "<沙盒>/Documents/yuyi-voice"
cp *.silk "<沙盒>/Documents/yuyi-voice/"
```

> 也可以先长按一次弹出面板，空列表页会**直接显示完整路径**，照着放就行。

2. 打开任意聊天 → **双指长按** → 面板弹出
3. 点某条语音右侧「发送」

---

## 实现说明

### 手势挂载

Swift 类的运行时名是 `_TtC9NTBaseAIO26NTAIOChatBaseViewController`，Logos 的 `%hook` 写不了。
所以用 `objc_getClassList` 模糊匹配，再 `MSHookMessageEx` 拦 `-viewDidLoad`：

```objc
Class chatVC = YVFindClassContaining(@"NTAIOChatBaseViewController", nil);
MSHookMessageEx(chatVC, @selector(viewDidLoad), (IMP)YV_viewDidLoad, (IMP *)&orig_viewDidLoad);
```

手势参数：
```objc
g.numberOfTouchesRequired = 2;
g.minimumPressDuration = 0.45;
g.cancelsTouchesInView = NO;    // 不干扰原有手势
```

### 会话目标提取（三级兜底）

1. `chatContext`（`AIOChatParameter.AIOChatContext`）→ `chatType` / `peerUid` / `peerUin` / `chatTitle`
2. 直接 KVC 读 VC 的 `peerUid` / `chatType`
3. `chatContext.chatInfo`（`OCContact`）的 `peerUid` / `chatType`

`AIOChatContext` 的字段是 Swift 计算属性，KVC 可能失效，
所以用 `respondsToSelector` + `objc_msgSend` 双路兜底。

### 发送

```objc
id contact = [OCContact ContactWithChatType:chatType peerUid:peerUid guildId:nil];

id elem = [OCPttElement PttElement];
elem.fileName = @"x.silk";
elem.filePath = @"/.../yuyi-voice/x.silk";
elem.md5HexStr = md5;
elem.fileSize = size;
elem.duration = 3000;         // 毫秒
elem.formatType = 1;          // SILK
elem.canConvert2Text = YES;

[[QQMsgService getInstance] sendMsgWithOCContact:contact
                                        msgElems:@[elem]
                               msgAttributeInfos:nil
                                        callBack:^(id r){ ... }];
```

---

## Linux 构建踩过的坑（已全部修复）

| 问题 | 原因 | 解决 |
|---|---|---|
| `could not build module 'Foundation'/'std'` | `.xm` 是 ObjC++，Linux 下 libc++ 头文件与 iOS SDK 冲突 | 改用 `.x`（纯 ObjC） |
| `unrecognised emulation mode: llvm` | Theos 调 `ld`，指向了 GNU ld | 链到 `ld64.lld` |
| `unknown argument '-framework'` | Theos 传的是 GNU ld 风格参数 | `scripts/ldwrap.py` 做参数转换 |
| `undefined symbol ___isPlatformVersionAtLeast` | Linux SDK 无 compiler-rt 内建 | `YVCompat.c` 提供 stub |
| `same architecture arm64` (lipo) | `ld64.lld` 把 arm64e 也标成 arm64 | `ARCHS := arm64` |
| `ldid: command not found` | Linux 无预编译包 | 源码编译 ldid |
| `control directory has bad permissions 700` | shell `umask 077` | 构建前 `umask 022` |
| `missing a filter property list` | 缺 MobileLoader 过滤配置 | 新增 `YuyiVoice.plist` |

---

## 真机调试

```bash
idevicesyslog | grep YuyiVoice
```

**启动时**应看到：
```
[YuyiVoice] matched class: _TtC9NTBaseAIO26NTAIOChatBaseViewController
[YuyiVoice] ✅ hooked -[... viewDidLoad]
[YuyiVoice] gesture installed on ...
```

**长按后**：
```
[YuyiVoice] two-finger long press on ...
[YuyiVoice] target = <YVChatTarget chatType=1 peerUid=u_xxx peerUin=123456 title=xxx>
[YuyiVoice] scanned 12 voice file(s) in /var/mobile/.../Documents/yuyi-voice
[YuyiVoice] send result: ...
```

---

## ⚠️ 仍需真机验证的 4 个点

| 点 | 现状 | 若失败怎么改 |
|---|---|---|
| **formatType** | 假设 `1 = SILK` | 改 `0`（AMR）试；或读 `QQPttConfigMgr.instance.getLocalUsePttFormatNoneVC` |
| **peerUid / peerUin** | 优先传 `peerUid` | 老框架可能吃 UIN → 换成 `target.peerUin ?: target.peerUid` |
| **chatType** | 默认 1（C2C），群聊应 2 | 看日志打印值，手动映射 |
| **时长估算** | 「字节数 / 25 × 20ms」粗估 | silk 变长编码无法精确；需精确就接 `SilkTool.SilkDecoder` 解帧统计 |

> 粗估偏差**不影响发送成功**，只影响气泡显示长度。

---

## 安全提示

- 语音走正常消息通道，但**批量/自动化发送可能触发风控**，建议控制频率。
- 仅供个人学习研究，请遵守 QQ 用户协议。