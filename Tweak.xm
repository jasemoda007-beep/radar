#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <substrate.h>
#import <MetalKit/MetalKit.h>
#import "ImGui/imgui.h"
#import "ImGui/imgui_impl_metal.h"

// --- [ 1. بنك الأوفستات والعناوين المحدثة (قائمة مسعود الجديدة) ] ---
namespace AhmedOffsets {
    // العناوين الجديدة التي زودتني بها
    uintptr_t UWorld = 0x106684010;
    uintptr_t GNames = 0x104C0F1E8;
    uintptr_t hookHUD = 0x108687C80;
    uintptr_t GetHUD = 0x1034AAF1C;
    uintptr_t DrawText = 0x10633B4E0;
    uintptr_t DrawLine = 0x105F52364;
    uintptr_t DrawRectFilled = 0x105F522D4;
    uintptr_t DrawCircleFilled = 0x10633B94C;
    uintptr_t Engine = 0x10A4A0768;
    uintptr_t BonePos = 0x1031DEDEC;
    uintptr_t ProjectWorldLocationToScreen = 0x105EFB82C;

    // أوفستات اللاعبين (من القائمة السابقة)
    int SelfOffset = 0x27a8;
    int Team = 0x938;
    int Health = 0xdb8;
    int Mesh = 0x4a8;
    int Robot = 0x9d0;
    int Recoil = 0xc50;
}

// --- [ 2. متغيرات التحكم والحالات ] ---
enum ModState { LOGIN, LOADING, SUCCESS_CARD, MAIN_MENU };
ModState g_State = LOGIN;

struct UserSub {
    NSString *key;
    NSString *type;
    NSString *endDate;
} g_User;

bool radarBox = true, radarLine = false, radarHealth = true;
bool aimbot = false, noRecoil = false;
float aimFOV = 120.0f;

// --- [ 3. محرك الذاكرة ] ---
uintptr_t get_base() { return (uintptr_t)_dyld_get_image_header(0); }

void patch_hex(uintptr_t addr, NSString *hex) {
    if (!addr) return;
    hex = [hex stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableData *data = [NSMutableData data];
    for (int i = 0; i < [hex length]; i += 2) {
        unsigned int b;
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(i, 2)]] scanHexInt:&b];
        [data appendBytes:&b length:1];
    }
    vm_protect(mach_task_self(), (vm_address_t)addr, data.length, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    memcpy((void *)addr, data.bytes, data.length);
    vm_protect(mach_task_self(), (vm_address_t)addr, data.length, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
}

// --- [ 4. نظام الدخول ] ---
void login_process(NSString *key) {
    g_State = LOADING;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_User.key = key;
        g_User.type = @"VIP LIFETIME";
        g_User.endDate = @"2027-01-01";
        g_State = SUCCESS_CARD;
    });
}

// --- [ 5. القائمة الرئيسية ] ---
void ShowMainMenu() {
    ImGui::Begin("🛰️ WESSAM CYBER V14 - OFFICIAL");
    if (ImGui::BeginTabBar("Tabs")) {
        if (ImGui::BeginTabItem("👁️ الرادار")) {
            ImGui::Checkbox("إظهار الصناديق", &radarBox);
            ImGui::Checkbox("عرض الصحة", &radarHealth);
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("🎯 القتال")) {
            ImGui::Checkbox("أيم بوت", &aimbot);
            if (ImGui::Checkbox("ثبات سلاح (No Recoil)", &noRecoil)) {
                patch_hex(get_base() + AhmedOffsets::Recoil, noRecoil ? @"00 00 00 00" : @"00 00 A0 41");
            }
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("⚙️ الإحداثيات")) {
            ImGui::Text("UWorld: 0x%lx", AhmedOffsets::UWorld);
            ImGui::Text("GNames: 0x%lx", AhmedOffsets::GNames);
            ImGui::Text("Engine: 0x%lx", AhmedOffsets::Engine);
            ImGui::EndTabItem();
        }
        ImGui::EndTabBar();
    }
    ImGui::Separator();
    ImGui::Text("Expiry: %s", [g_User.endDate UTF8String]);
    ImGui::End();
}

// --- [ 6. محرك الحقن المطور (حل مشكلة commandBuffer) ] ---
%hook MTKView
- (void)drawRect:(CGRect)rect {
    %orig;

    // الحصول على واصف الرسم الحالي
    MTLRenderPassDescriptor *descriptor = self.currentRenderPassDescriptor;
    if (!descriptor) return;

    static id<MTLCommandQueue> commandQueue = nil;
    if (!commandQueue) {
        commandQueue = [self.device newCommandQueue];
    }

    // إنشاء commandBuffer جديد بشكل صحيح
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

    static BOOL setup = NO;
    if (!setup) {
        ImGui_ImplMetal_Init(self.device);
        setup = YES;
    }

    // بدء فريم ImGui
    ImGui_ImplMetal_NewFrame(descriptor);
    ImGui::NewFrame();

    if (g_State == LOGIN) {
        ImGui::Begin("LOGIN");
        static char k[64] = "";
        ImGui::InputText("Key", k, 64);
        if (ImGui::Button("ACTIVATE")) login_process([NSString stringWithUTF8String:k]);
        ImGui::End();
    } else if (g_State == SUCCESS_CARD) {
        ImGui::Begin("SUCCESS");
        ImGui::TextColored(ImVec4(0,1,0,1), "Welcome Eng. Masoud!");
        if (ImGui::Button("OPEN MOD")) g_State = MAIN_MENU;
        ImGui::End();
    } else if (g_State == MAIN_MENU) {
        ShowMainMenu();
    }

    ImGui::Render();

    // إنشاء Encoder للرسم النهائي (هذا هو الإصلاح للخطأ السابق)
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    [renderEncoder pushDebugGroup:@"ImGui_Render"];
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, renderEncoder);
    [renderEncoder popDebugGroup];
    [renderEncoder endEncoding];

    // عرض النتيجة على الشاشة
    [commandBuffer presentDrawable:self.currentDrawable];
    [commandBuffer commit];
}
%end
