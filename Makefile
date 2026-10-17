export TARGET := iphone:clang:16.5:14.0
export ARCHS := arm64
export INSTALL_TARGET_PROCESSES := QQ

# rootful（默认）走 /Library/MobileSubstrate
# rootless（Dopamine/palera1n）加：make package THEOS_PACKAGE_SCHEME=rootless
export THEOS_PACKAGE_SCHEME ?=

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := YuyiVoice

YuyiVoice_FILES := Tweak.x \
                   YVSilkUtil.m \
                   YVVoiceSender.m \
                   YVVoicePanelController.m

YuyiVoice_CFLAGS := -fobjc-arc -Wno-unused-function -Wno-deprecated-declarations
YuyiVoice_FRAMEWORKS := UIKit Foundation CoreGraphics
YuyiVoice_LIBRARIES := substrate
YuyiVoice_INSTALL_PATH := /Library/MobileSubstrate/DynamicLibraries

# ─────────────────────────────────────────────────────────────
# 平台差异处理
#   macOS  : 原生 toolchain，什么都不用加
#   Linux  : 需要 ld64.lld + 参数转换 + ___isPlatformVersionAtLeast stub
# ─────────────────────────────────────────────────────────────
UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Linux)
    # Linux 下 .xm(ObjC++) 的 libc++ 头与 iOS SDK 冲突，用 -fno-modules 规避
    YuyiVoice_CFLAGS += -fno-modules

    # Theos 传的是 GNU ld 风格参数，交给 scripts/ldwrap.py 转成 ld64.lld 语法
    YuyiVoice_LDFLAGS += -fuse-ld=$(CURDIR)/scripts/ldwrap.sh

    # clang @available 会引用 ___isPlatformVersionAtLeast，Linux SDK 没有实现
    YuyiVoice_FILES += YVCompat.c
endif

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 QQ || true"