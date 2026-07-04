// ============================================================================
//  normal_map_cube — cubo con NORMAL MAP (DOT3), textura cargada de archivo.
//
//  El relieve es FALSO: la geometria es un cubo liso, pero la textura de normales
//  (Whisk3D_logo_normal.png) + el combiner DOT3 (N.L por pixel) lo hacen agarrar luz
//  como si tuviera relieve. La luz esta FIJA en el mundo y el cubo gira -> el relieve
//  "prende" segun como queda frente a la luz. Rota constante, se adapta a la ventana.
//
//  La textura la carga el Core (w3dEngine::LoadTexture). El render pasa por w3dEngine:
//  mismo camino que Mesh::RenderObject (pass DOT3) -> corre en desktop y en WebGL.
// ============================================================================
#define SDL_MAIN_HANDLED
#include <SDL2/SDL.h>
#include "w3dGraphics.h" // render del Core (w3dEngine) + MeshIndex
#include "w3dTexture.h"   // w3dEngine::LoadTexture
#include "w3dlog.h"       // log del Core (w3dLog): a whisk3d.log en desktop, a la consola en WebGL
#include <math.h>
#ifdef __EMSCRIPTEN__
    #include <emscripten.h>
    #include <emscripten/html5.h>
#endif

namespace gfx = w3dEngine;

// cubo: 24 vertices (4 por cara) + UV. La base tangente (T,N) es POR CARA.
static const float V[24 * 3] = {
    -1,-1, 1,   1,-1, 1,   1, 1, 1,  -1, 1, 1,   // +Z
     1,-1,-1,  -1,-1,-1,  -1, 1,-1,   1, 1,-1,   // -Z
     1,-1, 1,   1,-1,-1,   1, 1,-1,   1, 1, 1,   // +X
    -1,-1,-1,  -1,-1, 1,  -1, 1, 1,  -1, 1,-1,   // -X
    -1, 1, 1,   1, 1, 1,   1, 1,-1,  -1, 1,-1,   // +Y
    -1,-1,-1,   1,-1,-1,   1,-1, 1,  -1,-1, 1,   // -Y
};
static const float UV[24 * 2] = {
    0,1, 1,1, 1,0, 0,0,   0,1, 1,1, 1,0, 0,0,
    0,1, 1,1, 1,0, 0,0,   0,1, 1,1, 1,0, 0,0,
    0,1, 1,1, 1,0, 0,0,   0,1, 1,1, 1,0, 0,0,
};
static const MeshIndex IDX[36] = {
     0, 1, 2,  0, 2, 3,    4, 5, 6,  4, 6, 7,
     8, 9,10,  8,10,11,   12,13,14, 12,14,15,
    16,17,18, 16,18,19,   20,21,22, 20,22,23,
};
static const float faceN[6][3] = {{0,0,1},{0,0,-1},{1,0,0},{-1,0,0},{0,1,0},{0,-1,0}};
static const float faceT[6][3] = {{1,0,0},{-1,0,0},{0,0,-1},{0,0,1},{1,0,0},{1,0,0}};

static void  rotX(float* v, float deg){ float r=deg*0.01745329f,c=cosf(r),s=sinf(r); float y=v[1],z=v[2]; v[1]=c*y-s*z; v[2]=s*y+c*z; }
static void  rotY(float* v, float deg){ float r=deg*0.01745329f,c=cosf(r),s=sinf(r); float x=v[0],z=v[2]; v[0]=c*x+s*z; v[2]=-s*x+c*z; }
static float dot3(const float* a, const float* b){ return a[0]*b[0]+a[1]*b[1]+a[2]*b[2]; }
static void  cross3(const float* a, const float* b, float* o){ o[0]=a[1]*b[2]-a[2]*b[1]; o[1]=a[2]*b[0]-a[0]*b[2]; o[2]=a[0]*b[1]-a[1]*b[0]; }

