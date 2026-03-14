 #include <iostream> 
#include <string>
#include <thread>
#include <chrono>
#include <vector>

// المكتبات المطلوبة للـ Dylib (يجب توفرها في بيئة البناء)
#include "imgui.h"
#include "dobby.h"
#include "curl/curl.h"
#include "json.hpp" // nlohmann/json
using json = nlohmann::json;
using namespace std;

// ==========================================
// 1. المتغيرات العامة (الآيبي واللوحة)
// ==========================================
const string SERVER_URL = "http://34.204.178.160/panel.php?api=check&key=";

bool g_MenuOpen = true;
bool g_IsLoggedIn = false;
bool g_IsConnected = false;
bool g_ShowSuccessMsg = false;
char g_LicenseKey[64] = "SHAMMARI-VIP-2026"; // 16 حرف

bool g_ServerFrozen = false;
string g_FreezeMessage = "";
string g_SubStartDate = "14/03/2026";
string g_SubEndDate = "14/04/2026";
string g_SubType = "VIP 💎";

// ==========================================
// 2. إعدادات المنيو (التفعيلات)
// ==========================================
bool g_AngosBypass = true;
bool g_ESP_Players = true;
bool g_ESP_Box = true;
bool g_ESP_Health = true;
bool g_ESP_Skeleton = true;
bool g_ESP_Name = true;
bool g_ESP_Vehicles = false; // السيارات
bool g_ESP_Loot = false;     // الموارد والأسلحة

// ==========================================
// 3. أوفستات الرادار (Unreal Engine Offsets)
// ==========================================
// [تحديث]: هذه الأوفستات تتحدث من السيرفر أو تدوياً هنا
uintptr_t OFFSET_GWORLD    = 0x11223344; // خريطة العالم
uintptr_t OFFSET_GNAMES    = 0x55667788; // الأسماء
uintptr_t OFFSET_GOBJECTS  = 0x99AABBCC; // الكائنات (الأشياء)

// أوفستات داخلية (Offsets inside classes) - تتحدث من هنا
uintptr_t OFF_GAME_INSTANCE = 0x180; // OwningGameInstance
uintptr_t OFF_LOCAL_PLAYERS = 0x38;  // LocalPlayers
uintptr_t OFF_PLAYER_CONTROLLER = 0x30; // PlayerController
uintptr_t OFF_PLAYER_CAMERA = 0x340; // PlayerCameraManager
uintptr_t OFF_ULEVEL = 0x30; // ULevel
uintptr_t OFF_AACTORS = 0xA0; // Actors Array

// ==========================================
// 4. هوكات الحماية (Security Hooks)
// ==========================================
// [تحديث]: هذه الأوفستات لدوال الحماية في ملف اللعبة (أو angos)
uintptr_t OFFSET_SEND_REPORT = 0x1A2B3C; // دالة إرسال تقرير الباند
uintptr_t OFFSET_MEMORY_CHECK = 0x4D5E6F; // دالة فحص الذاكرة

// 1. هوك تعطيل الإبلاغات (Anti-Report)
static void* (*Original_SendReport)(void* url, void* data);
void* Replacement_SendReport(void* url, void* data) {
    if (g_AngosBypass && g_IsConnected) {
        return nullptr; // 🔴 تعطيل إرسال التقرير (آمن)
    }
    return Original_SendReport(url, data); // تشغيل طبيعي
}

// 2. هوك تعطيل فحص الذاكرة (Memory Bypass)
static int (*Original_MemoryCheck)();
int Replacement_MemoryCheck() {
    if (g_AngosBypass && g_IsConnected) {
        return 1; // 1 = آمن ولا يوجد تعديل
    }
    return Original_MemoryCheck();
}

// دالة تثبيت الهوكات (تعمل في بداية التشغيل)
void InstallSecurityHooks() {
    // uintptr_t base_addr = _dyld_get_image_vmaddr_slide(0);
    // DobbyHook((void*)(base_addr + OFFSET_SEND_REPORT), (void*)Replacement_SendReport, (void**)&Original_SendReport);
    // DobbyHook((void*)(base_addr + OFFSET_MEMORY_CHECK), (void*)Replacement_MemoryCheck, (void**)&Original_MemoryCheck);
}

// ==========================================
// 5. محرك رسم الرادار (Full ESP Engine)
// ==========================================

// دالة (وهمية للتوضيح) لتحويل إحداثيات اللعبة 3D إلى شاشة 2D
bool WorldToScreen(ImVec3 worldPos, ImVec2* screenPos) {
    // كود مصفوفة الكاميرا يوضع هنا
    return true; 
}

