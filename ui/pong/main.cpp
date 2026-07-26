// ============================================================================
//  Pong — el juego del Editor 2D de Whisk3D, corriendo SOLO (sin el editor).
//
//  Es el MISMO pong.w3dui + pong.lua que se abren en el editor; este main solo
//  arma la ventana (SDL + OpenGL/WebGL) y le pasa el loop al runtime del juego
//  (game/w3drun). Prueba de que un juego hecho en el editor se compila y corre
//  standalone en PC y en la web con el mismo codigo.
//
//  Controles: flechas ARRIBA/ABAJO (o el stick izquierdo del gamepad) mueven tu
//  pala. La maquina juega la otra. Dificultad: en el editor (aca queda "normal").
// ============================================================================
#define SDL_MAIN_HANDLED
#include <SDL2/SDL.h>
#include "w3drun.h"
#include "w3dGraphics.h"
#include <cstdio>
#ifdef __EMSCRIPTEN__
    #include <emscripten.h>
    #include <emscripten/html5.h>
#endif

namespace gfx = w3dEngine;

static SDL_Window* g_win = 0;
static bool g_run = true;
static SDL_GameController* g_pad = 0;
static Uint32 g_lastMs = 0;

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

static void frame() {
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
        if (e.type == SDL_QUIT) g_run = false;
        else if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE) g_run = false;
        else if (e.type == SDL_KEYDOWN) W3dGameTecla(e.key.keysym.sym, true);
        else if (e.type == SDL_KEYUP)   W3dGameTecla(e.key.keysym.sym, false);
        else if (e.type == SDL_CONTROLLERDEVICEADDED && !g_pad) g_pad = SDL_GameControllerOpen(e.cdevice.which);
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
    int w, h; tamActual(&w, &h);
    W3dGameRender(w, h);
    SDL_GL_SwapWindow(g_win);
}

namespace w3dEngine { bool W3dAudioInit(int); }   // audio/W3dAudio.h (sonido del beep())

int main(int, char**) {
    SDL_SetMainReady();
    SDL_Init(SDL_INIT_VIDEO | SDL_INIT_GAMECONTROLLER | SDL_INIT_AUDIO);
    w3dEngine::W3dAudioInit(44100);   // arranca el mixer (mudo si el device no abre)
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 16);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
#ifdef W3D_WEBGL
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
    g_win = SDL_CreateWindow("Pong - Whisk3D", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                             600, 600, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
    SDL_GLContext ctx = SDL_GL_CreateContext(g_win);
    if (!ctx) { fprintf(stderr, "GL context FALLO: %s\n", SDL_GetError()); return 2; }
    SDL_GL_SetSwapInterval(1);
#ifdef W3D_GLES2
    // el backend de SHADERS (WebGL/GLES2) hay que INICIALIZARLO: carga GL2.0 +
    // compila los shaders. El pipeline fijo (desktop) no lo necesita.
    gfx::GLES2Init((void* (*)(const char*))SDL_GL_GetProcAddress);
#endif

    // el juego: el MISMO w3dui + lua del editor, con las referencias del pong.w3d
    W3dGameFontPngSet("font.png");
    if (!W3dGameCargarUI("pong.w3dui")) { SDL_Log("no pude cargar pong.w3dui"); return 1; }
    W3dGameScript("pong.lua");
    W3dGameRef("jugador1",  "Pala 1");
    W3dGameRef("jugador2",  "Pala 2");
    W3dGameRef("pelota",    "Pelota");
    W3dGameRef("marcador1", "Marcador 1");
    W3dGameRef("marcador2", "Marcador 2");
    // UIs (contenedores) + objetos del menu: DEBEN coincidir con los ref_ del pong.w3d, sino el
    // script no los encuentra en el standalone (objeto() = nil) y el menu no se arma (bug Dante).
    W3dGameRef("juego",     "Juego");
    W3dGameRef("menuIni",   "MenuInicial");
    W3dGameRef("menuDif",   "MenuDificultad");
    W3dGameRef("mensaje",   "Mensaje");
    W3dGameRef("mensajeBg", "MensajeBg");
    W3dGameRef("mi1", "MI1"); W3dGameRef("mi2", "MI2"); W3dGameRef("mi3", "MI3");
    W3dGameRef("md1", "MD1"); W3dGameRef("md2", "MD2"); W3dGameRef("md3", "MD3");
    W3dGameRef("selMI", "SelMI"); W3dGameRef("selMD", "SelMD");
    W3dGameRef("titMI", "TituloMI"); W3dGameRef("titMD", "TituloMD");
    W3dGameRef("btnPausa", "BtnPausa");
    W3dGameRef("pausaBar1", "PausaBar1"); W3dGameRef("pausaBar2", "PausaBar2");
    W3dGameRef("dificultad", "normal");
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
