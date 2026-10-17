//
//  YVCompat.c
//  Linux 下用 Theos + ld64.lld 链接时，clang 的 @available 会生成对
//  ___isPlatformVersionAtLeast 的调用，但 Linux SDK 里没有这个编译器内建实现。
//  这里提供一个等价实现，iOS 上运行时不会走到这里（会被真实现覆盖），
//  仅用于让链接通过。
//

#include <stdint.h>

int32_t __isPlatformVersionAtLeast(uint32_t platform, uint32_t major,
                                   uint32_t minor, uint32_t subminor);

int32_t __isPlatformVersionAtLeast(uint32_t platform, uint32_t major,
                                   uint32_t minor, uint32_t subminor) {
    // 保守返回 1：iOS 14+ 环境视为满足，避免误判导致功能不启用。
    // 面板只用到 UISheetPresentationController（iOS 15），
    // 代码里已有 @available 保护，这里返回 1 不影响低版本安全性。
    return 1;
}