static SDL_Window* g_win = 0;
static bool  g_run = true;
static float g_ang = 0.0f;
static unsigned int g_nmap = 0;

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

    // luz fija en el MUNDO -> al espacio LOCAL del cubo (inverso de su rotacion Rx(a)*Ry(b))
    float luzLocal[3] = {3.0f, 4.0f, 6.0f};
    rotX(luzLocal, -g_ang * 0.55f);
    rotY(luzLocal, -g_ang);

    // L en tangent-space por vertice -> nmColors (igual que Mesh::ActualizarNormalMapColors)
    static unsigned char nmColors[24 * 4];
    for (int fc = 0; fc < 6; fc++) {
        float B[3]; cross3(faceN[fc], faceT[fc], B);
        for (int c = 0; c < 4; c++) {
            int v = fc * 4 + c;
            float L[3] = { luzLocal[0]-V[v*3], luzLocal[1]-V[v*3+1], luzLocal[2]-V[v*3+2] };
            float len = sqrtf(dot3(L, L)); if (len > 1e-6f) { L[0]/=len; L[1]/=len; L[2]/=len; }
            float lt = dot3(L, faceT[fc]), lb = dot3(L, B), ln = dot3(L, faceN[fc]);
            nmColors[v*4]   = (unsigned char)((lt * 0.5f + 0.5f) * 255);
            nmColors[v*4+1] = (unsigned char)((lb * 0.5f + 0.5f) * 255);
            nmColors[v*4+2] = (unsigned char)((ln * 0.5f + 0.5f) * 255);
            nmColors[v*4+3] = 255;
        }
    }

    int w, h; tamActual(&w, &h);
    gfx::Viewport(0, 0, w, h);
    gfx::ClearColor(0.08f, 0.09f, 0.12f, 1.0f);
    gfx::Clear(gfx::ColorBuffer | gfx::DepthBuffer);

    gfx::MatrixMode(gfx::Projection);
    gfx::LoadIdentity();
    gfx::Perspective(45.0f, (float)w / (float)h, 0.1f, 100.0f);

    gfx::MatrixMode(gfx::ModelView);
    gfx::LoadIdentity();
    gfx::Translatef(0.0f, 0.0f, -5.0f);
    gfx::Rotatef(g_ang * 0.55f, 1.0f, 0.0f, 0.0f);
    gfx::Rotatef(g_ang, 0.0f, 1.0f, 0.0f);

    // DOT3: textura=N, color=L -> N.L por pixel. Sin luz del pipeline.
    gfx::Disable(gfx::Lighting);
    gfx::DisableArray(gfx::NormalArray);
    gfx::Enable(gfx::Texture2D);
    gfx::BindTexture(g_nmap);
    gfx::TexFilter(true);
    gfx::TexWrap(false);
    gfx::TexEnvDot3(true);
    gfx::EnableArray(gfx::VertexArray);   gfx::VertexPointer3f(0, V);
    gfx::EnableArray(gfx::TexCoordArray); gfx::TexCoordPointer2f(0, UV);
    gfx::EnableArray(gfx::ColorArray);    gfx::ColorPointer4ub(nmColors);
    gfx::DrawTriangles(36, IDX);
    gfx::TexEnvDot3(false);

    SDL_GL_SwapWindow(g_win);
    g_ang += 0.7f;
}

int main(int, char**) {
    SDL_SetMainReady();
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

    g_win = SDL_CreateWindow("Whisk3D - Normal Map Cube",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 960, 600,
        SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
    if (!g_win) return 1;
    SDL_GLContext ctx = SDL_GL_CreateContext(g_win);
    SDL_GL_SetSwapInterval(1);

#ifdef W3D_WEBGL
    gfx::GLES2Init((void* (*)(const char*))SDL_GL_GetProcAddress);
#endif

    w3dLogReset();
    if (!gfx::LoadTexture("assets/Whisk3D_logo_normal.png", g_nmap)) {
        w3dLog("normal_map_cube: no pude cargar assets/Whisk3D_logo_normal.png");
        return 1;
    }
    w3dLog("normal_map_cube: normal map Whisk3D_logo_normal.png cargado con el Core");

    gfx::Enable(gfx::DepthTest);

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
