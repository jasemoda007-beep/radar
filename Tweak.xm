#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <MetalKit/MetalKit.h>
#import "ImGui/imgui.h"
#import "ImGui/imgui_impl_metal.h"

// ==========================================
// [ 1. الأوفستات والعناوين الأساسية ]
// ==========================================
namespace ServerConfig {
    NSString *LoginAPI = @"http://34.204.178.160/manager/api.php";
    NSString *OffsetsJSON = @"http://34.204.178.160/manager/offsets.json";
}

namespace Global {
    uintptr_t GWorld_Func = 0x102A5125C; // دالة فك التشفير
    uintptr_t GWorld_Data = 0x10A4A1960; // مفتاح البيانات
}

namespace Offsets {
    int ULevel = 0x30;
    int ActorArray = 0xA0;
    int ActorCount = 0xA8;
    int Recoil = 0xc50;
}

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
// [ 2. محرك قراءة الذاكرة (Memory Tools) ]
// ==========================================
uintptr_t get_base(const char* module) {
    if(!module) return (uintptr_t)_dyld_get_image_header(0);
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        if (strstr(_dyld_get_image_name(i), module)) return (uintptr_t)_dyld_get_image_header(i);
    }
    return 0;
}

template <typename T>
T ReadMem(uintptr_t address) {
    if (address > 0x100000000 && address < 0x2000000000) {
        return *(T*)address;
    }
    return T{};
}

// ==========================================
// [ 3. محرك الرياضيات (W2S Engine) ]
// ==========================================
struct Ue4Matrix {
    float m[4][4];
    float* operator[](int index) { return m[index]; }
};

