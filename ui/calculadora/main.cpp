// ============================================================================
//  Calculadora, ejemplo didactico de UI Whisk3D, corriendo SOLO (sin el editor).
//
//  Es la MISMA escena (.w3dui) + script (.lua) que se abre en el editor; este main
//  solo arma la ventana (SDL + OpenGL/WebGL) y le pasa el loop al runtime del
//  juego (game/w3drun). UNA sola escena, con el script embebido en el .w3dui.
//
//  Controles: mouse (click) o el dedo (tap) sobre los botones.
// ============================================================================
#ifndef __ANDROID__
// desktop/web: usamos NUESTRO main() + SDL_SetMainReady(). En Android NO: SDL (SDL_main.h) tiene que
// renombrar main->SDL_main para que SDLActivity encuentre el entry point; sino la app abre y se cierra.
#define SDL_MAIN_HANDLED
#endif
#include <SDL2/SDL.h>
#include "w3drun.h"
#include "w3dGraphics.h"
#include "io/w3dFilesystem.h"   // SetUserDataDir(): carpeta escribible (por si el script guardara config)
#include "script/W3dScript.h"   // W3dScriptSemilla(): reforzar la semilla del random con entropia del desktop
#include <cstdio>
#include <cstdlib>   // exit() (cierre del juego en Android)
#include <ctime>     // time(0): fuente que varia entre ejecuciones para la semilla del random
#ifdef __ANDROID__
    #include <jni.h>
    #include <android/asset_manager.h>
    #include <android/asset_manager_jni.h>
    #include "io/w3dFilesystem.h"   // w3dFileSystem::SetAssetManager (assets del APK)
#endif
#ifdef __EMSCRIPTEN__
    #include <emscripten.h>
    #include <emscripten/html5.h>
#endif

namespace gfx = w3dEngine;

static SDL_Window* g_win = 0;
static bool g_run = true;
static SDL_GameController* g_pad = 0;
static Uint32 g_lastMs = 0;

// MULTI-TOUCH: hasta 4 dedos. SDL entrega un fingerId arbitrario por dedo; lo mapeamos a un slot
// fijo 0..3 (el que lee dedo(1..4) en lua). Asi 2 jugadores tactiles manejan una pala cada uno.
#define W3D_NDEDOS 4
static SDL_FingerID g_dedoId[W3D_NDEDOS] = { (SDL_FingerID)-1, (SDL_FingerID)-1, (SDL_FingerID)-1, (SDL_FingerID)-1 };
static int dedoSlot(SDL_FingerID id, bool crear) {
    for (int i = 0; i < W3D_NDEDOS; i++) if (g_dedoId[i] == id) return i;
    if (!crear) return -1;
    for (int i = 0; i < W3D_NDEDOS; i++) if (g_dedoId[i] == (SDL_FingerID)-1) { g_dedoId[i] = id; return i; }
    return -1;
}

static void tamActual(int* w, int* h) {
#ifdef __EMSCRIPTEN__
    double cw = 0, ch = 0;
    emscripten_get_element_css_size("#canvas", &cw, &ch);
    *w = (int)cw; *h = (int)ch;
    static int lw = 0, lh = 0;
    if (*w != lw || *h != lh) { emscripten_set_canvas_element_size("#canvas", *w, *h); lw = *w; lh = *h; }
#else
    SDL_GL_GetDrawableSize(g_win, w, h);
    if (*w < 1 || *h < 1) SDL_GetWindowSize(g_win, w, h);   // fallback si el drawable no reporta
#endif
    if (*w < 1) *w = 1; if (*h < 1) *h = 1;
}

