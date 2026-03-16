#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <substrate.h>
#import <MetalKit/MetalKit.h>
#import "ImGui/imgui.h"
#import "ImGui/imgui_impl_metal.h"

// ==========================================
// [ 0. إعدادات السيرفر والروابط ]
// ==========================================
namespace ServerConfig {
    NSString *LoginAPI = @"http://34.204.178.160/manager/api.php";
    NSString *OffsetsJSON = @"http://34.204.178.160/manager/offsets.json";
}

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
}

enum ModState { LOGIN, ACTIVATING, SUCCESS_CARD, MAIN_MENU };
ModState g_State = LOGIN;
bool showMenu = true; 
bool imguiInitialized = false; 
NSArray *g_OnlineBypass = nil;

struct UserData {
    NSString *key;
    NSString *type;
    NSString *startDate;
    NSString *endDate;
} g_User;

bool radarBox = true, aimbot = false, noRecoil = false;

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

void fetch_json_and_inject() {
    NSURL *url = [NSURL URLWithString:ServerConfig::OffsetsJSON];
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

// ==========================================
// [ 5. واجهات ImGui (تصميم الخدود الطويلة + الدخول المباشر) ]
// ==========================================
void ShowUI() {
    // تصميم طولي مع حجم كبير متناسق
    ImGui::SetNextWindowSize(ImVec2(550, 950), ImGuiCond_FirstUseEver);
    
    if (g_State == LOGIN || g_State == ACTIVATING) {
        ImGui::Begin("WESSAM CYBER - LOGIN", &showMenu, ImGuiWindowFlags_NoCollapse);
        
        if (g_State == LOGIN) {
            ImGui::TextColored(ImVec4(0, 1, 0, 1), "System Ready for Injection!");
            ImGui::Spacing();
            ImGui::Spacing();
            ImGui::Separator();
            ImGui::Spacing();
            
            // زر الدخول المباشر لتخطي مشكلة الكيبورد مؤقتاً
            if (ImGui::Button("AUTO LOGIN (TEST) 🚀", ImVec2(-1, 90))) {
                g_User.key = @"WESSAM-TEST";
                g_User.type = @"VIP Developer";
                g_User.startDate = @"Today";
                g_User.endDate = @"Forever";
                g_State = SUCCESS_CARD;
            }
            ImGui::Spacing();
            ImGui::TextWrapped("Note: Press the button above to bypass the keyboard and enter the menu directly.");

        } else {
            ImGui::TextColored(ImVec4(1, 1, 0, 1), "Connecting to Server...");
            ImGui::Text("Please wait...");
        }
        ImGui::End();
    } 
    else if (g_State == SUCCESS_CARD) {
        ImGui::Begin("SUCCESS", &showMenu, ImGuiWindowFlags_NoCollapse);
        ImGui::TextColored(ImVec4(0, 1, 0, 1), "Mod Activated Successfully!");
        ImGui::Separator();
        ImGui::Text("Key: %s", [g_User.key UTF8String]);
        ImGui::Text("Type: %s", [g_User.type UTF8String]);
        ImGui::Text("Start: %s", [g_User.startDate UTF8String]);
        ImGui::Text("End: %s", [g_User.endDate UTF8String]);
        ImGui::Separator();
        
        if (ImGui::Button("ENTER MAIN MENU 🎮", ImVec2(-1, 90))) {
            g_State = MAIN_MENU;
        }
        ImGui::End();
    } 
    else if (g_State == MAIN_MENU) {
        ImGui::Begin("WESSAM MOD PANEL", &showMenu);
        if (ImGui::BeginTabBar("Tabs")) {
            if (ImGui::BeginTabItem("ESP (Radar)")) {
                ImGui::Spacing();
                ImGui::Checkbox(" Enable ESP Boxes", &radarBox);
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("Aimbot")) {
                ImGui::Spacing();
                ImGui::Checkbox(" Enable Magic Bullet", &aimbot);
                ImGui::Spacing();
                if (ImGui::Checkbox(" Enable No Recoil", &noRecoil)) {
                    uintptr_t addr = get_base(NULL) + Offsets::Recoil;
                    patch_memory(addr, noRecoil ? @"00 00 00 00" : @"00 00 A0 41");
                }
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("Server Bypass")) {
                ImGui::Spacing();
                ImGui::TextColored(ImVec4(0, 1, 0, 1), "Injected Online Bypasses:");
                if (g_OnlineBypass) {
                    for (NSDictionary *item in g_OnlineBypass) {
                        ImGui::BulletText("%s", [item[@"name"] UTF8String]);
                    }
                } else {
                    ImGui::Text("No bypass loaded yet.");
                }
                ImGui::EndTabItem();
            }
            ImGui::EndTabBar();
        }
        ImGui::End();
    }
}

// ==========================================
// [ 6. الطبقة العائمة (العودة للأساس القوي مع إصلاح الأبعاد) ]
// ==========================================
static MTKView *g_MTKView = nil;

@interface WessamOverlay : UIView <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@end

@implementation WessamOverlay
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;

        g_MTKView = [[MTKView alloc] initWithFrame:self.bounds];
        g_MTKView.device = MTLCreateSystemDefaultDevice();
        g_MTKView.backgroundColor = [UIColor clearColor];
        g_MTKView.clearColor = MTLClearColorMake(0, 0, 0, 0);
        g_MTKView.delegate = self;
        
        [self addSubview:g_MTKView];

        self.commandQueue = [g_MTKView.device newCommandQueue];
        
        ImGui::CreateContext();
        ImGui_ImplMetal_Init(g_MTKView.device);
        
        ImGuiIO& io = ImGui::GetIO();
        io.FontGlobalScale = 2.5f; 
        ImGui::GetStyle().ScaleAllSizes(2.5f);
        
        imguiInitialized = true;
    }
    return self;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}

