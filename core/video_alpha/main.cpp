// ============================================================================
//  video_alpha — un video con ALPHA (WebM) reproducido en loop SOBRE otro video
//  de fondo (MP4). La decodificacion y la reproduccion las hace el MOTOR
//  (w3dEngine::W3dVideo), modulo OPCIONAL: se compila con -DW3D_ENABLE_VIDEO y el
//  backend decide el codec (navegador = HW; desktop = FFmpeg). El ejemplo NO toca
//  ni GL ni ningun decoder: pide la textura del frame actual y dibuja dos quads.
//
//  Encuadre al cambiar el tamano de la ventana (como object-fit de CSS, sin deformar):
//    - FONDO (mp4)  -> "cover":   llena la ventana creciendo en ancho O alto; lo que
//                                 sobra se RECORTA. Nunca se ve el fondo negro.
//    - FRENTE (webm)-> "contain": se ve ENTERO, centrado; si no encaja, deja aire
//                                 (letterbox) a los lados o arriba/abajo.
// ============================================================================
#define SDL_MAIN_HANDLED
#include <SDL2/SDL.h>
#include "w3dGraphics.h"     // render del Core (w3dEngine)
#include "w3dlog.h"          // log del Core
#include "video/W3dVideo.h"  // reproduccion de video del Core (modulo opcional)
#include "io/W3dPack.h"      // assets PROTEGIDOS: contenedor cifrado (.w3dpack)
#ifdef __EMSCRIPTEN__
    #include <emscripten.h>
    #include <emscripten/html5.h>
#endif

namespace gfx = w3dEngine;

static SDL_Window*      g_win = 0;
static bool             g_run = true;
static w3dEngine::W3dVideo* g_fondo  = 0; // mp4  (cover)
static w3dEngine::W3dVideo* g_frente = 0; // webm (contain, con alpha)
static w3dEngine::W3dPack   g_pack;       // duenio de los bytes descifrados (mantener vivo)

// Clave del pack. EMBEBIDA aca = deterrence (frena al inspector / "guardar como" / scripts,
// ~99%). Un atacante que lea el binario la saca -> NO es DRM inquebrantable (ver THREAT_MODEL.md).
// Para proteccion fuerte, en vez de embeberla traela de TU servidor por sesion autorizada.
// Reemplazala por la clave que te imprime `w3dpacker --genkey` al empaquetar tus videos.
static const unsigned char PACK_KEY[32] = {
    0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07, 0x08,0x09,0x0a,0x0b,0x0c,0x0d,0x0e,0x0f,
    0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17, 0x18,0x19,0x1a,0x1b,0x1c,0x1d,0x1e,0x1f
};

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
    if (*w < 1) *w = 1;
    if (*h < 1) *h = 1;
}