#ifdef __ANDROID__
// consultar al Activity (getSafeInsets) los insets del notch/barras y pasarlos al juego -> acota la UI.
static void actualizarSafeArea() {
    JNIEnv* env = (JNIEnv*)SDL_AndroidGetJNIEnv();
    jobject activity = (jobject)SDL_AndroidGetActivity();
    if (!env || !activity) return;
    jclass clazz = env->GetObjectClass(activity);
    jmethodID mid = clazz ? env->GetMethodID(clazz, "getSafeInsets", "()[I") : 0;
    if (mid) {
        jintArray arr = (jintArray)env->CallObjectMethod(activity, mid);
        if (arr && env->GetArrayLength(arr) >= 4) {
            jint* v = env->GetIntArrayElements(arr, 0);
            W3dGameSafeArea((int)v[0], (int)v[1], (int)v[2], (int)v[3]);
            env->ReleaseIntArrayElements(arr, v, JNI_ABORT);
        }
        if (arr) env->DeleteLocalRef(arr);
    }
    // NUNCA dejar una excepcion JNI pendiente: la siguiente llamada JNI abortaria la app. Como esto corre
    // cada frame, un solo tropiezo (metodo ausente, etc.) tiraria el juego. La limpiamos siempre.
    if (env->ExceptionCheck()) env->ExceptionClear();
    if (clazz) env->DeleteLocalRef(clazz);
    env->DeleteLocalRef(activity);
}
#endif

static void frame() {
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
        if (e.type == SDL_QUIT) g_run = false;
        else if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE) g_run = false;
        else if (e.type == SDL_KEYDOWN) W3dGameTecla(e.key.keysym.sym, true);
        else if (e.type == SDL_KEYUP)   W3dGameTecla(e.key.keysym.sym, false);
        else if (e.type == SDL_CONTROLLERDEVICEADDED && !g_pad) g_pad = SDL_GameControllerOpen(e.cdevice.which);
        // al desconectar el gamepad: cerrarlo y liberar g_pad, sino no se puede abrir otro (queda roto)
        else if (e.type == SDL_CONTROLLERDEVICEREMOVED && g_pad &&
                 e.cdevice.which == SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(g_pad))) {
            SDL_GameControllerClose(g_pad); g_pad = 0;
        }
        // jugar con el mouse o el dedo: arrastrar mueve la pala (toque() en lua)
        else if (e.type == SDL_MOUSEBUTTONDOWN && e.button.button == SDL_BUTTON_LEFT)
            W3dGameToque((int)e.button.x, (int)e.button.y, true);
        else if (e.type == SDL_MOUSEMOTION) {
            W3dGameRaton((int)e.motion.x, (int)e.motion.y, true);   // mouse-over (siempre, sin clic)
            if (e.motion.state & SDL_BUTTON_LMASK)
                W3dGameToque((int)e.motion.x, (int)e.motion.y, true); // arrastre (con boton apretado)
        }
        else if (e.type == SDL_MOUSEBUTTONUP && e.button.button == SDL_BUTTON_LEFT)
            W3dGameToque((int)e.button.x, (int)e.button.y, false);
        // MULTI-TOUCH real (tactil / movil): cada dedo -> su slot -> dedo(1..4) en lua. Con esto andan
        // los 2 jugadores tactiles (antes SDL emulaba UN mouse con el primer dedo y 2 dedos se rompian).
        else if (e.type == SDL_FINGERDOWN || e.type == SDL_FINGERMOTION) {
            int s = dedoSlot(e.tfinger.fingerId, e.type == SDL_FINGERDOWN);
            if (s >= 0) { int w, h; tamActual(&w, &h);
                W3dGameDedo(s, (int)(e.tfinger.x * w), (int)(e.tfinger.y * h), true); }
        }
        else if (e.type == SDL_FINGERUP) {
            int s = dedoSlot(e.tfinger.fingerId, false);
            if (s >= 0) { int w, h; tamActual(&w, &h);
                W3dGameDedo(s, (int)(e.tfinger.x * w), (int)(e.tfinger.y * h), false);
                g_dedoId[s] = (SDL_FingerID)-1; }
        }
    }
#ifdef __EMSCRIPTEN__
    if (!g_run) { emscripten_cancel_main_loop(); return; }
