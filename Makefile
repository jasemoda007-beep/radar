# اسم المود
TWEAK_NAME = WessamMod

# إخبار المترجم أين يجد ملفات ImGui التي جلبها GitHub
WessamMod_FILES = Tweak.xm $(wildcard ImGui/*.cpp) $(wildcard ImGui/*.mm)
WessamMod_CFLAGS = -fobjc-arc -IImGui

# المكتبات الرسمية
WessamMod_FRAMEWORKS = UIKit Foundation Metal MetalKit QuartzCore

include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
