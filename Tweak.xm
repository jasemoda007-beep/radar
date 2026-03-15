#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import "ImGui/imgui.h"
#import "ImGui/imgui_impl_metal.h"

// --- [ قسم الأوفستات - Eng. Wessam ] ---
#define GWorld_Addr 0x106684010
#define GNames_Addr 0x104C0F1E8
#define ProjectToScreen_Addr 0x105EFB82C

// متغيرات التحكم
bool showMenu = true;
bool espEnabled = false;

// --- [ واجهة ImGui الاحترافية ] ---
void DrawInterface() {
    if (!showMenu) return;

    ImGui::Begin("Cyber Security Mod | Wessam", &showMenu);
    if (ImGui::BeginTabBar("Tabs")) {
        if (ImGui::BeginTabItem("Home")) {
            ImGui::Text("Welcome Eng. Wessam");
            if (ImGui::Button("Login (Online Check)")) { /* كود السيرفر */ }
            ImGui::EndTabItem();
        }
        if (ImGui::BeginTabItem("Visuals")) {
            ImGui::Checkbox("Enable ESP Radar", &espEnabled);
            ImGui::EndTabItem();
        }
        ImGui::EndTabBar();
    }
    ImGui::End();
}

// --- [ حقن الكود داخل اللعبة ] ---
%hook MTLCommandBuffer
- (void)presentDrawable:(id)drawable {
    // هنا يتم استدعاء رسم الواجهة والرادار في كل فريم
    DrawInterface(); 
    %orig;
}
%end

// نقطة البداية
__attribute__((constructor))
static void init() {
    NSLog(@"[WessamMod] Mod Loaded Successfully!");
}
