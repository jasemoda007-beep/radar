#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <MetalKit/MetalKit.h>
#import "ImGui/imgui.h"
#import "ImGui/imgui_impl_metal.h"

// ==========================================
// [ 1. الأوفستات الأساسية (تحديث أحمد المضمون) ]
// ==========================================
namespace Global {
    uintptr_t GWorld_Func = 0x102A62208;
    uintptr_t GWorld_Data = 0x10A566E00;
}

namespace Offsets {
    int ULevel = 0x30;
    int ActorArray = 0xA0;
    int ActorCount = 0xA8;
    
    int Ptr1 = 0x38;
    int Ptr2 = 0x78;
    int Ptr3 = 0x30;
    
    int CameraManager = 0x548;
    int CameraPOV = 0x10b0;        // PovOffset(0x10a0) + 0x10
    int SelfActor = 0x28d0;        // SelfOffset
    
    int MoveCoord = 0x110;         // MoveCoordOffset
    int Location = 0x208;          // CoordOffset
    int Mesh = 0x510;              // MeshOffset
    
    int Health = 0xe60;            // HpOffset
    int HealthMax = 0xe64;         // HpMaxOffset
    
    int CurrentWeapon = 0x2a60;    // WeaponOneOffset
    int WeaponAttr = 0x1360;       // WeaponAttrOffset
    int Recoil = 0xcf0;            // RecoilOffset
}

// ==========================================
// [ متغيرات التفعيلات والأزرار ]
// ==========================================
bool showMenu = true; 
bool imguiInitialized = false; 

bool espBox = false; 
bool espLines = false;
bool espHealth = false;
bool noRecoil = false; 
bool aimbot = false; 

// ==========================================
// [ 2. محرك قراءة وكتابة الذاكرة ]
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
    if (address > 0x100000000 && address < 0x2000000000) return *(T*)address;
    return T{};
}

template <typename T>
void WriteMem(uintptr_t address, T value) {
    if (address > 0x100000000 && address < 0x2000000000) *(T*)address = value;
}

// ==========================================
// [ 3. محرك الرياضيات ]
// ==========================================
struct Ue4Matrix { float m[4][4]; float* operator[](int index) { return m[index]; } };
struct ImVec3 {
    float x, y, z;
    ImVec3() : x(0), y(0), z(0) {}
    ImVec3(float _x, float _y, float _z) : x(_x), y(_y), z(_z) {}
    ImVec3 operator-(const ImVec3& other) const { return ImVec3(x - other.x, y - other.y, z - other.z); }
    static float Dot(const ImVec3& a, const ImVec3& b) { return a.x * b.x + a.y * b.y + a.z * b.z; }
};

struct MinimalViewInfo { ImVec3 location; ImVec3 rotation; float fov; };

Ue4Matrix rotatorToMatrix(ImVec3 rotation) {
    float radPitch = rotation.x * ((float) M_PI / 180.0f);
    float radYaw = rotation.y * ((float) M_PI / 180.0f);
    float radRoll = rotation.z * ((float) M_PI / 180.0f);
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
    
    float safeFov = 90.0f; // حماية ضد تشوه الكاميرا
    ImVec2 screenCoord;
    float fovCalc = screenCenter.x / tanf(safeFov * ((float) M_PI / 360.0f));
    screenCoord.x = (screenCenter.x + vTransformed.x * fovCalc / vTransformed.z);
    screenCoord.y = (screenCenter.y - vTransformed.y * fovCalc / vTransformed.z);
    return screenCoord;
}