// Dibuja el frame actual de 'v' como un quad 2D encuadrado en la ventana (W x H).
// cover=true  -> llena la ventana y recorta (UVs recortadas, quad a pantalla completa).
// cover=false -> se ve entero y centrado (quad del tamano que entra, UVs 0..1).
static void dibujarVideo(w3dEngine::W3dVideo* v, int W, int H, bool cover) {
    if (!v) return;
    int vw = v->Width(), vh = v->Height();
    if (vw <= 0 || vh <= 0) return; // todavia no hay frame decodificado

    float x0, y0, x1, y1;           // rect del quad en pixeles (ortho, origen abajo-izq)
    float u0 = 0, v0 = 0, u1 = 1, v1 = 1;
    float rw = (float)W / (float)vw, rh = (float)H / (float)vh;

    if (cover) {
        // el video escalado por max(rw,rh) cubre la ventana; recortamos por UV lo que sobra
        float s = rw > rh ? rw : rh;
        float uFrac = (float)W / (vw * s);   // fraccion visible en U
        float vFrac = (float)H / (vh * s);
        u0 = (1.0f - uFrac) * 0.5f; u1 = 1.0f - u0;
        v0 = (1.0f - vFrac) * 0.5f; v1 = 1.0f - v0;
        x0 = 0; y0 = 0; x1 = (float)W; y1 = (float)H;
    } else {
        // el video escalado por min(rw,rh) entra entero; lo centramos (letterbox)
        float s = rw < rh ? rw : rh;
        float dw = vw * s, dh = vh * s;
        x0 = (W - dw) * 0.5f; y0 = (H - dh) * 0.5f;
        x1 = x0 + dw;         y1 = y0 + dh;
    }

    const float pos[12] = { x0,y0,  x1,y0,  x1,y1,   x0,y0,  x1,y1,  x0,y1 };
    const float uv [12] = { u0,v0,  u1,v0,  u1,v1,   u0,v0,  u1,v1,  u0,v1 };

    gfx::BindTexture(v->Texture());
    gfx::EnableArray(gfx::VertexArray);   gfx::VertexPointer2f(0, pos);
    gfx::EnableArray(gfx::TexCoordArray); gfx::TexCoordPointer2f(0, uv);
    gfx::DrawTrianglesArray(6);
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
    double nowMs = (double)SDL_GetTicks();
    if (g_fondo)  g_fondo->Update(nowMs);   // el backend avanza el frame + hace loop
    if (g_frente) g_frente->Update(nowMs);

    gfx::Viewport(0, 0, w, h);
    gfx::ClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    gfx::Clear(gfx::ColorBuffer | gfx::DepthBuffer);

    // 2D sin luz ni profundidad: origen abajo-izquierda, en pixeles.
    gfx::MatrixMode(gfx::Projection); gfx::LoadIdentity();
    gfx::Ortho(0, (float)w, 0, (float)h, -1, 1);
    gfx::MatrixMode(gfx::ModelView);  gfx::LoadIdentity();
    gfx::Disable(gfx::DepthTest);
    gfx::Disable(gfx::Lighting);
    gfx::Enable(gfx::Texture2D);
    gfx::Color4f(1, 1, 1, 1); // sin tinte: el video se ve tal cual

    // 1) FONDO opaco (cover). Sin blend.
    gfx::Disable(gfx::Blend);
    dibujarVideo(g_fondo, w, h, true);

    // 2) FRENTE con alpha (contain), mezclado encima.
    gfx::Enable(gfx::Blend);
    gfx::BlendAlpha(); // SRC_ALPHA, ONE_MINUS_SRC_ALPHA
    dibujarVideo(g_frente, w, h, false);

    SDL_GL_SwapWindow(g_win);
}

int main(int, char**) {
    SDL_SetMainReady();
    if (SDL_Init(SDL_INIT_VIDEO) != 0) return 1;
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

    g_win = SDL_CreateWindow("Whisk3D - Video Alpha",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 960, 600,
        SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
    if (!g_win) return 1;
    SDL_GLContext ctx = SDL_GL_CreateContext(g_win);
    SDL_GL_SetSwapInterval(1);

#ifdef W3D_WEBGL
    gfx::GLES2Init((void* (*)(const char*))SDL_GL_GetProcAddress);
#endif

    w3dLogReset();
    // Los videos salen de un PACK CIFRADO: el Core lo descifra en memoria y le pasa los
    // bytes al decoder SIN que exista ningun archivo con nombre ni URL. En el navegador,
    // la pestania de red solo muestra el pack ilegible.
    if (g_pack.OpenFile("assets.w3dpack", PACK_KEY)) {
        size_t n = 0; const unsigned char* b;
        b = g_pack.Get("fondo.mp4", &n);   if (b) g_fondo  = gfx::W3dVideoOpenMemory(b, n, "video/mp4",  true);
        b = g_pack.Get("frente.webm", &n); if (b) g_frente = gfx::W3dVideoOpenMemory(b, n, "video/webm", true);
    } else {
        w3dLogE("video_alpha: no pude abrir assets.w3dpack (clave equivocada, o falta el pack)");
    }
    if (!g_fondo)  w3dLogE("video_alpha: sin fondo (revisa el pack / la clave / el modulo de video)");
    if (!g_frente) w3dLogE("video_alpha: sin frente");

#ifdef __EMSCRIPTEN__
    emscripten_set_main_loop(frame, 0, 1);
#else
    while (g_run) frame();
    delete g_frente;
    delete g_fondo;
    SDL_GL_DeleteContext(ctx);
    SDL_DestroyWindow(g_win);
    SDL_Quit();
#endif
    return 0;
}