#endif

    // gamepad analogico (los ejes ya normalizados, con deadzone)
    if (g_pad) {
        const float DZ = 0.2f, M = 1.0f / 32767.0f;
        float lx = SDL_GameControllerGetAxis(g_pad, SDL_CONTROLLER_AXIS_LEFTX) * M;
        float ly = SDL_GameControllerGetAxis(g_pad, SDL_CONTROLLER_AXIS_LEFTY) * M;
        if (lx > -DZ && lx < DZ) lx = 0; if (ly > -DZ && ly < DZ) ly = 0;
        W3dGameStick(0, lx, ly);
        W3dGameBoton("a", SDL_GameControllerGetButton(g_pad, SDL_CONTROLLER_BUTTON_A) != 0);
    }

    // dt REAL (la fisica del juego es proporcional al tiempo, no a los fps)
    Uint32 now = SDL_GetTicks();
    float dt = (now - g_lastMs) / 1000.0f;
    g_lastMs = now;
    if (dt < 0) dt = 0; if (dt > 0.1f) dt = 0.1f;

    W3dGameActualizar(dt);
#ifndef __EMSCRIPTEN__
    if (W3dGameQuierePararse()) {           // lua salir(): cerrar el juego (no en web)
#ifdef __ANDROID__
        // MATAR el proceso: si solo retornamos, la Activity queda viva y al reabrir se relanza main()
        // con los globals C++ estaticos sucios -> "abre y cierra". exit() arranca fresco la proxima vez.
        SDL_Quit();
        exit(0);
#endif
        g_run = false;
        return;
    }
#endif
#ifdef __ANDROID__
    actualizarSafeArea();                  // insets del notch -> UI dentro de la zona segura
#endif
    int w, h; tamActual(&w, &h);
    W3dGameRender(w, h);
    SDL_GL_SwapWindow(g_win);
}

// SIN AUDIO: la calculadora no suena (build liviano, sin W3D_ENABLE_AUDIO ni el
// backend SDL). No se arranca el mixer; el lua tampoco llama beep().

