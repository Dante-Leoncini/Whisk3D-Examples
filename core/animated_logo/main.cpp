// ============================================================================
//  animated_logo — carga un LOGO ANIMADO con TEXTURAS en formato glTF/GLB y lo
//  dibuja CENTRADO sobre fondo negro. Todo el trabajo pesado (parsear el .glb,
//  decodificar las texturas, animar y renderizar) lo hace el CORE:
//
//      #include "io/w3dGltf.h"     // loader + renderer glTF/GLB del Whisk3DCore
//      gltf::Model model;
//      gltf::LoadG(LeerArchivo, &carpeta, "whisk3d_logo.glb", model);   // <- carga (los bytes los da LeerArchivo)
//      gltf::Draw(model, tiempoSeg, vx, vy, vw, vh);                     // <- dibuja animado
//
//  El ejemplo NO toca GL directo ni parsea nada: solo dice de DONDE salen los bytes
//  (archivos de una carpeta) y DONDE va el viewport. Corre igual en desktop y en
//  WebGL. SOLO glTF/GLB (los demas formatos son extras del editor). El modelo puede
//  venir de ARCHIVOS (como aca) o de un pack cifrado (gltf::Load(pack, ...)).
// ============================================================================
#define SDL_MAIN_HANDLED
#include <SDL2/SDL.h>
#include "w3dGraphics.h"     // render del Core (w3dEngine)
#include "w3dlog.h"          // log del Core
#include "io/w3dGltf.h"      // loader + renderer glTF/GLB (DEL CORE)
#include "io/w3dFilesystem.h"  // w3dFileSystem::ReadFileBytes (disco en desktop, el VFS de emscripten en web)
#include <map>
#include <string>
#include <vector>
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
static float        g_aspect = 1.0f;  // ancho/alto del logo (ver LogoAspect)

// LOS BYTES DEL MODELO: gltf::LoadG le pide cada archivo por su nombre (el .glb y sus texturas externas) y esto los
// lee de una carpeta con el Core. Los guarda mientras dura la carga: LoadG copia lo que necesita.
struct Carpeta { std::string ruta; std::map<std::string, std::vector<unsigned char> > leidos; };
static const unsigned char* LeerArchivo(void* ctx, const char* nombre, size_t* largo) {
    Carpeta* c = (Carpeta*)ctx;
    std::vector<unsigned char>& d = c->leidos[nombre];
    if (d.empty() && !w3dFileSystem::ReadFileBytes(c->ruta + "/" + nombre, d)) d.clear();
    *largo = d.size();
    return d.empty() ? 0 : &d[0];
}
// las PROPORCIONES del logo (ancho/alto), con la misma cuenta con que gltf::Draw lo encuadra: el ancho cuenta el
// giro (el radio en Z), porque el logo rota sobre su eje vertical
static float LogoAspect(const gltf::Model& m) {
    Vector3 ext = m.bmax - m.bmin;
    float hx = ext.x * 0.5f, rz = ext.z * 0.5f, hy = ext.y * 0.5f;
    if (rz > hx) hx = rz;
    return (hx > 1e-4f && hy > 1e-4f) ? hx / hy : 1.0f;
}

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
        // del logo (g_aspect = ancho/alto). Ocupa como mucho el 70% del lado
        // mas chico -> siempre entra, centrado, en ventanas verticales u horizontales.
        float aspect = g_aspect; if (aspect < 0.05f) aspect = 0.05f;
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
    // --embed-file). La textura externa (image_0.png) la pide el Core por su nombre y
    // LeerArchivo la busca en esa misma carpeta. false si el .glb no esta o esta corrupto.
    Carpeta assets; assets.ruta = "assets";
    if (gltf::LoadG(LeerArchivo, &assets, "whisk3d_logo.glb", g_model)) {
        g_ok = true; g_t0 = SDL_GetTicks();
        g_aspect = LogoAspect(g_model);
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