// ==========================================
// [ 4. محرك الرادار والهاك (مربوط بالأزرار 100%) ]
// ==========================================
void DrawESP(ImDrawList* draw, ImVec2 screenSize) {
    uintptr_t slide = _dyld_get_image_vmaddr_slide(0); 
    typedef uintptr_t (*GWorldFn)(uintptr_t);
    GWorldFn get_gworld = (GWorldFn)(slide + Global::GWorld_Func);
    uintptr_t gWorld = get_gworld(slide + Global::GWorld_Data);
    if (!gWorld) return;

    uintptr_t ptr1 = ReadMem<uintptr_t>(gWorld + Offsets::Ptr1);
    uintptr_t ptr2 = ReadMem<uintptr_t>(ptr1 + Offsets::Ptr2);
    uintptr_t playerController = ReadMem<uintptr_t>(ptr2 + Offsets::Ptr3);
    uintptr_t cameraManager = ReadMem<uintptr_t>(playerController + Offsets::CameraManager);
    uintptr_t selfActor = ReadMem<uintptr_t>(playerController + Offsets::SelfActor);

    // 🔥 تفعيل زر ثبات السلاح (مربوط شغال) 🔥
    if (noRecoil && selfActor) {
        uintptr_t currentWeapon = ReadMem<uintptr_t>(selfActor + Offsets::CurrentWeapon);
        if (currentWeapon) {
            uintptr_t weaponAttr = ReadMem<uintptr_t>(currentWeapon + Offsets::WeaponAttr);
            if (weaponAttr) WriteMem<float>(weaponAttr + Offsets::Recoil, 0.0f);
        }
    }

    // إذا ما مفعل ولا زر بالرادار، اطلع بدون ما تتعب المعالج
    if (!espBox && !espLines && !espHealth) return;

    uintptr_t uLevel = ReadMem<uintptr_t>(gWorld + Offsets::ULevel);
    if (!uLevel) return;

    MinimalViewInfo pov;
    pov.location = ReadMem<ImVec3>(cameraManager + Offsets::CameraPOV + 0x0);
    pov.rotation = ReadMem<ImVec3>(cameraManager + Offsets::CameraPOV + 0xC); 
    pov.fov = 90.0f; 

    uintptr_t actorArray = ReadMem<uintptr_t>(uLevel + Offsets::ActorArray);
    int actorCount = ReadMem<int>(uLevel + Offsets::ActorCount);
    if (actorCount < 1 || actorCount > 5000) return;
    
    ImVec2 screenCenter = ImVec2(screenSize.x / 2, screenSize.y / 2);

    // حلقة قراءة الأعداء
    for (int i = 0; i < actorCount; i++) {
        uintptr_t actor = ReadMem<uintptr_t>(actorArray + (i * 8));
        if (!actor || actor == selfActor) continue; 

        // فلتر الأعداء الحقيقيين فقط (يجب أن يكون لديه مجسم ودم طبيعي)
        uintptr_t mesh = ReadMem<uintptr_t>(actor + Offsets::Mesh);
        if (!mesh) continue; 

        float hp = ReadMem<float>(actor + Offsets::Health);
        if (hp <= 0.0f || hp > 150.0f) continue; // تخطي الموتى والمجسمات الغريبة

        // قراءة الموقع حسب مسار أحمد: MoveCoord -> Location
        uintptr_t moveCoord = ReadMem<uintptr_t>(actor + Offsets::MoveCoord);
        if (!moveCoord) continue;
        ImVec3 actorLocation = ReadMem<ImVec3>(moveCoord + Offsets::Location);
        
        if (actorLocation.x == 0 && actorLocation.y == 0) continue;
        if (actorLocation.x > 2000000 || actorLocation.x < -2000000) continue; 
        
        ImVec2 screenPos = worldToScreen(actorLocation, pov, screenCenter);

        // إذا كان العدو داخل الشاشة
        if (screenPos.x > -100 && screenPos.y > -100 && screenPos.x < screenSize.x + 100) {
            float distance = sqrt(pow(pov.location.x - actorLocation.x, 2) + pow(pov.location.y - actorLocation.y, 2)) / 100.0f;
            if (distance < 1.0f || distance > 800.0f) continue;
            
            float boxWidth = 800.0f / distance;
            float boxHeight = 1600.0f / distance;
            
            // 🔥 تفاعل الأزرار بالرسم 🔥
            if (espBox) {
                draw->AddRect(ImVec2(screenPos.x - (boxWidth / 2), screenPos.y - boxHeight), 
                              ImVec2(screenPos.x + (boxWidth / 2), screenPos.y), 
                              IM_COL32(255, 0, 0, 255), 0, 0, 1.5f);
            }
            if (espLines) {
                draw->AddLine(ImVec2(screenCenter.x, 80), 
                              ImVec2(screenPos.x, screenPos.y - boxHeight), 
                              IM_COL32(255, 255, 255, 200), 1.0f);
            }
            if (espHealth) {
                float hpMax = ReadMem<float>(actor + Offsets::HealthMax);
                if (hpMax <= 0.0f) hpMax = 100.0f;
                float hpPercent = hp / hpMax;
                
                draw->AddRectFilled(ImVec2(screenPos.x - (boxWidth / 2) - 6, screenPos.y - boxHeight), 
                                    ImVec2(screenPos.x - (boxWidth / 2) - 2, screenPos.y), 
                                    IM_COL32(0, 0, 0, 150));
                draw->AddRectFilled(ImVec2(screenPos.x - (boxWidth / 2) - 6, screenPos.y - (boxHeight * hpPercent)), 
                                    ImVec2(screenPos.x - (boxWidth / 2) - 2, screenPos.y), 
                                    IM_COL32(0, 255, 0, 255));
            }
        }
    }
}