// أ. رسم اللاعبين (الدم، البوكس، الهيكل، الاسم)
void DrawPlayerESP(ImDrawList* draw, ImVec2 head, ImVec2 foot, float hp, string name, float dist) {
    float height = foot.y - head.y;
    float width = height / 2.0f;
    ImVec2 top_left = ImVec2(head.x - width / 2, head.y);
    ImVec2 bottom_right = ImVec2(head.x + width / 2, foot.y);

    if (g_ESP_Box) {
        draw->AddRect(top_left, bottom_right, IM_COL32(0, 0, 0, 255), 0, 0, 2.5f); // ظل
        draw->AddRect(top_left, bottom_right, IM_COL32(0, 229, 255, 255), 0, 0, 1.5f); // سيان
    }

    if (g_ESP_Health) {
        float hp_h = height * (hp / 100.0f);
        ImU32 col = (hp > 60) ? IM_COL32(0,255,0,255) : ((hp > 25) ? IM_COL32(255,255,0,255) : IM_COL32(255,0,0,255));
        draw->AddRectFilled(ImVec2(top_left.x - 6, top_left.y), ImVec2(top_left.x - 3, bottom_right.y), IM_COL32(0,0,0,150));
        draw->AddRectFilled(ImVec2(top_left.x - 6, bottom_right.y - hp_h), ImVec2(top_left.x - 3, bottom_right.y), col);
    }

    if (g_ESP_Name) {
        string t = name + " [" + to_string((int)dist) + "m]";
        ImVec2 ts = ImGui::CalcTextSize(t.c_str());
        ImVec2 tp = ImVec2(head.x - (ts.x / 2), head.y - 15);
        draw->AddText(ImVec2(tp.x+1, tp.y+1), IM_COL32(0,0,0,255), t.c_str());
        draw->AddText(tp, IM_COL32(255,255,255,255), t.c_str());
    }

    if (g_ESP_Skeleton) {
        // [تحديث العظام من هنا]: استخراج Bone Matrix
        // رسم الرقبة، الصدر، الأكتاف، الأيدي، الأقدام.
        // draw->AddLine(NeckPos, ChestPos, IM_COL32(255, 255, 255, 255), 1.0f);
    }
}

// ب. رسم السيارات (Vehicles)
void DrawVehicleESP(ImDrawList* draw, ImVec2 pos, string vehName, float dist) {
    if (!g_ESP_Vehicles) return;
    string t = "🚗 " + vehName + " [" + to_string((int)dist) + "m]";
    ImVec2 tp = ImVec2(pos.x - (ImGui::CalcTextSize(t.c_str()).x / 2), pos.y);
    draw->AddText(ImVec2(tp.x+1, tp.y+1), IM_COL32(0,0,0,255), t.c_str());
    draw->AddText(tp, IM_COL32(255, 165, 0, 255), t.c_str()); // برتقالي للسيارات
}

// ج. رسم الموارد والأسلحة (Loot & Weapons)
void DrawLootESP(ImDrawList* draw, ImVec2 pos, string itemName, float dist) {
    if (!g_ESP_Loot) return;
    string t = "🔫 " + itemName + " [" + to_string((int)dist) + "m]";
    ImVec2 tp = ImVec2(pos.x - (ImGui::CalcTextSize(t.c_str()).x / 2), pos.y);
    draw->AddText(ImVec2(tp.x+1, tp.y+1), IM_COL32(0,0,0,255), t.c_str());
    draw->AddText(tp, IM_COL32(255, 255, 0, 255), t.c_str()); // أصفر للموارد
}

// الدالة الرئيسية لرسم كل الـ ESP
void RenderESP() {
    ImDrawList* draw_list = ImGui::GetBackgroundDrawList();

    // 1. [جلب GWorld]
    // uintptr_t uWorld = *(uintptr_t*)(base_addr + g_GWorldOffset);
    // if (!uWorld) return;
    
    // 2. [جلب المصفوفة AActor]
    // Loop over actors...
    // if (actor is Player) -> DrawPlayerESP(...)
    // if (actor is Vehicle) -> DrawVehicleESP(...)
    // if (actor is Weapon/Loot) -> DrawLootESP(...)

    // -- (رسم وهمي للمحاكاة) --
    if (g_ESP_Players) {
        ImVec2 c = ImVec2(ImGui::GetIO().DisplaySize.x/2, ImGui::GetIO().DisplaySize.y/2);
        DrawPlayerESP(draw_list, ImVec2(c.x+100, c.y-100), ImVec2(c.x+100, c.y+50), 75, "Enemy_1", 120);
    }
    if (g_ESP_Vehicles) DrawVehicleESP(draw_list, ImVec2(200, 300), "Dacia", 150);
    if (g_ESP_Loot) DrawLootESP(draw_list, ImVec2(300, 400), "M416", 50);
}

