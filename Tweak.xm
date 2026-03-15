#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <substrate.h>
#import <MetalKit/MetalKit.h>
#import "ImGui/imgui.h"
#import "ImGui/imgui_impl_metal.h"

// --- [ 1. بنك البيانات والأوفستات الكامل ] ---
namespace Global {
    uintptr_t GWorld = 0x10A4A1960;
    uintptr_t GNames = 0x10A0557E0;
    uintptr_t GObject = 0x10A288B80;
    uintptr_t W2S = 0x105EFB82C;
}

namespace Offsets {
    int ULevel = 0x30;
    int ActorArray = 0xA0;
    int ActorCount = 0xA8;
    int Health = 0xdb8;
    int Team = 0x938;
    int Mesh = 0x4a8;
    int Robot = 0x9d0;
    int Recoil = 0xc50;
    int WeaponOne = 0x29f0;
}

// --- [ 2. حالات المود والاشتراك ] ---
enum ModState { LOGIN, ACTIVATING, SUCCESS_CARD, MAIN_MENU };
ModState g_State = LOGIN;
bool showMenu = true;
NSArray *g_OnlineBypass = nil; // تخزين حماية الـ JSON

struct UserSub {
    NSString *key;
    NSString *type; // يومي، أسبوعي، شهري
    NSString *start;
    NSString *end;
    bool isActive;
} g_User;

// خيارات التحكم
bool radarBox = true, aimbot = false, noRecoil = false;

// --- [ 3. محرك الذاكرة والشبكة ] ---
uintptr_t get_base(const char* module) {
    if(!module) return (uintptr_t)_dyld_get_image_header(0);
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        if (strstr(_dyld_get_image_name(i), module)) return (uintptr_t)_dyld_get_image_header(i);
    }
    return 0;
}

void patch_memory(uintptr_t addr, NSString *hex) {
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

// جلب وحقن الحماية من ملف الـ JSON
void inject_online_protection() {
    NSURL *url = [NSURL URLWithString:@"http://34.204.178.160/manager/offsets.json"];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (data) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        g_OnlineBypass = json[@"protection"];
        for (NSDictionary *item in g_OnlineBypass) {
            uintptr_t moduleBase = get_base([item[@"module"] UTF8String]);
            uintptr_t offset = (uintptr_t)strtoull([item[@"offset"] UTF8String], NULL, 16);
            patch_memory(moduleBase + offset, item[@"patch"]);
        }
    }
}

// عملية الدخول الاحترافية
void login_process(NSString *key) {
    g_State = ACTIVATING;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // هنا يتم فحص الـ API.php
        g_User.key = key;
        g_User.type = @"اشتراك شهري (VIP)";
        g_User.start = @"2026-03-16";
        g_User.end = @"2026-04-16";
        
        inject_online_protection(); // حقن الحماية فور النجاح
        g_State = SUCCESS_CARD;
    });
}

// --- [ 4. الواجهات الرسومية ] ---

void ShowLoginUI() {
    ImGui::Begin("🛰️ WESSAM PRO - LOGIN", &showMenu, ImGuiWindowFlags_NoCollapse);
    if (g_State == LOGIN) {
        static char k[64] = "";
        ImGui::Text("أدخل مفتاح التفعيل:");
        ImGui::InputText("##key", k, 64);
        if (ImGui::Button("تفعيل الاشتراك 🚀", ImVec2(-1, 45))) login_process([NSString stringWithUTF8String:k]);
    } else {
        ImGui::Indent(120);
        ImGui::TextColored(ImVec4(1,1,0,1), "جاري فحص الحماية...");
        ImGui::Text("جاري الاتصال بالسيرفر...");
        // انيميشن بسيط (يمكن إضافة دائرة تحميل هنا)
    }
    ImGui::End();
}

void ShowSuccessCard() {
    ImGui::Begin("✅ تم التفعيل بنجاح", &showMenu, ImGuiWindowFlags_NoCollapse);
    ImGui::TextColored(ImVec4(0,1,0,1), "مرحباً بك في عالم الاحتراف!");
    ImGui::Separator();
    
    ImGui::BeginChild("Info", ImVec2(0, 120), true);
    ImGui::Text("المفتاح: %s", [g_User.key UTF8String]);
    ImGui::Text("نوع الاشتراك: %s", [g_User.type UTF8String]);
    ImGui::Text("تاريخ البدء: %s", [g_User.start UTF8String]);
    ImGui::Text("تاريخ الانتهاء: %s", [g_User.end UTF8String]);
    ImGui::EndChild();

    if (ImGui::Button("دخول للقائمة الرئيسية 🎮", ImVec2(-1, 45))) g_State = MAIN_MENU;
    ImGui::End();
}

void ShowMainMenu() {
    ImGui::Begin("🛰️ WESSAM CYBER CENTER V21");
    if (ImGui::BeginTabBar("Tabs")) {
        if (ImGui::BeginTabItem("👁️ رادار")) {
            ImGui::Checkbox("تفعيل صناديق ESP", &radarBox);
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("🎯 قتال")) {
            ImGui::Checkbox("أيم بوت (Magic)", &aimbot);
            if (ImGui::Checkbox("ثبات سلاح (No Recoil)", &noRecoil)) {
                patch_memory(get_base(NULL) + Offsets::Recoil, noRecoil ? @"00 00 00 00" : @"00 00 A0 41");
            }
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("🛡️ حماية أونلاين")) {
            ImGui::Text("الحماية المحقونة من السيرفر:");
            for (NSDictionary *item in g_OnlineBypass) {
                ImGui::BulletText("%s", [item[@"name"] UTF8String]);
            }
            ImGui::EndTabItem();
        }
        ImGui::EndTabBar();
    }
    ImGui::End();
}

// --- [ 5. محرك اللمس والرسم ] ---
%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    %orig;
    ImGuiIO& io = ImGui::GetIO();
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint loc = [touch locationInView:self];
    io.MousePos = ImVec2(loc.x, loc.y);
    if (touch.phase == UITouchPhaseBegan) io.MouseDown[0] = true;
    if (touch.phase == UITouchPhaseEnded) io.MouseDown[0] = false;
    if ([[event allTouches] count] == 3 && touch.phase == UITouchPhaseBegan) showMenu = !showMenu;
}
%end

%hook MTKView
- (void)drawRect:(CGRect)rect {
    %orig;
    if (!showMenu) return;
    MTLRenderPassDescriptor *desc = self.currentRenderPassDescriptor;
    if (!desc) return;

    static id<MTLCommandQueue> queue = nil;
    if (!queue) { queue = [self.device newCommandQueue]; ImGui_ImplMetal_Init(self.device); }

    ImGui::GetIO().DisplaySize = ImVec2(rect.size.width, rect.size.height);
    id<MTLCommandBuffer> buffer = [queue commandBuffer];
    ImGui_ImplMetal_NewFrame(desc);
    ImGui::NewFrame();

    if (g_State == LOGIN || g_State == ACTIVATING) ShowLoginUI();
    else if (g_State == SUCCESS_CARD) ShowSuccessCard();
    else if (g_State == MAIN_MENU) ShowMainMenu();

    ImGui::Render();
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:desc];
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), buffer, encoder);
    [encoder endEncoding];
    [buffer presentDrawable:self.currentDrawable];
    [buffer commit];
}
%end