// ==========================================
// [ 5. دالة تصميم الأزرار الفخمة (ON/OFF) ]
// ==========================================
static void DrawClassicToggle(const char* name, bool* value) {
    ImGui::Text("%s", name);
    ImGui::NextColumn();
    
    ImGui::PushID(name);
    if (*value) {
        ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.2f, 1.0f, 0.2f, 1.0f)); // لون أخضر
        if (ImGui::Selectable("ON", false)) *value = false;
        ImGui::PopStyleColor();
    } else {
        ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(1.0f, 0.2f, 0.2f, 1.0f)); // لون أحمر
        if (ImGui::Selectable("OFF", false)) *value = true;
        ImGui::PopStyleColor();
    }
    ImGui::PopID();
    
    ImGui::NextColumn();
}

// ==========================================
// [ 6. واجهة ImGui (المنيو الكلاسيكي) ]
// ==========================================
void ShowUI() {
    ImGui::SetNextWindowSize(ImVec2(400, 320), ImGuiCond_FirstUseEver);
    ImGui::PushStyleColor(ImGuiCol_WindowBg, ImVec4(0.05f, 0.05f, 0.05f, 0.85f)); 
    ImGui::PushStyleColor(ImGuiCol_Border, ImVec4(0.0f, 0.0f, 0.0f, 0.0f)); 
    
    ImGui::Begin("WessamVIP", &showMenu, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoCollapse);
    
    ImGui::Spacing(); ImGui::Spacing();
    
    ImGui::Columns(2, "opts", false);
    ImGui::SetColumnWidth(0, 280.0f); // التحكم بعرض الاسم والزر
    
    // رسم الأزرار الحقيقية المربوطة 100%
    DrawClassicToggle("ESP Boxes (مربعات)", &espBox);
    DrawClassicToggle("ESP Lines (خطوط)", &espLines);
    DrawClassicToggle("ESP Health (شريط الدم)", &espHealth);
    DrawClassicToggle("No Recoil (ثبات سلاح)", &noRecoil);
    DrawClassicToggle("Magic Bullet (قريباً)", &aimbot);
    
    ImGui::Columns(1);
    
    ImGui::Spacing(); ImGui::Spacing(); ImGui::Spacing();
    
    ImGui::PushStyleColor(ImGuiCol_Text, ImVec4(0.8f, 0.8f, 0.8f, 1.0f));
    if (ImGui::Selectable("[x] Close Menu")) showMenu = false;
    ImGui::PopStyleColor();
    
    ImGui::End();
    ImGui::PopStyleColor(2); 
}

// ==========================================
// [ 7. الطبقة العائمة والتشغيل ]
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
        io.FontGlobalScale = 2.2f; 
        ImGui::GetStyle().ScaleAllSizes(2.2f);
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
    ImGuiIO& io = ImGui::GetIO();
    io.DisplaySize = ImVec2(view.bounds.size.width, view.bounds.size.height);
    MTLRenderPassDescriptor *desc = view.currentRenderPassDescriptor;
    if (!desc) return;
    id<MTLCommandBuffer> buffer = [self.commandQueue commandBuffer];
    ImGui_ImplMetal_NewFrame(desc);
    ImGui::NewFrame();

    if (showMenu) ShowUI();
    
    // رسم الرادار
    ImDrawList* draw = ImGui::GetBackgroundDrawList();
    DrawESP(draw, io.DisplaySize);

    ImGui::Render();
    id<MTLRenderCommandEncoder> encoder = [buffer renderCommandEncoderWithDescriptor:desc];
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), buffer, encoder);
    [encoder endEncoding];
    [buffer presentDrawable:view.currentDrawable];
    [buffer commit];
}
@end

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
