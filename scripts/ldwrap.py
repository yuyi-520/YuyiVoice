#!/usr/bin/env python3
# 把 Theos 传出的旧式 GNU/ld 风格参数转换成 ld64.lld 能接受的写法
import sys
import subprocess

args = sys.argv[1:]
out = []
i = 0
n = len(args)

while i < n:
    a = args[i]

    # -iphoneos_version_min 14.0.0  ->  -platform_version ios 14.0.0 14.0.0
    if a == '-iphoneos_version_min':
        if i + 1 < n:
            out += ['-platform_version', 'ios', args[i + 1], args[i + 1]]
            i += 2
        else:
            i += 1
        continue

    # 这些是 clang/老 ld 专用，ld64.lld 不认识，直接丢弃参数及值
    if a in ('-mllvm', '-multiply_defined'):
        i += 2
        continue

    # -dylib_install_name  ->  -install_name
    if a == '-dylib_install_name':
        if i + 1 < n:
            out += ['-install_name', args[i + 1]]
            i += 2
        else:
            i += 1
        continue

    # rootless 的兼容库，rootful 构建里没有，跳过
    if a in ('-lroot_oldabi', '-lroot'):
        i += 1
        continue

    out.append(a)
    i += 1

sys.exit(subprocess.call(['/usr/lib/llvm-18/bin/ld64.lld'] + out))