// ==========================================
// 6. الاتصال باللوحة (API)
// ==========================================
static size_t WriteCallback(void *c, size_t s, size_t n, void *u) { ((string*)u)->append((char*)c, s*n); return s*n; }
void ForceRefreshConnection() { g_IsConnected = false; }

void ServerThread() {
    CURL *curl; CURLcode res;
    while(true) {
        if(g_IsLoggedIn && string(g_LicenseKey).length() >= 10) {
            curl = curl_easy_init();
            if(curl) {
                string url = SERVER_URL + string(g_LicenseKey);
                string readBuffer;
                curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
                curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
                curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);
                res = curl_easy_perform(curl);
                if(res == CURLE_OK) {
                    try {
                        auto response = json::parse(readBuffer);
                        if (response["server_state"] == "danger") {
                            g_ServerFrozen = true; g_IsConnected = false;
                        } else if (response["status"] == "success") {
                            g_ServerFrozen = false; g_IsConnected = true;
                            // تحديث أوفستات GWorld و Angos من السيرفر
                        } else { g_IsConnected = false; }
                    } catch (...) { g_IsConnected = false; }
                } else { g_IsConnected = false; }
                curl_easy_cleanup(curl);
            }
        }
        this_thread::sleep_for(chrono::seconds(5)); 
    }
}

// ==========================================
// 7. واجهة ImGui (VIP Theme)
// ==========================================
void ToggleButton(const char* str_id, bool* v) {
    ImVec2 p = ImGui::GetCursorScreenPos(); ImDrawList* dl = ImGui::GetWindowDrawList();
    float h = ImGui::GetFrameHeight(), w = h * 1.55f, r = h * 0.5f;
    ImGui::InvisibleButton(str_id, ImVec2(w, h));
    if (ImGui::IsItemClicked()) *v = !*v;
    float t = *v ? 1.0f : 0.0f;
    ImU32 bg = *v ? IM_COL32(0, 229, 255, 255) : IM_COL32(50, 54, 61, 255);
    dl->AddRectFilled(p, ImVec2(p.x + w, p.y + h), bg, h * 0.5f);
    dl->AddCircleFilled(ImVec2(p.x + r + t * (w - r * 2.0f), p.y + r), r - 1.5f, IM_COL32(255, 255, 255, 255));
    ImGui::SameLine(); ImGui::Text("%s", str_id); 
}

void ApplyWMASTERTheme() {
    ImGuiStyle& s = ImGui::GetStyle(); ImVec4* c = s.Colors;
    c[ImGuiCol_WindowBg] = ImVec4(0.05f, 0.07f, 0.09f, 0.95f);
    c[ImGuiCol_TitleBg] = ImVec4(0.09f, 0.11f, 0.14f, 1.0f);
    c[ImGuiCol_Border] = ImVec4(0.00f, 0.90f, 1.00f, 0.30f);
    s.WindowRounding = 12.0f;
}