- (void)drawInMTKView:(MTKView *)view {
    if (!showMenu && !radarBox) return;

    ImGuiIO& io = ImGui::GetIO();
    // أخذ أبعاد النافذة الحالية دائماً
    io.DisplaySize = ImVec2(view.bounds.size.width, view.bounds.size.height);

    MTLRenderPassDescriptor *desc = view.currentRenderPassDescriptor;
    if (!desc) return;

    id<MTLCommandBuffer> buffer = [self.commandQueue commandBuffer];
    ImGui_ImplMetal_NewFrame(desc);
    ImGui::NewFrame();

    ShowUI();

    ImGui::Render();
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:desc];
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), buffer, encoder);
    [encoder endEncoding];
    [buffer presentDrawable:view.currentDrawable];
    [buffer commit];
}
@end

// ==========================================
// [ 7. محرك الهوك (إجبار الشاشة بالعرض Landscape) ]
// ==========================================
%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            // حساب العرض والطول الحقيقي للعبة بالعرض غصباً عن قراءات النظام
            CGFloat w = MAX([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
            CGFloat h = MIN([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height);
            
            WessamOverlay *overlay = [[WessamOverlay alloc] initWithFrame:CGRectMake(0, 0, w, h)];
            
            // التمدد مع الشاشة في حال حدوث أي دوران
            overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            g_MTKView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            
            [self addSubview:overlay];
        });
    });
}

- (void)sendEvent:(UIEvent *)event {
    if (imguiInitialized && g_MTKView) {
        ImGuiIO& io = ImGui::GetIO();
        UITouch *touch = [[event allTouches] anyObject];
        
        if (touch) {
            // أخذ الإحداثيات من g_MTKView مباشرة حتى ما يصير أي انحراف باللمس
            CGPoint loc = [touch locationInView:g_MTKView];
            io.MousePos = ImVec2(loc.x, loc.y);
            
            if (touch.phase == UITouchPhaseBegan) io.MouseDown[0] = true;
            else if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) io.MouseDown[0] = false;
        }
    }
    
    UITouch *touch3 = [[event allTouches] anyObject];
    if ([[event allTouches] count] == 3 && touch3 && touch3.phase == UITouchPhaseBegan) {
        showMenu = !showMenu;
    }

    %orig;
}
%end

- (void)sendEvent:(UIEvent *)event {
    if (imguiInitialized && g_MTKView) {
        ImGuiIO& io = ImGui::GetIO();
        UITouch *touch = [[event allTouches] anyObject];
        
        if (touch) {
            CGPoint loc = [touch locationInView:g_MTKView];
            io.MousePos = ImVec2(loc.x, loc.y);
            
            if (touch.phase == UITouchPhaseBegan) io.MouseDown[0] = true;
            else if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) io.MouseDown[0] = false;
        }
    }
    
    UITouch *touch3 = [[event allTouches] anyObject];
    if ([[event allTouches] count] == 3 && touch3 && touch3.phase == UITouchPhaseBegan) {
        showMenu = !showMenu;
    }

    %orig;
}
%end
