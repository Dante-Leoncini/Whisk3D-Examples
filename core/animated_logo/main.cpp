// ============================================================================
//  animated_logo — carga un LOGO ANIMADO con TEXTURAS en formato glTF/GLB y lo
//  dibuja CENTRADO sobre fondo negro. Todo el trabajo pesado (parsear el .glb,
//  decodificar las texturas, animar y renderizar) lo hace el CORE:
//
//      #include "io/w3dGltf.h"     // loader + renderer glTF/GLB del Whisk3DCore
//      gltf::Model model;
//      gltf::LoadFile("assets", "whisk3d_logo.glb", model);   // <- carga desde archivo
//      gltf::Draw(model, tiempoSeg, vx, vy, vw, vh);          // <- dibuja animado
//
//  El ejemplo NO toca GL directo ni parsea nada: solo elige DONDE va el viewport.
//  Corre igual en desktop y en WebGL. SOLO glTF/GLB (los demas formatos son extras
//  del editor). El modelo puede venir de un ARCHIVO (LoadFile) o de un pack cifrado
//  (gltf::Load(pack, ...) — ver RQ_Games).
// ============================================================================
#define SDL_MAIN_HANDLED
#include <SDL2/SDL.h>
#include "w3dGraphics.h"     // render del Core (w3dEngine)
#include "w3dlog.h"          // log del Core
#include "io/w3dGltf.h"      // loader + renderer glTF/GLB (DEL CORE)
#ifdef __EMSCRIPTEN__
    #include <emscripten.h>
    #include <emscripten/html5.h>
#endif

namespace gfx = w3dEngine;

static SDL_Window*  g_win  = 0;
static bool         g_run  = true;
static gltf::Model  g_model;
static bool         g_ok   = false;   // el logo se cargo bien
static unsigned int g_t0   = 0;       // ticks del arranque (tiempo de animacion)

static int g_lastW = 0, g_lastH = 0;
static void tamActual(int* w, int* h) {
#ifdef __EMSCRIPTEN__
    double cw = 0, ch = 0;
    emscripten_get_element_css_size("#canvas", &cw, &ch);
    *w = (int)cw; *h = (int)ch;
    if (*w != g_lastW || *h != g_lastH) {
        emscripten_set_canvas_element_size("#canvas", *w, *h);
        g_lastW = *w; g_lastH = *h;
    }
#else
    SDL_GL_GetDrawableSize(g_win, w, h);
#endif
    if (*w < 1) *w = 1; if (*h < 1) *h = 1;
}

static void frame() {
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
        if (e.type == SDL_QUIT) g_run = false;
        else if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE) g_run = false;
    }
#ifdef __EMSCRIPTEN__
    if (!g_run) { emscripten_cancel_main_loop(); return; }
#endif

    int w, h; tamActual(&w, &h);
    gfx::Viewport(0, 0, w, h);
    gfx::ClearColor(0.0f, 0.0f, 0.0f, 1.0f);            // FONDO NEGRO
    gfx::Clear(gfx::ColorBuffer | gfx::DepthBuffer);

    if (g_ok) {
        float t = (SDL_GetTicks() - g_t0) / 1000.0f;

        // Viewport CENTRADO en el medio de la ventana, manteniendo las proporciones
        // del logo (g_model.fitAspect = ancho/alto). Ocupa como mucho el 70% del lado
        // mas chico -> siempre entra, centrado, en ventanas verticales u horizontales.
        float aspect = g_model.fitAspect; if (aspect < 0.05f) aspect = 0.05f;
        int maxW = (int)(w * 0.70f), maxH = (int)(h * 0.70f);
        int lw = maxW, lh = (int)(lw / aspect + 0.5f);
        if (lh > maxH) { lh = maxH; lw = (int)(lh * aspect + 0.5f); }
        int vx = (w - lw) / 2, vy = (h - lh) / 2;

        gltf::Draw(g_model, t, vx, vy, lw, lh);          // animado, con sus materiales/texturas
    }

    SDL_GL_SwapWindow(g_win);
}

int main(int, char**) {
    SDL_SetMainReady();
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    // ANTIALIASING: MSAA 4x (en WebGL SDL2 lo mapea a antialias:true del canvas)
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 1);
    SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 4);

    g_win = SDL_CreateWindow("Whisk3D - Animated Logo (glTF/GLB)",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 960, 600,
        SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
    if (!g_win) return 1;
    SDL_GLContext ctx = SDL_GL_CreateContext(g_win);
    SDL_GL_SetSwapInterval(1);

#ifdef W3D_WEBGL
    gfx::GLES2Init((void* (*)(const char*))SDL_GL_GetProcAddress);
#endif
    w3dLogReset();

    // Carga el logo animado + su textura desde la carpeta "assets" (embebida en web con
    // --embed-file assets@assets). El Core resuelve la textura externa (image_0.png)
    // relativa a esa misma carpeta. Devuelve false si el .glb no esta o esta corrupto.
    if (gltf::LoadFile("assets", "whisk3d_logo.glb", g_model)) {
        g_ok = true; g_t0 = SDL_GetTicks();
        w3dLog("animated_logo: logo cargado con el Core (glTF/GLB)");
    } else {
        w3dLogE("animated_logo: no pude cargar assets/whisk3d_logo.glb — sigo con fondo negro");
    }

#ifdef __EMSCRIPTEN__
    emscripten_set_main_loop(frame, 0, 1);
#else
    while (g_run) frame();
    SDL_GL_DeleteContext(ctx);
    SDL_DestroyWindow(g_win);
    SDL_Quit();
#endif
    return 0;
}
