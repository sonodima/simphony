TARGET := iphone:clang:latest:6.0
INSTALL_TARGET_PROCESSES = SpringBoard

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Simphony

Simphony_FILES = Tweak.x
Simphony_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