int main(int, char**) {
#ifndef __ANDROID__
    SDL_SetMainReady();   // en Android lo hace SDL antes de llamar a SDL_main
#endif
    // NO emular un mouse desde el touch: queremos los dedos por separado (SDL_FINGER*) para el 2P
    // tactil. Con la emulacion, 2 dedos peleaban por el unico cursor y el juego "dejaba de andar".
    SDL_SetHint(SDL_HINT_TOUCH_MOUSE_EVENTS, "0");
    // SOLO VERTICAL: una calculadora no rota (acompania al screenOrientation="portrait"
    // del AndroidManifest). Va ANTES de crear la ventana; en desktop/web es inocuo.
    SDL_SetHint(SDL_HINT_ORIENTATIONS, "Portrait");
#if defined(__linux__) && !defined(__ANDROID__) && !defined(__EMSCRIPTEN__)
    // app-id = nombre del .desktop instalado (whisk3d-calculadora.desktop): asi el dock
    // muestra el icono. Este SDL2 no tiene SDL_HINT_APP_ID: Wayland lee el env
    // SDL_VIDEO_WAYLAND_WMCLASS y X11 el SDL_VIDEO_X11_WMCLASS, ANTES de SDL_Init.
    SDL_setenv("SDL_VIDEO_WAYLAND_WMCLASS", "whisk3d-calculadora", 1);
    SDL_setenv("SDL_VIDEO_X11_WMCLASS", "whisk3d-calculadora", 1);
#endif
    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER) != 0) {
        fprintf(stderr, "SDL_Init FALLO: %s\n", SDL_GetError()); return 2;
    }
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
#if defined(W3D_WEBGL) || defined(__ANDROID__)
    // WebGL y Android: contexto GLES 2.0 (backend de shaders). Android NO tiene el pipeline fijo.
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
#else
    // pipeline FIJO (glVertexPointer/glDrawArrays): pedir COMPATIBILITY 2.1, igual
    // que el editor. Sin esto el driver puede dar un contexto CORE y no dibuja nada.
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 1);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_COMPATIBILITY);
#endif
    g_win = SDL_CreateWindow("Calculadora Whisk3D", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                             360, 640, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
    if (!g_win) { fprintf(stderr, "ventana FALLO: %s\n", SDL_GetError()); return 2; }
    SDL_GLContext ctx = SDL_GL_CreateContext(g_win);
    if (!ctx) { fprintf(stderr, "GL context FALLO: %s\n", SDL_GetError()); return 2; }
    SDL_GL_SetSwapInterval(1);
    // Android: la calculadora NO va inmersiva (a proposito, distinto del whiskpaddle): es una
    // app utilitaria y conviene ver la hora/bateria y la navegacion para salir. VENTANA NORMAL:
    // la barra de estado ocupa la franja del notch, asi que los insets quedan en 0 y
    // areaSegura() devuelve el lienzo entero (el Activity/styles.xml acompanan: sin fullscreen).
#ifdef W3D_GLES2
    // el backend de SHADERS (WebGL/GLES2) hay que INICIALIZARLO: carga GL2.0 +
    // compila los shaders. El pipeline fijo (desktop) no lo necesita.
    gfx::GLES2Init((void* (*)(const char*))SDL_GL_GetProcAddress);
#endif

#ifdef __ANDROID__
    // los assets (calculadora.w3dui + calculadora.lua + font.png) van DENTRO del APK. El Core los lee con el
    // AAssetManager del NDK; lo sacamos del Activity via JNI y se lo pasamos al filesystem una vez.
    {
        JNIEnv* env = (JNIEnv*)SDL_AndroidGetJNIEnv();
        jobject activity = (jobject)SDL_AndroidGetActivity();
        if (env && activity) {
            jclass clazz = env->GetObjectClass(activity);
            jmethodID mid = env->GetMethodID(clazz, "getAssets", "()Landroid/content/res/AssetManager;");
            jobject amJava = env->CallObjectMethod(activity, mid);
            AAssetManager* am = AAssetManager_fromJava(env, amJava);
            w3dFileSystem::SetAssetManager(am);
            env->DeleteLocalRef(amJava);
            env->DeleteLocalRef(clazz);
            env->DeleteLocalRef(activity);
        }
    }
#endif

    // carpeta ESCRIBIBLE por si el script usara guardarConfig(): SDL_GetPrefPath da el almacenamiento
    // propio de la app (en Android el CWD es "/" y no se puede escribir). En web es inocuo (localStorage).
    // La calculadora no persiste nada, asi que no hay ConfigLoad ni deteccion de idioma (ver whiskpaddle).
    {
        char* pref = SDL_GetPrefPath("Whisk3D", "Calculadora");
        if (pref) { w3dFileSystem::SetUserDataDir(pref); SDL_free(pref); }
    }

    // REFORZAR la semilla del random con entropia del desktop (time(0) varia entre corridas). El Core ya
    // se siembra solo; esto se mezcla ANTES de crear los lua_States (W3dGameInicio -> W3dScriptCargar).
    W3dScriptSemilla((unsigned)time(0));

    // el juego: UNA sola escena. El script + sus refs YA vienen embebidos en el .w3dui
    // (array root "scripts": [{ruta,refs}]), asi que no hay W3dGameScript/W3dGameRef.
    // "Calculadora" es el campo "nombre" del .w3dui (con una sola escena hasta es opcional fijarla).
    W3dGameFontPngSet("font.png");
    if (!W3dGameCargarEscena("calculadora.w3dui")) { SDL_Log("no pude cargar calculadora.w3dui"); return 1; }
    W3dGameEscenaInicial("Calculadora");
    W3dGameInicio();

    g_lastMs = SDL_GetTicks();
#ifdef __EMSCRIPTEN__
    emscripten_set_main_loop(frame, 0, 1);
#else
    while (g_run) frame();
    SDL_Quit();
#endif
    return 0;
}
