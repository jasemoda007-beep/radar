#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <MetalKit/MetalKit.h>
#import "ImGui/imgui.h"
#import "ImGui/imgui_impl_metal.h"

// ==========================================
// [ 0. إعدادات السيرفر والمود ]
// ==========================================
namespace ServerConfig {
    NSString *LoginAPI = @"http://34.204.178.160/manager/api.php";
    NSString *OffsetsJSON = @"http://34.204.178.160/manager/offsets.json";
}

namespace Offsets { int Recoil = 0xc50; }

enum ModState { LOGIN, ACTIVATING, SUCCESS_CARD, MAIN_MENU };
ModState g_State = LOGIN;
bool showMenu = true; 
bool imguiInitialized = false; 

struct UserData {
    NSString *key;
    NSString *type;
} g_User;

bool radarBox = true, aimbot = false, noRecoil = false;

// ==========================================
// [ 1. واجهات ImGui ]
// ==========================================
void ShowUI() {
    ImGui::SetNextWindowSize(ImVec2(600, 450), ImGuiCond_FirstUseEver);
    
    if (g_State == LOGIN) {
        ImGui::Begin("WESSAM CYBER - LOGIN", &showMenu, ImGuiWindowFlags_NoCollapse);
        ImGui::TextColored(ImVec4(0, 1, 0, 1), "System Ready! (Dolphins Engine)");
        ImGui::Spacing(); ImGui::Separator(); ImGui::Spacing();
        
        if (ImGui::Button("AUTO LOGIN (TEST) 🚀", ImVec2(-1, 90))) {
            g_User.key = @"WESSAM-TEST";
            g_User.type = @"VIP Developer";
            g_State = SUCCESS_CARD;
        }
        ImGui::End();
    } 
    else if (g_State == SUCCESS_CARD) {
        ImGui::Begin("SUCCESS", &showMenu, ImGuiWindowFlags_NoCollapse);
        ImGui::TextColored(ImVec4(0, 1, 0, 1), "Mod Activated Successfully!");
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
                ImGui::EndTabItem();
            }
            ImGui::EndTabBar();
        }
        ImGui::End();
    }
}

// ==========================================
// [ 2. الطبقة العائمة (بأسلوب Dolphins الأصلي) ]
// ==========================================
@interface WessamView : MTKView <MTKViewDelegate>
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@end

@implementation WessamView
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.clearColor = MTLClearColorMake(0, 0, 0, 0);
        self.device = MTLCreateSystemDefaultDevice();
        self.delegate = self;
        
        // التمدد التلقائي مع اللعبة
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        // السماح باللمس الأصلي
        self.userInteractionEnabled = YES;
        
        // إصلاح الأبعاد (الريتنا)
        CGFloat scale = [UIScreen mainScreen].scale;
        self.contentScaleFactor = scale;

        self.commandQueue = [self.device newCommandQueue];
        
        ImGui::CreateContext();
        ImGui_ImplMetal_Init(self.device);
        
        ImGuiIO& io = ImGui::GetIO();
        io.DisplayFramebufferScale = ImVec2(scale, scale);
        io.FontGlobalScale = 2.0f; 
        ImGui::GetStyle().ScaleAllSizes(2.0f);
        
        imguiInitialized = true;
    }
    return self;
}

// ==========================================
// [ 3. محرك اللمس الأصلي (بدون هوك!) ]
// ==========================================
- (void)updateIOWithTouches:(NSSet<UITouch *> *)touches {
    ImGuiIO& io = ImGui::GetIO();
    UITouch *touch = [touches anyObject];
    if (touch) {
        CGPoint loc = [touch locationInView:self]; // هنا الآيفون يحسبها صح 100%
        io.MousePos = ImVec2(loc.x, loc.y);
        if (touch.phase == UITouchPhaseBegan) io.MouseDown[0] = true;
        else if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) io.MouseDown[0] = false;
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouches:touches]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouches:touches]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouches:touches]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouches:touches]; }

// تمرير اللمس للعبة إذا كان المنيو مغلق
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self && !showMenu) {
        return nil; // تمرير اللمس لببجي
    }
    return hitView;
}

// دالة الإخفاء والإظهار بثلاث أصابع
- (void)toggleMenu {
    showMenu = !showMenu;
}

// ==========================================
// [ 4. محرك الرسم ]
// ==========================================
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

    if (showMenu) ShowUI();
    
    // المربع التجريبي للرادار
    if (radarBox) {
        ImDrawList* draw = ImGui::GetBackgroundDrawList();
        float cx = io.DisplaySize.x / 2.0f;
        float cy = io.DisplaySize.y / 2.0f;
        draw->AddRect(ImVec2(cx - 50, cy - 100), ImVec2(cx + 50, cy + 100), IM_COL32(255,0,0,255), 0.0f, 0, 3.0f);
        draw->AddText(ImVec2(cx - 30, cy - 120), IM_COL32(0,255,0,255), "Enemy (Test)");
    }

    ImGui::Render();
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:desc];
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), buffer, encoder);
    [encoder endEncoding];
    [buffer presentDrawable:view.currentDrawable];
    [buffer commit];
}
@end

// ==========================================
// [ 5. التشغيل الذكي (مسروق من مشروع Dolphins) ]
// ==========================================
static void didFinishLaunching(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef info) {
    // ننتظر 4 ثواني حتى تفتح اللعبة وتستقر شاشتها
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(4.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
        if (!mainWindow) mainWindow = [[UIApplication sharedApplication].windows firstObject];
        
        if (mainWindow) {
            WessamView *overlay = [[WessamView alloc] initWithFrame:mainWindow.bounds];
            overlay.layer.zPosition = 99999;
            [mainWindow addSubview:overlay];
            
            // إضافة حساس أبل الأصلي للإخفاء بـ 3 أصابع
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:overlay action:@selector(toggleMenu)];
            tap.numberOfTouchesRequired = 3;
            [mainWindow addGestureRecognizer:tap];
        }
    });
}

// دالة البدء التلقائي (بدون هوك)
__attribute__((constructor)) static void initialize() {
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, &didFinishLaunching, (CFStringRef)UIApplicationDidFinishLaunchingNotification, NULL, CFNotificationSuspensionBehaviorDrop);
}
