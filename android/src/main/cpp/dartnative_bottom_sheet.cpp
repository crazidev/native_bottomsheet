#include <jni.h>
#include <dlfcn.h>
#include <string>
#include <cstring>

// ─── Cached JVM reference ────────────────────────────────────────────────────
static JavaVM* gJvm = nullptr;

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
    gJvm = vm;
    return JNI_VERSION_1_6;
}

// ─── IsolateGen (from DartNative core) ───────────────────────────────────────
using GenFn = uint64_t (*)();
static GenFn gIsolateGenFn = nullptr;

static uint64_t getIsolateGen() {
    if (!gIsolateGenFn) {
        gIsolateGenFn = (GenFn)dlsym(RTLD_DEFAULT, "DN_IsolateGen");
    }
    return gIsolateGenFn ? gIsolateGenFn() : 0;
}

extern "C" JNIEXPORT jlong JNICALL
Java_com_dartnative_bottom_1sheet_DNBottomSheetBridge_nativeIsolateGen(JNIEnv*, jobject) {
    return (jlong)getIsolateGen();
}

// ─── Deliver event to Dart dispatcher ────────────────────────────────────────
// The dispatcher fn: (token: Int64, type: Int32, payload: *const CChar) -> Void
using DispatchFn = void (*)(int64_t, int32_t, const char*);

extern "C" JNIEXPORT void JNICALL
Java_com_dartnative_bottom_1sheet_DNBottomSheetBridge_nativeDeliver(
    JNIEnv* env, jobject,
    jlong ptr, jlong token, jint type, jstring jpayload)
{
    const char* payload = jpayload ? env->GetStringUTFChars(jpayload, nullptr) : "";
    ((DispatchFn)ptr)((int64_t)token, (int32_t)type, payload);
    if (jpayload) env->ReleaseStringUTFChars(jpayload, payload);
}

// ─── @_cdecl-style FFI entry points called from Dart ─────────────────────────
// These receive JSON as a null-terminated C string and delegate to Kotlin.

static void callKotlin_setDispatcher(JNIEnv* env, jlong ptr);
static void callKotlin_show(JNIEnv* env, const char* json);
static void callKotlin_dismiss(JNIEnv* env, int64_t sheetId, bool animated);
static void callKotlin_snapTo(JNIEnv* env, int64_t sheetId, int32_t idx, bool animated);
static void callKotlin_invalidate(JNIEnv* env, int64_t sheetId);
static void callKotlin_beginAnim(JNIEnv* env, int64_t sheetId);
static void callKotlin_endAnim(JNIEnv* env, int64_t sheetId);
static void callKotlin_mountContent(JNIEnv* env, int64_t sheetId, int64_t viewId);
static void callKotlin_push(JNIEnv* env, int64_t sheetId, int32_t detentIdx);
static void callKotlin_pop(JNIEnv* env, int64_t sheetId);

// Helper: get JNIEnv for current thread
static JNIEnv* getEnv() {
    JNIEnv* env = nullptr;
    if (gJvm) gJvm->AttachCurrentThread(&env, nullptr);
    return env;
}

// Helper: get Kotlin singleton instance
static jobject getBridgeSingleton(JNIEnv* env) {
    jclass cls = env->FindClass("com/dartnative/bottom_sheet/DNBottomSheetBridge");
    if (!cls) return nullptr;
    jfieldID fid = env->GetStaticFieldID(cls, "INSTANCE", "Lcom/dartnative/bottom_sheet/DNBottomSheetBridge;");
    if (!fid) return nullptr;
    return env->GetStaticObjectField(cls, fid);
}

extern "C" void DNBottomSheetSetDispatcher(int64_t ptr) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge) return;
    jclass cls = env->GetObjectClass(bridge);
    jmethodID mid = env->GetMethodID(cls, "setDispatcher", "(J)V");
    if (mid) env->CallVoidMethod(bridge, mid, (jlong)ptr);
}

extern "C" int64_t DNBottomSheetShow(const char* jsonCStr) {
    JNIEnv* env = getEnv();
    if (!env || !jsonCStr) return 0;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge) return 0;
    jclass cls = env->GetObjectClass(bridge);
    jmethodID mid = env->GetMethodID(cls, "show", "(Ljava/lang/String;)J");
    if (!mid) return 0;
    jstring jstr = env->NewStringUTF(jsonCStr);
    jlong rootViewId = env->CallLongMethod(bridge, mid, jstr);
    env->DeleteLocalRef(jstr);
    return (int64_t)rootViewId;
}

extern "C" void DNBottomSheetDismiss(int64_t sheetId, bool animated) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge) return;
    jclass cls = env->GetObjectClass(bridge);
    jmethodID mid = env->GetMethodID(cls, "dismiss", "(JZ)V");
    if (mid) env->CallVoidMethod(bridge, mid, (jlong)sheetId, (jboolean)animated);
}

extern "C" void DNBottomSheetSnapTo(int64_t sheetId, int32_t detentIndex, bool animated) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge) return;
    jclass cls = env->GetObjectClass(bridge);
    jmethodID mid = env->GetMethodID(cls, "snapTo", "(JIZ)V");
    if (mid) env->CallVoidMethod(bridge, mid, (jlong)sheetId, (jint)detentIndex, (jboolean)animated);
}

extern "C" void DNBottomSheetLayoutContent(int64_t sheetId) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge) return;
    jclass cls = env->GetObjectClass(bridge);
    jmethodID mid = env->GetMethodID(cls, "layoutContent", "(J)V");
    if (mid) env->CallVoidMethod(bridge, mid, (jlong)sheetId);
}

extern "C" void DNBottomSheetInvalidateDetents(int64_t sheetId) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge) return;
    jclass cls = env->GetObjectClass(bridge);
    jmethodID mid = env->GetMethodID(cls, "invalidateDetents", "(J)V");
    if (mid) env->CallVoidMethod(bridge, mid, (jlong)sheetId);
}

extern "C" void DNBottomSheetAnimateChangesBegin(int64_t sheetId) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge) return;
    jclass cls = env->GetObjectClass(bridge);
    jmethodID mid = env->GetMethodID(cls, "beginAnimateChanges", "(J)V");
    if (mid) env->CallVoidMethod(bridge, mid, (jlong)sheetId);
}

extern "C" void DNBottomSheetAnimateChangesEnd(int64_t sheetId) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge) return;
    jclass cls = env->GetObjectClass(bridge);
    jmethodID mid = env->GetMethodID(cls, "endAnimateChanges", "(J)V");
    if (mid) env->CallVoidMethod(bridge, mid, (jlong)sheetId);
}

extern "C" void DNBottomSheetMountContent(int64_t sheetId, int64_t viewId) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge) return;
    jclass cls = env->GetObjectClass(bridge);
    jmethodID mid = env->GetMethodID(cls, "mountContent", "(JJ)V");
    if (mid) env->CallVoidMethod(bridge, mid, (jlong)sheetId, (jlong)viewId);
}

extern "C" void DNBottomSheetPush(int64_t sheetId, int32_t expandsToDetentIndex) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge) return;
    jclass cls = env->GetObjectClass(bridge);
    jmethodID mid = env->GetMethodID(cls, "push", "(JI)V");
    if (mid) env->CallVoidMethod(bridge, mid, (jlong)sheetId, (jint)expandsToDetentIndex);
}

extern "C" void DNBottomSheetPop(int64_t sheetId) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge) return;
    jclass cls = env->GetObjectClass(bridge);
    jmethodID mid = env->GetMethodID(cls, "pop", "(J)V");
    if (mid) env->CallVoidMethod(bridge, mid, (jlong)sheetId);
}