void RenderWMASTER_UI() {
    ApplyWMASTERTheme();

    if (g_ServerFrozen) {
        ImGui::SetNextWindowPos(ImVec2(0,0)); ImGui::SetNextWindowSize(ImGui::GetIO().DisplaySize);
        ImGui::Begin("Frozen", nullptr, ImGuiWindowFlags_NoDecoration|ImGuiWindowFlags_NoInputs|ImGuiWindowFlags_NoBackground);
        ImGui::GetWindowDrawList()->AddRectFilled(ImVec2(0,0), ImGui::GetIO().DisplaySize, IM_COL32(0,0,0,255));
        ImGui::SetCursorPos(ImVec2(ImGui::GetWindowSize().x/2 - 100, ImGui::GetWindowSize().y/2));
        ImGui::TextColored(ImVec4(1,0,0,1), "النظام تحت الصيانة - الشمري");
        ImGui::End(); return; 
    }

    // الشريط العلوي الثابت
    ImGui::SetNextWindowPos(ImVec2(0,0)); ImGui::SetNextWindowSize(ImVec2(ImGui::GetIO().DisplaySize.x, 35));
    ImGui::Begin("TopBar", nullptr, ImGuiWindowFlags_NoDecoration|ImGuiWindowFlags_NoBackground|ImGuiWindowFlags_NoMove);
    if (ImGui::InvisibleButton("TopBarBtn", ImVec2(ImGui::GetIO().DisplaySize.x, 35))) ForceRefreshConnection();
    ImGui::SetCursorPos(ImVec2(15, 10));
    if (g_IsConnected) {
        ImGui::GetWindowDrawList()->AddCircleFilled(ImVec2(20, 18), 5.0f, IM_COL32(0, 255, 102, 255));
        ImGui::SetCursorPos(ImVec2(35, 10)); ImGui::TextColored(ImVec4(0,1,0.4f,1), "Live (متصل: 34.204.178.160)");
    } else {
        ImGui::GetWindowDrawList()->AddCircleFilled(ImVec2(20, 18), 5.0f, IM_COL32(255, 51, 102, 255));
        ImGui::SetCursorPos(ImVec2(35, 10)); ImGui::TextColored(ImVec4(1,0.2f,0.4f,1), "No Sturte");
    }
    ImGui::SetCursorPos(ImVec2(ImGui::GetIO().DisplaySize.x/2 - 60, 10)); ImGui::TextColored(ImVec4(0.5f,0.5f,0.5f,1), "W-MASTER V3");
    ImGui::End();

    // رسم الرادار إذا متصل
    if (g_IsConnected) RenderESP();

    // المنيو
    if (!g_MenuOpen) return;

    ImGui::SetNextWindowSize(ImVec2(360, 550), ImGuiCond_FirstUseEver);
    ImGui::Begin(u8"🦅 حماية محمد الشمري", &g_MenuOpen, ImGuiWindowFlags_NoCollapse);

    if (!g_IsLoggedIn) {
        ImGui::TextColored(ImVec4(0.5f,0.5f,0.5f,1), u8"أدخل الكود (16 رقم وحرف):");
        ImGui::InputText("##key", g_LicenseKey, IM_ARRAYSIZE(g_LicenseKey), ImGuiInputTextFlags_CharsUppercase);
        ImGui::Spacing();
        if (ImGui::Button(u8"تسجيل الدخول", ImVec2(-1, 40))) {
            g_ShowSuccessMsg = true;
            thread([&](){ this_thread::sleep_for(chrono::seconds(1)); g_ShowSuccessMsg=false; g_IsLoggedIn=true; g_IsConnected=true; }).detach();
        }
        if (g_ShowSuccessMsg) ImGui::TextColored(ImVec4(0,1,0,1), u8"✅ تم التفعيل بنجاح!");
    } else {
        ImGui::BeginChild("SubBox", ImVec2(0, 90), true);
        ImGui::TextColored(ImVec4(0,0.9f,1,1), u8"أهلاً بك: محمد الشمري (VIP)");
        ImGui::Text(u8"النوع: %s | الحالة: نشط 🟢", g_SubType.c_str());
        ImGui::Text(u8"الانتهاء: %s", g_SubEndDate.c_str());
        ImGui::EndChild();
        
        ImGui::TextColored(ImVec4(1,1,0,1), u8"[ السيرفر والحماية ]");
        ToggleButton(u8"🛡️ تخطي الحماية (Angos Bypass & Hooks)", &g_AngosBypass);
        ImGui::Separator();
        
        ImGui::TextColored(ImVec4(1,1,0,1), u8"[ إعدادات الرادار - ESP ]");
        ToggleButton(u8"👁️ تفعيل رادار اللاعبين (Players)", &g_ESP_Players);
        if (g_ESP_Players) {
            ImGui::Indent();
            ToggleButton(u8"🔲 صندوق اللاعب (Box)", &g_ESP_Box);
            ToggleButton(u8"❤️ شريط الدم (Health Bar)", &g_ESP_Health);
            ToggleButton(u8"☠️ الهيكل العظمي (Skeleton)", &g_ESP_Skeleton);
            ToggleButton(u8"🏷️ الاسم والمسافة (Name/Dist)", &g_ESP_Name);
            ImGui::Unindent();
        }
        ImGui::Spacing();
        ToggleButton(u8"🚗 رادار السيارات (Vehicles)", &g_ESP_Vehicles);
        ToggleButton(u8"🔫 رادار الأسلحة والموارد (Loot)", &g_ESP_Loot);

        ImGui::Spacing();
        ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0,0.5f,0.8f,0.3f));
        if (ImGui::Button(u8"✈️ المطور: محمد الشمري (اضغط للتليكرام)", ImVec2(-1, 35))) {
            // كود فتح التليكرام هنا
        }
        ImGui::PopStyleColor();
    }
    ImGui::End();
}

// ==========================================
// 8. نقطة الإقلاع (Main Init)
// ==========================================
__attribute__((constructor))
void InitWMASTER() {
    InstallSecurityHooks(); // زرع هوكات الحماية أولاً
    thread server_monitor(ServerThread); // تشغيل الاتصال
    server_monitor.detach();
}
