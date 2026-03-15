#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <substrate.h>
#import <MetalKit/MetalKit.h>
#import "ImGui/imgui.h"
#import "ImGui/imgui_impl_metal.h"

// --- [ 1. بنك الأوفستات (أحمد) ] ---
namespace AhmedOffsets {
    uintptr_t UWorld = 0x106684010;
    uintptr_t GNames = 0x104C0F1E8;
    uintptr_t Engine = 0x10A4A0768;
    uintptr_t BonePos = 0x1031DEDEC;
    uintptr_t ProjectWorldLocationToScreen = 0x105EFB82C;
    int Health = 0xdb8;
    int Recoil = 0xc50;
}

// --- [ 2. متغيرات التحكم والظهور ] ---
enum ModState { LOGIN, LOADING, SUCCESS_CARD, MAIN_MENU };
ModState g_State = LOGIN;
bool showMenu = true; // مفتاح إظهار وإخفاء المنيو

struct UserSub {
    NSString *key;
    NSString *type;
    NSString *endDate;
} g_User;

bool radarBox = true, radarHealth = true, aimbot = false, noRecoil = false;

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

// --- [ 4. نظام اللمس والنقر بـ 3 أصابع ] ---
%hook UIWindow
- (void)sendEvent:(UIEvent *)event {
    %orig;

    // الحصول على بيانات اللمس لـ ImGui
    ImGuiIO& io = ImGui::GetIO();
    UITouch *touch = [[event allTouches] anyObject];
    CGPoint location = [touch locationInView:self];

    // إرسال الإحداثيات لـ ImGui ليتحرك المنيو مع الإصبع
    io.MousePos = ImVec2(location.x, location.y);
    
    if (touch.phase == UITouchPhaseBegan) io.MouseDown[0] = true;
    if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) io.MouseDown[0] = false;

    // كشف النقر بـ 3 أصابع لإظهار/إخفاء المنيو
    if ([[event allTouches] count] == 3) {
        if (touch.phase == UITouchPhaseBegan) {
            showMenu = !showMenu;
        }
    }
}
%end

// --- [ 5. واجهات المود ] ---
void login_process(NSString *key) {
    g_State = LOADING;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        g_User.key = key;
        g_User.type = @"VIP LIFETIME";
        g_User.endDate = @"2027-01-01";
        g_State = SUCCESS_CARD;
    });
}

void ShowMainMenu() {
    ImGui::SetNextWindowSize(ImVec2(400, 300), ImGuiCond_FirstUseEver);
    if (ImGui::Begin("🛰️ WESSAM CYBER V17", &showMenu)) {
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
            ImGui::EndTabBar();
        }
    }
    ImGui::End();
}

// --- [ 6. محرك الرسم المعدل ] ---
%hook MTKView
- (void)drawRect:(CGRect)rect {
    %orig;

    if (!showMenu) return; // لا ترسم المنيو إذا كان مخفياً

    MTLRenderPassDescriptor *descriptor = self.currentRenderPassDescriptor;
    if (!descriptor) return;

    static id<MTLCommandQueue> commandQueue = nil;
    if (!commandQueue) commandQueue = [self.device newCommandQueue];

    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

    static BOOL setup = NO;
    if (!setup) {
        ImGui_ImplMetal_Init(self.device);
        setup = YES;
    }

    ImGui_ImplMetal_NewFrame(descriptor);
    ImGui::NewFrame();

    if (g_State == LOGIN) {
        ImGui::Begin("LOGIN", &showMenu);
        static char k[64] = "";
        ImGui::InputText("Key", k, 64);
        if (ImGui::Button("ACTIVATE", ImVec2(-1, 0))) login_process([NSString stringWithUTF8String:k]);
        ImGui::End();
    } else if (g_State == SUCCESS_CARD) {
        ImGui::Begin("SUCCESS", &showMenu);
        ImGui::Text("Welcome Eng. Masoud!");
        if (ImGui::Button("START MOD", ImVec2(-1, 0))) g_State = MAIN_MENU;
        ImGui::End();
    } else if (g_State == MAIN_MENU) {
        ShowMainMenu();
    }

    ImGui::Render();
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:descriptor];
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, renderEncoder);
    [renderEncoder endEncoding];

    [commandBuffer presentDrawable:self.currentDrawable];
    [commandBuffer commit];
}
%end
