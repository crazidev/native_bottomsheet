#include <jni.h>
#include <dlfcn.h>
#include <string>
#include <cstring>
#include <android/log.h>

#define TAG "DNBottomSheetNative"
#define LOGD(...) __android_log_print(ANDROID_LOG_DEBUG, TAG, __VA_ARGS__)
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO,  TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, TAG, __VA_ARGS__)

// ─── Cached JVM and Bridge references ─────────────────────────────────────────
static JavaVM* gJvm = nullptr;
static jclass gBridgeClass = nullptr;
static jobject gBridgeInstance = nullptr;

// Cached method IDs
static jmethodID mid_setDispatcher       = nullptr;
static jmethodID mid_show                = nullptr;
static jmethodID mid_dismiss             = nullptr;
static jmethodID mid_snapTo              = nullptr;
static jmethodID mid_layoutContent       = nullptr;
static jmethodID mid_invalidateDetents   = nullptr;
static jmethodID mid_beginAnimateChanges = nullptr;
static jmethodID mid_endAnimateChanges   = nullptr;
static jmethodID mid_mountContent        = nullptr;
static jmethodID mid_push                = nullptr;
static jmethodID mid_pop                 = nullptr;

static void resolveMethods(JNIEnv* env, jclass cls) {
    if (!cls) return;
    mid_setDispatcher       = env->GetMethodID(cls, "setDispatcher", "(J)V");
    mid_show                = env->GetMethodID(cls, "show", "(Ljava/lang/String;)J");
    mid_dismiss             = env->GetMethodID(cls, "dismiss", "(JZ)V");
    mid_snapTo              = env->GetMethodID(cls, "snapTo", "(JIZ)V");
    mid_layoutContent       = env->GetMethodID(cls, "layoutContent", "(J)V");
    mid_invalidateDetents   = env->GetMethodID(cls, "invalidateDetents", "(J)V");
    mid_beginAnimateChanges = env->GetMethodID(cls, "beginAnimateChanges", "(J)V");
    mid_endAnimateChanges   = env->GetMethodID(cls, "endAnimateChanges", "(J)V");
    mid_mountContent        = env->GetMethodID(cls, "mountContent", "(JJ)V");
    mid_push                = env->GetMethodID(cls, "push", "(JI)V");
    mid_pop                 = env->GetMethodID(cls, "pop", "(J)V");

    if (env->ExceptionCheck()) {
        env->ExceptionClear();
    }
}

static void initBridgeFromClass(JNIEnv* env, jclass localCls) {
    if (!localCls) return;
    if (gBridgeClass) {
        env->DeleteGlobalRef(gBridgeClass);
        gBridgeClass = nullptr;
    }
    gBridgeClass = (jclass)env->NewGlobalRef(localCls);

    jfieldID fid = env->GetStaticFieldID(gBridgeClass, "INSTANCE", "Lcom/dartnative/bottom_sheet/DNBottomSheetBridge;");
    if (fid) {
        jobject localInst = env->GetStaticObjectField(gBridgeClass, fid);
        if (localInst) {
            if (gBridgeInstance) {
                env->DeleteGlobalRef(gBridgeInstance);
                gBridgeInstance = nullptr;
            }
            gBridgeInstance = env->NewGlobalRef(localInst);
            env->DeleteLocalRef(localInst);
        }
    }
    resolveMethods(env, gBridgeClass);
    if (env->ExceptionCheck()) {
        env->ExceptionClear();
    }
}

extern "C" JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void*) {
    gJvm = vm;
    JNIEnv* env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) == JNI_OK) {
        jclass localCls = env->FindClass("com/dartnative/bottom_sheet/DNBottomSheetBridge");
        if (localCls) {
            initBridgeFromClass(env, localCls);
            env->DeleteLocalRef(localCls);
            LOGI("JNI_OnLoad: DNBottomSheetBridge successfully resolved and cached");
        } else {
            LOGE("JNI_OnLoad: could not find DNBottomSheetBridge class");
            if (env->ExceptionCheck()) {
                env->ExceptionClear();
            }
        }
    }
    return JNI_VERSION_1_6;
}

