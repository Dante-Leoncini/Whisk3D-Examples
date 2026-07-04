// ============================================================================
//  simple_cube — el ejemplo mas simple de Whisk3D.
//
//  Un cubo LISO, iluminado por una luz, rotando constantemente. Sin texturas: solo
//  geometria + una luz + un color de material. Todo el render pasa por w3dEngine (el
//  render del Core) -> el mismo codigo corre en Windows, Linux, Android, Symbian y WebGL.
//
//  - En WebGL el loop es emscripten_set_main_loop (el browser es 1 hilo: un while()
//    infinito lo colgaria). En desktop es un while() normal.
//  - Se adapta al tamaño de la ventana/canvas cada frame (viewport + aspect dinamicos).
// ============================================================================
#define SDL_MAIN_HANDLED
#include <SDL2/SDL.h>
#include "w3dGraphics.h" // render del Core (w3dEngine) + MeshIndex
#include "w3dlog.h"       // log del Core (w3dLog): a whisk3d.log en desktop, a la consola en WebGL
#ifdef __EMSCRIPTEN__
    #include <emscripten.h>
    #include <emscripten/html5.h>
#endif

namespace gfx = w3dEngine;

// cubo: 24 vertices (4 por cara) + normal por cara. Sin UV (no hay textura).
static const float cubeVerts[24 * 3] = {
    -1,-1, 1,   1,-1, 1,   1, 1, 1,  -1, 1, 1,   // +Z
     1,-1,-1,  -1,-1,-1,  -1, 1,-1,   1, 1,-1,   // -Z
     1,-1, 1,   1,-1,-1,   1, 1,-1,   1, 1, 1,   // +X
    -1,-1,-1,  -1,-1, 1,  -1, 1, 1,  -1, 1,-1,   // -X
    -1, 1, 1,   1, 1, 1,   1, 1,-1,  -1, 1,-1,   // +Y
    -1,-1,-1,   1,-1,-1,   1,-1, 1,  -1,-1, 1,   // -Y
};

static const signed char cubeNormals[24 * 3] = {
      0,  0,127,   0,  0,127,   0,  0,127,   0,  0,127,
      0,  0,-127,  0,  0,-127,  0,  0,-127,  0,  0,-127,
    127,  0,  0, 127,  0,  0, 127,  0,  0, 127,  0,  0,
   -127,  0,  0,-127,  0,  0,-127,  0,  0,-127,  0,  0,
      0,127,  0,   0,127,  0,   0,127,  0,   0,127,  0,
      0,-127, 0,   0,-127, 0,   0,-127, 0,   0,-127, 0,
};

static const MeshIndex cubeIdx[36] = {
     0, 1, 2,  0, 2, 3,    4, 5, 6,  4, 6, 7,
     8, 9,10,  8,10,11,   12,13,14, 12,14,15,
    16,17,18, 16,18,19,   20,21,22, 20,22,23,
};

static SDL_Window* g_win = 0;
static bool  g_run = true;
static float g_ang = 0.0f; // acumula siempre -> rotacion continua

// tamano ACTUAL del framebuffer (se adapta a la ventana / canvas).
static int g_lastW = 0, g_lastH = 0;
static void tamActual(int* w, int* h) {
#ifdef __EMSCRIPTEN__
    double cw = 0, ch = 0;
    emscripten_get_element_css_size("#canvas", &cw, &ch); // tamano en pantalla (CSS)
    *w = (int)cw; *h = (int)ch;
    if (*w != g_lastW || *h != g_lastH) {                 // resolucion del canvas = display (nitido)
        emscripten_set_canvas_element_size("#canvas", *w, *h);
        g_lastW = *w; g_lastH = *h;
    }
#else
    SDL_GL_GetDrawableSize(g_win, w, h); // desktop: tamano real del framebuffer
#endif
    if (*w < 1) *w = 1; if (*h < 1) *h = 1;
}

// un frame: eventos + dibujo. La llama el browser (WebGL) o el while() (desktop).
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
    gfx::ClearColor(0.10f, 0.12f, 0.16f, 1.0f);
    gfx::Clear(gfx::ColorBuffer | gfx::DepthBuffer);

    gfx::MatrixMode(gfx::Projection);
    gfx::LoadIdentity();
    gfx::Perspective(45.0f, (float)w / (float)h, 0.1f, 100.0f);

    gfx::MatrixMode(gfx::ModelView);
    gfx::LoadIdentity();
    gfx::Translatef(0.0f, 0.0f, -5.0f);

    // luz fija a la escena (se posiciona tras la vista, antes de rotar el cubo)
    const float luzPos[4] = {3.0f, 4.0f, 5.0f, 1.0f};
    gfx::Light0fv(gfx::LightPosition, luzPos);

    gfx::Rotatef(g_ang * 0.55f, 1.0f, 0.0f, 0.0f);
    gfx::Rotatef(g_ang, 0.0f, 1.0f, 0.0f);

    gfx::EnableArray(gfx::VertexArray); gfx::VertexPointer3f(0, cubeVerts);
    gfx::EnableArray(gfx::NormalArray); gfx::NormalPointer3b(cubeNormals);
    gfx::DrawTriangles(36, cubeIdx);

    SDL_GL_SwapWindow(g_win);
    g_ang += 0.7f;
}

int main(int, char**) {
    SDL_SetMainReady();
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

    g_win = SDL_CreateWindow("Whisk3D - Simple Cube",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 960, 600,
        SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
    if (!g_win) return 1;
    SDL_GLContext ctx = SDL_GL_CreateContext(g_win);
    SDL_GL_SetSwapInterval(1);

#ifdef W3D_WEBGL
    gfx::GLES2Init((void* (*)(const char*))SDL_GL_GetProcAddress); // backend ES2: carga GL2.0 + shaders
#endif

    w3dLogReset(); // trunca el log (desktop) / marca el inicio (web)
    w3dLog("simple_cube: cubo iluminado con el render de Whisk3D Core (w3dEngine)");

    // estado fijo de la escena (persiste entre frames)
    gfx::Enable(gfx::DepthTest);
    gfx::Enable(gfx::Lighting);
    gfx::Enable(gfx::Light0);
    gfx::Enable(gfx::Normalize);

    const float luzDifusa[4]   = {1.0f, 1.0f, 0.95f, 1.0f};
    const float luzAmbiente[4] = {0.30f, 0.30f, 0.35f, 1.0f};
    gfx::Light0fv(gfx::LightDiffuse, luzDifusa);
    gfx::Light0fv(gfx::LightAmbient, luzAmbiente);

    // color del cubo (material): un naranja Whisk3D
    const float matNaranja[4] = {0.95f, 0.55f, 0.20f, 1.0f};
    gfx::Material(gfx::MatDiffuse, matNaranja);
    gfx::Material(gfx::MatAmbient, matNaranja);

#ifdef __EMSCRIPTEN__
    emscripten_set_main_loop(frame, 0, 1); // el browser llama a frame() ~60 veces/seg
#else
    while (g_run) frame();
    SDL_GL_DeleteContext(ctx);
    SDL_DestroyWindow(g_win);
    SDL_Quit();
#endif
    return 0;
}
