#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach/mach.h>
#import <substrate.h>
#import "ImGui/imgui.h"

// --- [ إعدادات السيرفر ] ---
#define API_URL @"http://34.204.178.160/manager/api.php"
#define JSON_URL @"http://34.204.178.160/manager/offsets.json"

// --- [ المتغيرات العالمية ] ---
bool isAuthorized = false;
NSString *expiryDate = @"بانتظار الدخول...";
NSArray *onlineFeatures = nil;

// --- [ 1. محرك البحث عن الملفات والتعطيل (Patch Engine) ] ---

uintptr_t get_module_base(const char *moduleName) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        if (strstr(_dyld_get_image_name(i), moduleName)) {
            return (uintptr_t)_dyld_get_image_header(i);
        }
    }
    return 0;
}

void apply_patch(uintptr_t address, NSString *hexString) {
    if (!address || !hexString) return;
    
    // تحويل النص إلى بايتات
    hexString = [hexString stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableData *data = [NSMutableData data];
    for (int i = 0; i < [hexString length]; i += 2) {
        unsigned int byte;
        [[NSScanner scannerWithString:[hexString substringWithRange:NSMakeRange(i, 2)]] scanHexInt:&byte];
        [data appendBytes:&byte length:1];
    }

    vm_protect(mach_task_self(), (vm_address_t)address, data.length, FALSE, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
    memcpy((void *)address, data.bytes, data.length);
    vm_protect(mach_task_self(), (vm_address_t)address, data.length, FALSE, VM_PROT_READ | VM_PROT_EXECUTE);
    
    NSLog(@"[WESSAM] Applied Patch to: 0x%lx", (unsigned long)address);
}

// --- [ 2. جلب البيانات من السيرفر ] ---

void fetchOnlineOffsets() {
    NSURL *url = [NSURL URLWithString:JSON_URL];
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (data) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        onlineFeatures = json[@"features"];
        NSLog(@"[WESSAM] Loaded %lu Features From Server", (unsigned long)[onlineFeatures count]);
    }
}

void checkLicense(NSString *userKey) {
    NSString *udid = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    NSString *devName = [[UIDevice currentDevice] name];
    
    NSString *fullUrl = [NSString stringWithFormat:@"%@?key=%@&hwid=%@&name=%@", API_URL, userKey, udid, [devName stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    
    NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:fullUrl]];
    if (data) {
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([json[@"status"] isEqualToString:@"success"]) {
            isAuthorized = true;
            expiryDate = json[@"expiry"];
            fetchOnlineOffsets(); // جلب الأوفستات فور نجاح الدخول
        }
    }
}

// --- [ 3. واجهة المستخدم ImGui ] ---

void DrawMainUI() {
    ImGui::Begin("WESSAM CYBER MOD v7.0");

    if (!isAuthorized) {
        static char keyBuffer[32] = "";
        ImGui::Text("Enter License Key:");
        ImGui::InputText("##key", keyBuffer, 32);
        
        if (ImGui::Button("Login & Activate", ImVec2(-1, 0))) {
            checkLicense([NSString stringWithUTF8String:keyBuffer]);
        }
    } else {
        ImGui::TextColored(ImVec4(0, 1, 0, 1), "Status: ACTIVE");
        ImGui::Text("Expiry: %s", [expiryDate UTF8String]);
        ImGui::Separator();

        // عرض التفعيلات التي سحبناها من ملف JSON تلقائياً
        for (NSDictionary *feat in onlineFeatures) {
            bool temp = false; 
            if (ImGui::Button([feat[@"name"] UTF8String], ImVec2(-1, 0))) {
                uintptr_t base = get_module_base([feat[@"module"] UTF8String]);
                if (base > 0) {
                    unsigned long long offset;
                    [[NSScanner scannerWithString:feat[@"offset"]] scanHexLongLong:&offset];
                    apply_patch(base + (uintptr_t)offset, feat[@"byte"]);
                }
            }
        }
    }
    ImGui::End();
}

// --- [ 4. الحقن والتشغيل ] ---

%hook MTLCommandBuffer
- (void)presentDrawable:(id)drawable {
    DrawMainUI(); // رسم القائمة فوق اللعبة
    %orig;
}
%end

__attribute__((constructor))
static void initialize() {
    NSLog(@"[WESSAM] Mod Injection Successful!");
}