extern "C" JNIEXPORT void JNICALL
Java_com_dartnative_bottom_1sheet_DNBottomSheetBridge_nativeInit(
    JNIEnv* env, jobject, jobject bridge)
{
    if (!bridge) return;
    if (gBridgeInstance) {
        env->DeleteGlobalRef(gBridgeInstance);
        gBridgeInstance = nullptr;
    }
    gBridgeInstance = env->NewGlobalRef(bridge);

    jclass localCls = env->GetObjectClass(bridge);
    if (localCls) {
        if (gBridgeClass) {
            env->DeleteGlobalRef(gBridgeClass);
            gBridgeClass = nullptr;
        }
        gBridgeClass = (jclass)env->NewGlobalRef(localCls);
        resolveMethods(env, gBridgeClass);
        env->DeleteLocalRef(localCls);
    }
    LOGI("nativeInit: bridge instance registered from Kotlin");
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

extern "C" JNIEXPORT jlong JNICALL
Java_com_dartnative_bottom_1sheet_DNBottomSheetBridgeKt_nativeIsolateGen(JNIEnv*, jclass) {
    return (jlong)getIsolateGen();
}

// ─── Deliver event to Dart dispatcher ────────────────────────────────────────
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

extern "C" JNIEXPORT void JNICALL
Java_com_dartnative_bottom_1sheet_DNBottomSheetBridgeKt_nativeDeliver(
    JNIEnv* env, jclass,
    jlong ptr, jlong token, jint type, jstring jpayload)
{
    const char* payload = jpayload ? env->GetStringUTFChars(jpayload, nullptr) : "";
    ((DispatchFn)ptr)((int64_t)token, (int32_t)type, payload);
    if (jpayload) env->ReleaseStringUTFChars(jpayload, payload);
}

// Helper: get JNIEnv for current thread
static JNIEnv* getEnv() {
    if (!gJvm) return nullptr;
    JNIEnv* env = nullptr;
    jint res = gJvm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
    if (res == JNI_EDETACHED) {
        if (gJvm->AttachCurrentThread(&env, nullptr) != JNI_OK) {
            return nullptr;
        }
    }
    if (env && env->ExceptionCheck()) {
        env->ExceptionClear();
    }
    return env;
}

// Helper: get Kotlin singleton instance
static jobject getBridgeSingleton(JNIEnv* env) {
    if (gBridgeInstance) return gBridgeInstance;
    if (gBridgeClass) {
        jfieldID fid = env->GetStaticFieldID(gBridgeClass, "INSTANCE", "Lcom/dartnative/bottom_sheet/DNBottomSheetBridge;");
        if (fid) {
            jobject localInst = env->GetStaticObjectField(gBridgeClass, fid);
            if (localInst) {
                gBridgeInstance = env->NewGlobalRef(localInst);
                env->DeleteLocalRef(localInst);
                return gBridgeInstance;
            }
        }
    }
    return nullptr;
}

// ─── @_cdecl-style FFI entry points called from Dart ─────────────────────────

extern "C" void DNBottomSheetSetDispatcher(int64_t ptr) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge || !mid_setDispatcher) return;
    env->CallVoidMethod(bridge, mid_setDispatcher, (jlong)ptr);
    if (env->ExceptionCheck()) env->ExceptionClear();
}

extern "C" int64_t DNBottomSheetShow(const char* jsonCStr) {
    JNIEnv* env = getEnv();
    if (!env || !jsonCStr) return 0;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge || !mid_show) {
        LOGE("DNBottomSheetShow: bridge or show method not resolved");
        return 0;
    }
    jstring jstr = env->NewStringUTF(jsonCStr);
    jlong rootViewId = env->CallLongMethod(bridge, mid_show, jstr);
    env->DeleteLocalRef(jstr);
    if (env->ExceptionCheck()) {
        LOGE("DNBottomSheetShow: exception in Kotlin show()");
        env->ExceptionDescribe();
        env->ExceptionClear();
        return 0;
    }
    return (int64_t)rootViewId;
}

extern "C" void DNBottomSheetDismiss(int64_t sheetId, bool animated) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge || !mid_dismiss) return;
    env->CallVoidMethod(bridge, mid_dismiss, (jlong)sheetId, (jboolean)animated);
    if (env->ExceptionCheck()) env->ExceptionClear();
}

extern "C" void DNBottomSheetSnapTo(int64_t sheetId, int32_t detentIndex, bool animated) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge || !mid_snapTo) return;
    env->CallVoidMethod(bridge, mid_snapTo, (jlong)sheetId, (jint)detentIndex, (jboolean)animated);
    if (env->ExceptionCheck()) env->ExceptionClear();
}

extern "C" void DNBottomSheetLayoutContent(int64_t sheetId) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge || !mid_layoutContent) return;
    env->CallVoidMethod(bridge, mid_layoutContent, (jlong)sheetId);
    if (env->ExceptionCheck()) env->ExceptionClear();
}

extern "C" void DNBottomSheetInvalidateDetents(int64_t sheetId) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge || !mid_invalidateDetents) return;
    env->CallVoidMethod(bridge, mid_invalidateDetents, (jlong)sheetId);
    if (env->ExceptionCheck()) env->ExceptionClear();
}

extern "C" void DNBottomSheetAnimateChangesBegin(int64_t sheetId) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge || !mid_beginAnimateChanges) return;
    env->CallVoidMethod(bridge, mid_beginAnimateChanges, (jlong)sheetId);
    if (env->ExceptionCheck()) env->ExceptionClear();
}

extern "C" void DNBottomSheetAnimateChangesEnd(int64_t sheetId) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge || !mid_endAnimateChanges) return;
    env->CallVoidMethod(bridge, mid_endAnimateChanges, (jlong)sheetId);
    if (env->ExceptionCheck()) env->ExceptionClear();
}

extern "C" void DNBottomSheetMountContent(int64_t sheetId, int64_t viewId) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge || !mid_mountContent) return;
    env->CallVoidMethod(bridge, mid_mountContent, (jlong)sheetId, (jlong)viewId);
    if (env->ExceptionCheck()) env->ExceptionClear();
}

extern "C" void DNBottomSheetPush(int64_t sheetId, int32_t expandsToDetentIndex) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge || !mid_push) return;
    env->CallVoidMethod(bridge, mid_push, (jlong)sheetId, (jint)expandsToDetentIndex);
    if (env->ExceptionCheck()) env->ExceptionClear();
}

extern "C" void DNBottomSheetPop(int64_t sheetId) {
    JNIEnv* env = getEnv();
    if (!env) return;
    jobject bridge = getBridgeSingleton(env);
    if (!bridge || !mid_pop) return;
    env->CallVoidMethod(bridge, mid_pop, (jlong)sheetId);
    if (env->ExceptionCheck()) env->ExceptionClear();
}

