# ==========================================
# [ فرن الصهر - Wessam Mod ]
# ==========================================

ARCHS = arm64
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WessamMod

# التعديل هنا: أضفنا (wildcard ImGui/*.mm) عشان الفرن يقرأ ملف الميتال!
WessamMod_FILES = Tweak.xm $(wildcard ImGui/*.cpp) $(wildcard ImGui/*.mm)

WessamMod_LIBRARIES = substrate
WessamMod_FRAMEWORKS = UIKit Foundation Metal MetalKit QuartzCore

WessamMod_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
WessamMod_CCFLAGS = -std=c++14 -fno-rtti -fno-exceptions

include $(THEOS_MAKE_PATH)/tweak.mk