struct ImVec3 {
    float x, y, z;
    ImVec3() : x(0), y(0), z(0) {}
    ImVec3(float _x, float _y, float _z) : x(_x), y(_y), z(_z) {}
    ImVec3 operator-(const ImVec3& other) const { return ImVec3(x - other.x, y - other.y, z - other.z); }
    static float Dot(const ImVec3& a, const ImVec3& b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
};

struct Ue4Rotator { float pitch, yaw, roll; };
struct MinimalViewInfo { ImVec3 location; Ue4Rotator rotation; float fov; };

Ue4Matrix rotatorToMatrix(Ue4Rotator rotation) {
    float radPitch = rotation.pitch * ((float) M_PI / 180.0f);
    float radYaw = rotation.yaw * ((float) M_PI / 180.0f);
    float radRoll = rotation.roll * ((float) M_PI / 180.0f);
    
    float SP = sinf(radPitch); float CP = cosf(radPitch);
    float SY = sinf(radYaw);   float CY = cosf(radYaw);
    float SR = sinf(radRoll);  float CR = cosf(radRoll);
    
    Ue4Matrix matrix;
    matrix[0][0] = (CP * CY); matrix[0][1] = (CP * SY); matrix[0][2] = (SP); matrix[0][3] = 0;
    matrix[1][0] = (SR * SP * CY - CR * SY); matrix[1][1] = (SR * SP * SY + CR * CY); matrix[1][2] = (-SR * CP); matrix[1][3] = 0;
    matrix[2][0] = (-(CR * SP * CY + SR * SY)); matrix[2][1] = (CY * SR - CR * SP * SY); matrix[2][2] = (CR * CP); matrix[2][3] = 0;
    matrix[3][0] = 0; matrix[3][1] = 0; matrix[3][2] = 0; matrix[3][3] = 1;
    return matrix;
}

ImVec2 worldToScreen(ImVec3 worldLocation, MinimalViewInfo camViewInfo, ImVec2 screenCenter) {
    Ue4Matrix tempMatrix = rotatorToMatrix(camViewInfo.rotation);
    ImVec3 vAxisX(tempMatrix[0][0], tempMatrix[0][1], tempMatrix[0][2]);
    ImVec3 vAxisY(tempMatrix[1][0], tempMatrix[1][1], tempMatrix[1][2]);
    ImVec3 vAxisZ(tempMatrix[2][0], tempMatrix[2][1], tempMatrix[2][2]);
    
    ImVec3 vDelta = worldLocation - camViewInfo.location;
    ImVec3 vTransformed(ImVec3::Dot(vDelta, vAxisY), ImVec3::Dot(vDelta, vAxisZ), ImVec3::Dot(vDelta, vAxisX));
    if (vTransformed.z < 1.0f) vTransformed.z = 1.0f; 
    
    ImVec2 screenCoord;
    float fovCalc = screenCenter.x / tanf(camViewInfo.fov * ((float) M_PI / 360.0f));
    screenCoord.x = (screenCenter.x + vTransformed.x * fovCalc / vTransformed.z);
    screenCoord.y = (screenCenter.y - vTransformed.y * fovCalc / vTransformed.z);
    return screenCoord;
}

// ==========================================
// [ 4. محرك الرادار (ESP Loop - فك التشفير) ]
// ==========================================
void DrawESP(ImDrawList* draw, ImVec2 screenSize) {
    if (!radarBox) return;

    uintptr_t slide = _dyld_get_image_vmaddr_slide(0); 
    typedef uintptr_t (*GWorldFn)(uintptr_t);
    GWorldFn get_gworld = (GWorldFn)(slide + Global::GWorld_Func);
    uintptr_t gWorld = get_gworld(slide + Global::GWorld_Data);
    
    if (!gWorld) {
        draw->AddText(ImVec2(screenSize.x / 2 - 50, 50), IM_COL32(255, 0, 0, 255), "GWorld Not Found!");
        return;
    }

    uintptr_t uLevel = ReadMem<uintptr_t>(gWorld + Offsets::ULevel);
    if (!uLevel) {
        draw->AddText(ImVec2(screenSize.x / 2 - 50, 50), IM_COL32(255, 0, 0, 255), "ULevel Not Found!");
        return;
    }

    uintptr_t actorArray = ReadMem<uintptr_t>(uLevel + Offsets::ActorArray);
    int actorCount = ReadMem<int>(uLevel + Offsets::ActorCount);
    
    char infoText[256];
    sprintf(infoText, "[+] Memory Hooked! Actors Count: %d", actorCount);
    draw->AddText(ImVec2(screenSize.x / 2 - 130, 80), IM_COL32(0, 255, 0, 255), infoText);
    
    draw->AddRect(ImVec2(screenSize.x / 2 - 50, 120), ImVec2(screenSize.x / 2 + 50, 220), IM_COL32(255, 255, 0, 255), 0, 0, 2.0f);
}

// ==========================================
// [ 5. واجهات ImGui ]
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
// [ 6. الطبقة العائمة (بأسلوب Dolphins) ]
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
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.userInteractionEnabled = YES;
        
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

- (void)updateIOWithTouches:(NSSet<UITouch *> *)touches {
    ImGuiIO& io = ImGui::GetIO();
    UITouch *touch = [touches anyObject];
    if (touch) {
        CGPoint loc = [touch locationInView:self]; 
        io.MousePos = ImVec2(loc.x, loc.y);
        if (touch.phase == UITouchPhaseBegan) io.MouseDown[0] = true;
        else if (touch.phase == UITouchPhaseEnded || touch.phase == UITouchPhaseCancelled) io.MouseDown[0] = false;
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouches:touches]; }
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouches:touches]; }
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouches:touches]; }
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event { [self updateIOWithTouches:touches]; }

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self && !showMenu) return nil; 
    return hitView;
}

- (void)toggleMenu { showMenu = !showMenu; }

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
    
    if (radarBox) {
        ImDrawList* draw = ImGui::GetBackgroundDrawList();
        DrawESP(draw, io.DisplaySize);
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
// [ 7. التشغيل الذكي والربط ]
// ==========================================
static void didFinishLaunching(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef info) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *mainWindow = [UIApplication sharedApplication].keyWindow;
        if (!mainWindow) mainWindow = [[UIApplication sharedApplication].windows firstObject];
        
        UIViewController *rootVC = mainWindow.rootViewController;
        if (rootVC && rootVC.view) {
            WessamView *overlay = [[WessamView alloc] initWithFrame:rootVC.view.bounds];
            [rootVC.view addSubview:overlay];
            
            UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:overlay action:@selector(toggleMenu)];
            tap.numberOfTouchesRequired = 3;
            [rootVC.view addGestureRecognizer:tap];
        }
    });
}

__attribute__((constructor)) static void initialize() {
    CFNotificationCenterAddObserver(CFNotificationCenterGetLocalCenter(), NULL, &didFinishLaunching, (CFStringRef)UIApplicationDidFinishLaunchingNotification, NULL, CFNotificationSuspensionBehaviorDrop);
}
