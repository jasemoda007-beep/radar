#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <substrate.h>
#import <MetalKit/MetalKit.h>
#import "ImGui/imgui.h"
#import "ImGui/imgui_impl_metal.h"

// --- [ 1. بنك الأوفستات والعناوين المحدثة 2026 ] ---
namespace AhmedOffsets {
    // العناوين الأساسية (Core Addresses)
    uintptr_t GWorld = 0x106684010; 
    uintptr_t GNames = 0x104C0F1E8;
    uintptr_t Engine = 0x10A4A0768;

    // وظائف الرسم والمواقع (Rendering & Functions)
    uintptr_t hookHUD = 0x108687C80;
    uintptr_t GetHUD = 0x1034AAF1C;
    uintptr_t DrawText = 0x10633B4E0;
    uintptr_t DrawLine = 0x105F52364;
    uintptr_t DrawRectFilled = 0x105F522D4;
    uintptr_t DrawCircleFilled = 0x10633B94C;
    uintptr_t BonePos = 0x1031DEDEC;
    uintptr_t ViewMatrix = 0x105EFB82C; // ProjectWorldLocationToScreen

    // أوفستات البيانات الداخلية (Internal Offsets)
    int ULevel = 0x30;
    int ActorArray = 0xA0;
    int ActorCount = 0xA8;
    int Mesh = 0x4a8;
    int Team = 0x938;
    int Health = 0xdb8;
    int Robot = 0x9d0;
    int Recoil = 0xc50;
    int Angle = 0x508;
}

// --- [ 2. متغيرات التحكم ] ---
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_User.key = key;
        g_User.type = @"VIP FULL ACCESS";
        g_User.endDate = @"2026-05-01";
        g_State = SUCCESS_CARD;
    });
}

// --- [ 5. القائمة الرئيسية ] ---
void ShowMainMenu() {
    ImGui::Begin("🛰️ WESSAM CYBER - INTERNAL V13");
    
    if (ImGui::BeginTabBar("MainTabs")) {
        if (ImGui::BeginTabItem("👁️ الرادار")) {
            ImGui::Checkbox("تفعيل الصناديق", &radarBox);
            ImGui::Checkbox("تفعيل الخطوط", &radarLine);
            ImGui::Checkbox("عرض الصحة (0xdb8)", &radarHealth);
            ImGui::EndTabItem();
        }
        
        if (ImGui::BeginTabItem("🎯 القتال")) {
            ImGui::Checkbox("أيم بوت تلقائي", &aimbot);
            ImGui::SliderFloat("نطاق الأيم (FOV)", &aimFOV, 30, 500);
            
            ImGui::Separator();
            
            if (ImGui::Checkbox("ثبات السلاح (0xc50)", &noRecoil)) {
                uintptr_t recoilAddr = get_base() + AhmedOffsets::Recoil;
                patch_hex(recoilAddr, noRecoil ? @"00 00 00 00" : @"00 00 A0 41"); 
            }
            ImGui::EndTabItem();
        }

        if (ImGui::BeginTabItem("🛠️ معلومات المحرك")) {
            ImGui::Text("GWorld: 0x%lx", AhmedOffsets::GWorld);
            ImGui::Text("Engine: 0x%lx", AhmedOffsets::Engine);
            ImGui::Text("BonePos: 0x%lx", AhmedOffsets::BonePos);
            ImGui::EndTabItem();
        }
        ImGui::EndTabBar();
    }
    ImGui::Separator();
    ImGui::Text("User: %s | Expiry: %s", [g_User.key UTF8String], [g_User.endDate UTF8String]);
    ImGui::End();
}

// --- [ 6. حقن الرسم (MTKView) ] ---
%hook MTKView
- (void)drawRect:(CGRect)rect {
    %orig;
    static BOOL setup = NO;
    if (!setup) {
        ImGui_ImplMetal_Init(self.device);
        setup = YES;
    }

    ImGui_ImplMetal_NewFrame(self.currentRenderPassDescriptor);
    ImGui::NewFrame();

    if (g_State == LOGIN) {
        ImGui::Begin("SECURITY CHECK");
        static char k[64] = "";
        ImGui::InputText("License Key", k, 64);
        if (ImGui::Button("ACTIVATE", ImVec2(-1, 40))) login_process([NSString stringWithUTF8String:k]);
        ImGui::End();
    } 
    else if (g_State == SUCCESS_CARD) {
        ImGui::Begin("SUCCESS");
        ImGui::TextColored(ImVec4(0,1,0,1), "Welcome back, Eng. Masoud!");
        ImGui::Text("Subscription: %s", [g_User.type UTF8String]);
        if (ImGui::Button("OPEN CONTROL PANEL", ImVec2(-1, 40))) g_State = MAIN_MENU;
        ImGui::End();
    } 
    else if (g_State == MAIN_MENU) {
        ShowMainMenu();
    }

    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), self.currentDrawable.commandBuffer, self.currentDrawable.texture);
}
%end
