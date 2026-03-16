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

// ==========================================
// [ 1. بنك الأوفستات والعناوين المتكامل ]
// ==========================================
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

// ==========================================
// [ 2. المتغيرات، الحالات، والبيانات ]
// ==========================================
enum ModState { LOGIN, ACTIVATING, SUCCESS_CARD, MAIN_MENU };
ModState g_State = LOGIN;
bool showMenu = true; 
bool imguiInitialized = false; // متغير لحماية اللعبة من الكراش
NSArray *g_OnlineBypass = nil;

struct UserData {
    NSString *key;
    NSString *type;
    NSString *startDate;
    NSString *endDate;
} g_User;

bool radarBox = true, aimbot = false, noRecoil = false;

// ==========================================
// [ 3. محرك الذاكرة ]
// ==========================================
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

// ==========================================
// [ 4. محرك السيرفر (JSON & API) ]
// ==========================================
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

void login_process(NSString *key) {
    g_State = ACTIVATING;
    NSString *udid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *urlStr = [NSString stringWithFormat:@"%@?key=%@&hwid=%@", ServerConfig::LoginAPI, key, udid];
        NSURL *url = [NSURL URLWithString:urlStr];
        NSString *response = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:nil];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([response containsString:@"SUCCESS"]) {
                NSArray *dataParts = [response componentsSeparatedByString:@"|"];
                g_User.key = key;
                if (dataParts.count >= 4) {
                    g_User.type = dataParts[1];
                    g_User.startDate = dataParts[2];
                    g_User.endDate = dataParts[3];
                } else {
                    g_User.type = @"اشتراك مدفوع";
                    g_User.startDate = @"اليوم";
                    g_User.endDate = @"غير محدد";
                }
                fetch_json_and_inject();
                g_State = SUCCESS_CARD;
            } else {
                g_State = LOGIN;
            }
        });
    });
}

// ==========================================
// [ 5. واجهات ImGui ]
// ==========================================
void ShowUI() {
    ImGui::SetNextWindowSize(ImVec2(380, 280), ImGuiCond_FirstUseEver);
    
    if (g_State == LOGIN || g_State == ACTIVATING) {
        ImGui::Begin("🛰️ WESSAM CYBER - LOGIN", &showMenu, ImGuiWindowFlags_NoCollapse);
        if (g_State == LOGIN) {
            static char k[64] = "";
            ImGui::Text("يرجى إدخال مفتاح التفعيل الخاص بك:");
            ImGui::InputText("##key", k, 64);
            ImGui::Spacing();
            if (ImGui::Button("تفعيل المود 🚀", ImVec2(-1, 45))) {
                login_process([NSString stringWithUTF8String:k]);
            }
        } else {
            ImGui::TextColored(ImVec4(1, 1, 0, 1), "⏳ جاري الاتصال بالسيرفر والتحقق...");
            ImGui::Text("الرجاء الانتظار...");
        }
        ImGui::End();
    } 
    else if (g_State == SUCCESS_CARD) {
        ImGui::Begin("✅ معلومات الاشتراك", &showMenu, ImGuiWindowFlags_NoCollapse);
        ImGui::TextColored(ImVec4(0, 1, 0, 1), "تم تفعيل التويك بنجاح!");
        ImGui::Separator();
        ImGui::Text("المفتاح: %s", [g_User.key UTF8String]);
        ImGui::Text("نوع الاشتراك: %s", [g_User.type UTF8String]);
        ImGui::Text("البداية: %s", [g_User.startDate UTF8String]);
        ImGui::Text("النهاية: %s", [g_User.endDate UTF8String]);
        ImGui::Separator();
        if (ImGui::Button("دخول إلى القائمة الرئيسية 🎮", ImVec2(-1, 45))) {
            g_State = MAIN_MENU;
        }
        ImGui::End();
    } 
    else if (g_State == MAIN_MENU) {
        ImGui::Begin("🛰️ WESSAM MOD PANEL", &showMenu);
        if (ImGui::BeginTabBar("Tabs")) {
            if (ImGui::BeginTabItem("👁️ الرادار")) {
                ImGui::Checkbox("تفعيل صندوق العدو", &radarBox);
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("🎯 القتال")) {
                ImGui::Checkbox("تفعيل الأيم بوت", &aimbot);
                if (ImGui::Checkbox("تفعيل ثبات السلاح (No Recoil)", &noRecoil)) {
                    uintptr_t addr = get_base(NULL) + Offsets::Recoil;
                    patch_memory(addr, noRecoil ? @"00 00 00 00" : @"00 00 A0 41");
                }
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("🛡️ حماية السيرفر")) {
                ImGui::TextColored(ImVec4(0, 1, 0, 1), "تم حقن الملفات التالية أونلاين:");
                if (g_OnlineBypass) {
                    for (NSDictionary *item in g_OnlineBypass) {
                        ImGui::BulletText("%s", [item[@"name"] UTF8String]);
                    }
                } else {
                    ImGui::Text("لا توجد حماية محقونة حالياً.");
                }
                ImGui::EndTabItem();
            }
            ImGui::EndTabBar();
        }
        ImGui::End();
    }
}

