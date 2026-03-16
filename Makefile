# ==========================================
# [ فرن الصهر - Wessam Mod ]
# ==========================================

# تحديد المعمارية (لأجهزة أبل الحديثة) وإصدار النظام
ARCHS = arm64
TARGET = iphone:clang:latest:14.0

include $(THEOS)/makefiles/common.mk

# اسم المود (هذا هو الاسم الذي سيظهر لملف الدايلب النهائي)
TWEAK_NAME = WessamMod

# دمج ملف التويك الأساسي مع ملفات مكتبة ImGui
WessamMod_FILES = Tweak.xm $(wildcard ImGui/*.cpp)

# مكتبة الهوك الأساسية (بدونها لا يعمل أي شيء)
WessamMod_LIBRARIES = substrate

# إطارات أبل المطلوبة للرسم والواجهات (مهمة جداً للطبقة العائمة)
WessamMod_FRAMEWORKS = UIKit Foundation Metal MetalKit QuartzCore

# إعدادات لغة البرمجة (لتجاهل التحذيرات المزعجة ودعم ++C)
WessamMod_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable
WessamMod_CCFLAGS = -std=c++14 -fno-rtti -fno-exceptions

include $(THEOS_MAKE_PATH)/tweak.mk
