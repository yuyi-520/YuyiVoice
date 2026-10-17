export TARGET := iphone:clang:16.5:14.0
export ARCHS := arm64
export INSTALL_TARGET_PROCESSES := QQ

# 优先使用 rootful 布局（/Library/MobileSubstrate），
# 如用 rootless（Dopamine/palera1n）可在命令行加 THEOS_PACKAGE_SCHEME=rootless
export THEOS_PACKAGE_SCHEME ?=

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := YuyiVoice

YuyiVoice_FILES := Tweak.x \
                   YVSilkUtil.m \
                   YVVoiceSender.m \
                   YVVoicePanelController.m \
                   YVCompat.c

YuyiVoice_CFLAGS := -fobjc-arc -Wno-unused-function -Wno-deprecated-declarations -fno-modules
YuyiVoice_FRAMEWORKS := UIKit Foundation CoreGraphics
YuyiVoice_LIBRARIES := substrate
YuyiVoice_LDFLAGS := -fuse-ld=/tmp/ldwrap.sh
YuyiVoice_INSTALL_PATH := /Library/MobileSubstrate/DynamicLibraries

include $(THEOS_MAKE_PATH)/tweak.mk

after-install::
	install.exec "killall -9 QQ || true"