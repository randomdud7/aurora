TARGET := iphone:clang:latest:16.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AuroraPrefs
AuroraPrefs_FILES = RootListController.m
AuroraPrefs_CFLAGS = -fobjc-arc
AuroraPrefs_FRAMEWORKS = UIKit Foundation CoreFoundation
AuroraPrefs_PRIVATE_FRAMEWORKS = Preferences
AuroraPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
