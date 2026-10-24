TARGET := iphone:clang:latest:16.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Aurora
Aurora_FILES = Tweak.x
Aurora_CFLAGS = -fobjc-arc
Aurora_FRAMEWORKS = UIKit Foundation CoreFoundation QuartzCore

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += auroraprefs
include $(THEOS_MAKE_PATH)/aggregate.mk