// ==========================================
// [ 6. الطبقة العائمة (Overlay) المضمونة 100% ]
// ==========================================
@interface WessamOverlay : UIView <MTKViewDelegate>
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@end

@implementation WessamOverlay
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO; // السماح للمس باختراق اللعبة

        self.mtkView = [[MTKView alloc] initWithFrame:frame];
        self.mtkView.device = MTLCreateSystemDefaultDevice();
        self.mtkView.backgroundColor = [UIColor clearColor];
        self.mtkView.clearColor = MTLClearColorMake(0, 0, 0, 0);
        self.mtkView.delegate = self;
        [self addSubview:self.mtkView];

        self.commandQueue = [self.mtkView.device newCommandQueue];
        
        ImGui::CreateContext();
        ImGui_ImplMetal_Init(self.mtkView.device);
        imguiInitialized = true; // تم تشغيل المنيو بأمان!
    }
    return self;
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {}

- (void)drawInMTKView:(MTKView *)view {
    if (!showMenu && !radarBox) return;

    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(view.bounds.size.width, view.bounds.size.height);

    MTLRenderPassDescriptor *desc = view.currentRenderPassDescriptor;
    if (!desc) return;

    id<MTLCommandBuffer> buffer = [self.commandQueue commandBuffer];
    ImGui_ImplMetal_NewFrame(desc);
    ImGui::NewFrame();

    ShowUI(); // رسم الواجهة

    ImGui::Render();
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:desc];
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), buffer, encoder);
    [encoder endEncoding];
    [buffer presentDrawable:view.currentDrawable];
    [buffer commit];
}
@end

// ==========================================
// [ 7. محرك الهوك المطور (اللمس وحقن الشاشة) ]
// ==========================================
%hook UIWindow
- (void)makeKeyAndVisible {
    %orig;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // حقن الشاشة الشفافة بعد 3 ثواني من فتح اللعبة لضمان التحميل
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            WessamOverlay *overlay = [[WessamOverlay alloc] initWithFrame:self.bounds];
            [self addSubview:overlay];
        });
    });
}

- (void)sendEvent:(UIEvent *)event {
    %orig;
    
    // الحماية من الكراش! لا تقرأ اللمس إذا كان المنيو لم يُرسم بعد
    if (!imguiInitialized) return;

    ImGuiIO& io = ImGui::GetIO();
    UITouch *touch = [[event allTouches] anyObject];
    if (!touch) return;
    
    CGPoint loc = [touch locationInView:self];
    
    io.MousePos = ImVec2(loc.x, loc.y);
    if (touch.phase == UITouchPhaseBegan) io.MouseDown[0] = true;
    if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) io.MouseDown[0] = false;

    // الإخفاء والظهور بـ 3 أصابع
    if ([[event allTouches] count] == 3 && touch.phase == UITouchPhaseBegan) {
        showMenu = !showMenu;
    }
}
%end
