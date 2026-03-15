#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <substrate.h>
#import "ImGui/imgui.h"

// --- [ 1. تعريف حالات المود والاشتراك ] ---
enum ModState { LOGIN, LOADING, SUCCESS_CARD, MAIN_MENU };
ModState g_State = LOGIN;

struct UserSub {
    NSString *key;
    NSString *type;      // يومي، أسبوعي، شهري
    NSString *startDate;
    NSString *endDate;
    int daysLeft;
} g_User;

NSArray *g_OnlineFeatures = nil;

// --- [ 2. بنك أوفستات أحمد الثابتة ] ---
namespace AhmedOffsets {
    uintptr_t GWorld = 0x106684010;
    uintptr_t ViewMatrix = 0x105EFB82C;
    int Team = 0x938;
    int Health = 0xdb8;
    int Mesh = 0x4a8;
    int Recoil = 0xc50;
    int Robot = 0x9d0;
}

// متغيرات التحكم بالرادار والأيم بوت
bool radarBox = true, radarLine = false, radarHealth = true;
bool aimbot = false, noRecoil = false, drawFOV = true;
float aimFOV = 120.0f, aimSmooth = 0.5f;

// --- [ 3. محرك الذاكرة والحقن (Module Finder) ] ---

uintptr_t get_module_base(const char *moduleName) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        if (strstr(_dyld_get_image_name(i), moduleName)) return (uintptr_t)_dyld_get_image_header(i);
    }
    return (uintptr_t)_dyld_get_image_header(0); // الافتراضي هو اللعبة نفسها
}

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

// --- [ 4. نظام الشبكة والتحقق ] ---

void fetch_json() {
    NSURL *url = [NSURL URLWithString:@"http://34.204.178.160/manager/offsets.json"];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (data) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        g_OnlineFeatures = json[@"features"];
    }
}

void login_process(NSString *key) {
    g_State = LOADING;
    NSString *udid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString *urlStr = [NSString stringWithFormat:@"http://34.204.178.160/manager/api.php?key=%@&hwid=%@", key, udid];
    
    // محاكاة استجابة السيرفر وتجهيز بطاقة الاشتراك
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_User.key = key;
        g_User.startDate = @"2026-03-16"; // تاريخ اليوم
        g_User.endDate = @"2026-04-16";   // مثال لشهر
        g_User.type = @"اشتراك شهري (VIP)";
        g_User.daysLeft = 30;
        
        fetch_json(); // جلب الأوفستات أونلاين
        g_State = SUCCESS_CARD;
    });
}

// --- [ 5. واجهات ImGui الجميلة ] ---

void SetStyle() {
    ImGuiStyle& s = ImGui::GetStyle();
    s.WindowRounding = 15;
    s.FrameRounding = 8;
    s.Colors[ImGuiCol_TitleBgActive] = ImColor(255, 0, 0); // أحمر
    s.Colors[ImGuiCol_CheckMark] = ImColor(0, 255, 65);   // أخضر
}

// 1. نافذة اللوكن
void ShowLogin() {
    ImGui::SetNextWindowSize(ImVec2(350, 220));
    ImGui::Begin("🛰️ تسجيل الدخول | WESSAM PRO", NULL, ImGuiWindowFlags_NoCollapse);
    static char k[64] = "";
    ImGui::Text("أدخل كود التفعيل:");
    ImGui::InputText("##k", k, 64);
    if (ImGui::Button("تفعيل المود 🚀", ImVec2(-1, 45))) {
        login_process([NSString stringWithUTF8String:k]);
    }
    if (g_State == LOADING) ImGui::TextColored(ImVec4(1,1,0,1), "جاري فحص الكود والـ UDID...");
    ImGui::End();
}

// 2. بطاقة نجاح الاشتراك
void ShowSuccessCard() {
    ImGui::SetNextWindowSize(ImVec2(350, 280));
    ImGui::Begin("✅ تفعيل الاشتراك", NULL, ImGuiWindowFlags_NoCollapse);
    ImGui::TextColored(ImVec4(0,1,0,1), "تم تفعيل الجهاز بنجاح!");
    ImGui::Separator();
    ImGui::Text("نوع الاشتراك: %s", [g_User.type UTF8String]);
    ImGui::Text("تاريخ البدء: %s", [g_User.startDate UTF8String]);
    ImGui::Text("تاريخ الانتهاء: %s", [g_User.endDate UTF8String]);
    ImGui::Text("المتبقي: %d يوم", g_User.daysLeft);
    ImGui::Separator();
    if (ImGui::Button("دخول إلى القائمة الرئيسية 🎮", ImVec2(-1, 45))) g_State = MAIN_MENU;
    ImGui::End();
}

// 3. القائمة الرئيسية
void ShowMainMenu() {
    SetStyle();
    ImGui::Begin("🛰️ WESSAM COMMAND CENTER v10.0");
    if (ImGui::BeginTabBar("Tabs")) {
        if (ImGui::BeginTabItem("👁️ رادار ESP")) {
            ImGui::Checkbox("إظهار الصناديق", &radarBox);
            ImGui::Checkbox("خطوط الأعداء", &radarLine);
            ImGui::Checkbox("عرض الصحة", &radarHealth);
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("🎯 القتال")) {
            ImGui::Checkbox("أيم بوت (Aim)", &aimbot);
            ImGui::SliderFloat("النطاق (FOV)", &aimFOV, 50, 500);
            if (ImGui::Checkbox("ثبات سلاح (Recoil)", &noRecoil)) {
                patch_hex(get_module_base("ShadowTrackerExtra") + AhmedOffsets::Recoil, @"00 00 00 00");
            }
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("🛡️ حماية أونلاين")) {
            for (NSDictionary *f in g_OnlineFeatures) {
                if (ImGui::Button([f[@"name"] UTF8String], ImVec2(-1, 0))) {
                    patch_hex(get_module_base([f[@"module"] UTF8String]), f[@"byte"]);
                }
            }
            ImGui::EndTabItem();
        }
        ImGui::EndTabBar();
    }
    ImGui::Separator();
    ImGui::TextColored(ImVec4(0.5,0.5,0.5,1), "ينتهي في: %s", [g_User.endDate UTF8String]);
    ImGui::End();
}

// --- [ 6. الربط والتشغيل ] ---
%hook MTLCommandBuffer
- (void)presentDrawable:(id)drawable {
    if (g_State == LOGIN || g_State == LOADING) ShowLogin();
    else if (g_State == SUCCESS_CARD) ShowSuccessCard();
    else if (g_State == MAIN_MENU) ShowMainMenu();
    %orig;
}
%end
