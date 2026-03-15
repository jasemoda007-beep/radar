# اسم المود
TWEAK_NAME = WessamMod

# الملفات المراد جمعها (Tweak + ملفات مكتبة ImGui)
WessamMod_FILES = Tweak.xm $(wildcard ImGui/*.cpp) $(wildcard ImGui/backends/*.mm)

# مكتبات النظام الضرورية للرسم واللمس
WessamMod_FRAMEWORKS = UIKit Foundation Metal MetalKit QuartzCore CoreGraphics

# إعدادات المعالج والأمان
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
