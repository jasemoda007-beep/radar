# تحديد المعماريات الحديثة فقط 64 بت لتجنب خطأ الـ Constant Conversion
ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WessamMod

# إضافة الملفات وتحديد المسارات
WessamMod_FILES = Tweak.xm $(wildcard ImGui/*.cpp) $(wildcard ImGui/imgui_impl_metal.mm)
WessamMod_CFLAGS = -fobjc-arc -IImGui -Wno-unused-variable -Wno-constant-conversion

# المكتبات المطلوبة للرسم والحقن
WessamMod_FRAMEWORKS = UIKit Foundation Metal MetalKit QuartzCore
WessamMod_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk
