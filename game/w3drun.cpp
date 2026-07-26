// ============================================================================
//  w3drun.cpp — ver w3drun.h. El runtime del juego 2D + los globals y stubs
//  que las piezas reusadas del editor esperan (asi el juego linkea sin arrastrar
//  todo el editor).
// ============================================================================
#include "w3drun.h"
#include "objects/Objects.h"
#include "objects/UI.h"
#include "objects/Texto2D.h"
#include "objects/Elemento2D.h"
#include "io/UI2DFormato.h"
#include "render/UIOverlay.h"
#include "script/W3dScript.h"
#include "w3dGraphics.h"
#include "WhiskUI/draw/glesdraw.h"   // W3dPantallaAlto (flip Y del scissor)

extern "C" {
#include "lua.h"
#include "lauxlib.h"
}

#include <vector>
#include <string>

namespace gfx = w3dEngine;

// ---------------------------------------------------------------------------
//  GLOBALS que las piezas reusadas del editor esperan (definidas ACA para el
//  runtime; en el editor las definen variables.cpp / OpcionesRender.cpp).
// ---------------------------------------------------------------------------
bool  g_redraw = true;                 // el editor lo usa para redibujar por evento
float g_gameRenderW = 480.0f;          // tamano de la "ventana de render" del juego
float g_gameRenderH = 480.0f;          // (UIOverlay lo lee via UI2D_TamanoVentana)

// la tipografia pixel (font.png); Fuente2D la pide con W3dGameFontPng()
static std::string gFontPng = "font.png";
void W3dGameFontPngSet(const std::string& ruta) { gFontPng = ruta; }
const char* W3dGameFontPng() { return gFontPng.c_str(); }

// ---------------------------------------------------------------------------
//  STUBS de imagen/video: el pong es solo rectangulos + texto, no usa texturas
//  ni video. UIOverlay igual referencia estas funciones (para los otros tipos),
//  asi que se stubean -> el runtime no arrastra ffmpeg ni el cache de video.
//  (Un juego con imagenes linkearia el Textura2D/Video2DCache reales en su lugar.)
// ---------------------------------------------------------------------------
#ifdef W3D_GAME_NO_TEX
unsigned Textura2DObtener(const std::string&, int* w, int* h) { if (w) *w = 0; if (h) *h = 0; return 0; }
std::string Textura2DRutaDecodificable(const std::string& r) { return r; }
struct VideoPreview;
const VideoPreview* Video2DPreview(const std::string&) { return 0; }
unsigned W3dMsAhora() { return 0; }
#endif

// ---------------------------------------------------------------------------
//  BINDINGS 2D del juego (los mismos nombres que ve el script en el editor):
//  pantalla/posPx/setPosPx/tamPx/setTamPx/setTexto. Coordenadas en PIXELES del
//  lienzo con (0,0) en el CENTRO. Se registran via W3dScriptSetBindExtra.
// ---------------------------------------------------------------------------
static UI* UIJuego() {
    if (!SceneCollection) return 0;
    for (size_t i = 0; i < SceneCollection->Childrens.size(); i++)
        if (SceneCollection->Childrens[i]->getType() == ObjectType::ui)
            return (UI*)SceneCollection->Childrens[i];
    return 0;
}
static void TamLienzo(float* w, float* h) {
    // EL MISMO tamaño que ve el RENDER del overlay (UI2D_TamanoVentana lee g_gameRenderW/H): asi el
    // script (pantalla/posPx) y el dibujo COINCIDEN. Lo pone W3dGameRender: la ventana real si la UI es
    // "igual que el render" (dinamico), o el tamaño fijo de la UI si no. Sin esto, con igualQueRender el
    // script usaba la ventana (600) y el overlay el tamaño fijo (480) -> todo descolocado (bug Dante).
    *w = g_gameRenderW; *h = g_gameRenderH;
}
static int LPantalla(lua_State* L) {
    float w, h; TamLienzo(&w, &h);
    lua_pushnumber(L, w); lua_pushnumber(L, h); return 2;
}
static int LPosPx(lua_State* L) {
    Object* o = W3dScriptParamObjeto(L, 1);
    float w, h; TamLienzo(&w, &h);
    if (!o) { lua_pushnumber(L, 0); lua_pushnumber(L, 0); return 2; }
    lua_pushnumber(L, o->pos.x * w); lua_pushnumber(L, o->pos.y * h); return 2;
}
static int LSetPosPx(lua_State* L) {
    Object* o = W3dScriptParamObjeto(L, 1);
    float w, h; TamLienzo(&w, &h);
    if (o && w > 0 && h > 0) { o->pos.x = (float)luaL_checknumber(L, 2) / w;
                               o->pos.y = (float)luaL_checknumber(L, 3) / h; }
    return 0;
}
static int LTamPx(lua_State* L) {
    Object* o = W3dScriptParamObjeto(L, 1);
    float w, h; TamLienzo(&w, &h);
    if (o && UI2D_EsElemento2D(o)) {
        Elemento2D* e = (Elemento2D*)o;
        lua_pushnumber(L, e->tamPx ? e->ancho : e->ancho * w);
        lua_pushnumber(L, e->tamPx ? e->alto  : e->alto  * h);
    } else { lua_pushnumber(L, 0); lua_pushnumber(L, 0); }
    return 2;
}
static int LSetTamPx(lua_State* L) {
    Object* o = W3dScriptParamObjeto(L, 1);
    float w, h; TamLienzo(&w, &h);
    if (o && UI2D_EsElemento2D(o) && w > 0 && h > 0) {
        Elemento2D* e = (Elemento2D*)o;
        float nw = (float)luaL_checknumber(L, 2), nh = (float)luaL_checknumber(L, 3);
        if (e->tamPx) { e->ancho = nw; e->alto = nh; }
        else          { e->ancho = nw / w; e->alto = nh / h; }
    }
    return 0;
}
static int LSetTexto(lua_State* L) {
    Object* o = W3dScriptParamObjeto(L, 1);
    if (o && o->getType() == ObjectType::texto2d) {
        const char* s = lua_tostring(L, 2);
        ((Texto2D*)o)->texto = s ? s : "";
    }
    return 0;
}
// mostrar/setOpacidad/setTam: mismas que la API del editor (ScriptUI.cpp) -> el mismo pong.lua corre
// standalone. mostrar prende/apaga el objeto (menus); setOpacidad = crossfade; setTam = tamaño de fuente.
static int LMostrar(lua_State* L) {
    Object* o = W3dScriptParamObjeto(L, 1);
    if (o) o->visible = lua_toboolean(L, 2) != 0;
    return 0;
}
static int LSetOpacidad(lua_State* L) {
    Object* o = W3dScriptParamObjeto(L, 1);
    if (o && UI2D_EsElemento2D(o)) {
        float a = (float)luaL_checknumber(L, 2);
        if (a < 0.0f) a = 0.0f; if (a > 1.0f) a = 1.0f;
        ((Elemento2D*)o)->opacidad = a;
    }
    return 0;
}
static int LSetTam(lua_State* L) {
    Object* o = W3dScriptParamObjeto(L, 1);
    if (o && o->getType() == ObjectType::texto2d)
        ((Texto2D*)o)->tam = (float)luaL_checknumber(L, 2);
    return 0;
}
static void RegistrarBind(void* Lv) {
    lua_State* L = (lua_State*)Lv;
    lua_pushcfunction(L, LPantalla); lua_setglobal(L, "pantalla");
    lua_pushcfunction(L, LPosPx);    lua_setglobal(L, "posPx");
    lua_pushcfunction(L, LSetPosPx); lua_setglobal(L, "setPosPx");
    lua_pushcfunction(L, LTamPx);    lua_setglobal(L, "tamPx");
    lua_pushcfunction(L, LSetTamPx); lua_setglobal(L, "setTamPx");
    lua_pushcfunction(L, LSetTexto); lua_setglobal(L, "setTexto");
    lua_pushcfunction(L, LMostrar);     lua_setglobal(L, "mostrar");
    lua_pushcfunction(L, LSetOpacidad); lua_setglobal(L, "setOpacidad");
    lua_pushcfunction(L, LSetTam);      lua_setglobal(L, "setTam");
}

// ---------------------------------------------------------------------------
//  Estado del juego cargado
// ---------------------------------------------------------------------------
static Object* gDuenio = 0;   // el objeto que lleva los scripts (la UI misma)

bool W3dGameCargarUI(const std::string& ruta) {
    // la RAIZ de la escena (el editor usa un Scene; el runtime, un Object pelado):
    // los objetos nuevos se cuelgan de aca, y UI2DCargar necesita que exista
    if (!SceneCollection) SceneCollection = new Object(0, "Scene");
    W3dScriptSetBindExtra(RegistrarBind);   // registrar la API 2D antes de cargar scripts
    UI* u = UI2DCargar(ruta);
    if (!u) return false;
    gDuenio = u;
    g_gameRenderW = u->ancho; g_gameRenderH = u->alto;
    return true;
}

void W3dGameScript(const std::string& rutaLua) {
    if (!gDuenio) return;
    if (!gDuenio->scriptDatos) gDuenio->scriptDatos = new W3dScriptDatos();
    W3dScriptEntrada e; e.ruta = rutaLua;
    gDuenio->scriptDatos->scripts.push_back(e);
}
void W3dGameRef(const std::string& prop, const std::string& valor) {
    if (!gDuenio || !gDuenio->scriptDatos || gDuenio->scriptDatos->scripts.empty()) return;
    gDuenio->scriptDatos->scripts.back().refs.push_back(std::make_pair(prop, valor));
}

static Object* BuscarPorNombre(Object* o, const std::string& n) {
    if (!o) return 0;
    if (o->name == n) return o;
    for (size_t i = 0; i < o->Childrens.size(); i++) {
        Object* r = BuscarPorNombre(o->Childrens[i], n);
        if (r) return r;
    }
    return 0;
}

void W3dGameInicio() {
    if (!gDuenio || !gDuenio->scriptDatos) return;
    if (!W3dScriptCargar(gDuenio)) return;
    // resolver las referencias (por nombre) y las opciones de cada script
    for (size_t e = 0; e < gDuenio->scriptDatos->scripts.size(); e++) {
        const W3dScriptEntrada& ent = gDuenio->scriptDatos->scripts[e];
        for (size_t r = 0; r < ent.refs.size(); r++) {
            Object* obj = BuscarPorNombre(SceneCollection, ent.refs[r].second);
            if (obj) W3dScriptResolverRef(gDuenio, (int)e, ent.refs[r].first, obj);
            W3dScriptResolverOpcion(gDuenio, (int)e, ent.refs[r].first, ent.refs[r].second);
        }
    }
    W3dScriptInicio(gDuenio);
}

void W3dGameActualizar(float dt) {
    if (gDuenio) W3dScriptActualizar(gDuenio, dt);
}

// mapeo del ultimo render (ventana -> lienzo), para convertir el toque a coords del lienzo
static float gUltEsc = 1.0f, gUltX0 = 0.0f, gUltY0 = 0.0f;

// dibuja la UI en 2D (ortho), centrada y escalada para ENTRAR en la ventana
void W3dGameRender(int winW, int winH) {
    if (winW < 1) winW = 1; if (winH < 1) winH = 1;
    // el lienzo del juego: la ventana REAL si la UI es "igual que el render" (dinamico), o su tamaño
    // FIJO si no. Lo leen TANTO el script (TamLienzo) como el overlay (UI2D_TamanoVentana) -> coinciden.
    { UI* ug = UIJuego();
      if (ug && ug->igualQueRender) { g_gameRenderW = (float)winW; g_gameRenderH = (float)winH; }
      else if (ug) { g_gameRenderW = ug->ancho; g_gameRenderH = ug->alto; } }
    W3dPantallaAlto = winH;
    gfx::Viewport(0, 0, winW, winH);
    gfx::ClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    gfx::Clear(gfx::ColorBuffer | gfx::DepthBuffer);

    gfx::MatrixMode(gfx::Projection); gfx::LoadIdentity();
    gfx::Ortho(0, winW, winH, 0, -1, 1);
    gfx::MatrixMode(gfx::ModelView); gfx::LoadIdentity();
    // estado 2D (el MISMO que el Editor2D antes del overlay): sin depth/luz/niebla/
    // cull, y con el vertex array activo (los rects y el texto lo esperan asi)
    gfx::Disable(gfx::DepthTest); gfx::Disable(gfx::Lighting);
    gfx::Disable(gfx::Fog); gfx::Disable(gfx::CullFace);
    gfx::Disable(gfx::Blend); gfx::Disable(gfx::Texture2D);
    gfx::DisableArray(gfx::NormalArray); gfx::DisableArray(gfx::ColorArray);
    gfx::DisableArray(gfx::TexCoordArray); gfx::EnableArray(gfx::VertexArray);

    float lw, lh; TamLienzo(&lw, &lh);
    if (lw < 1) lw = 1; if (lh < 1) lh = 1;
    float esc = (float)winW / lw; if ((float)winH / lh < esc) esc = (float)winH / lh;
    float dw = lw * esc, dh = lh * esc;
    float x0 = (winW - dw) * 0.5f, y0 = (winH - dh) * 0.5f;
    gUltEsc = esc; gUltX0 = x0; gUltY0 = y0;   // para convertir el toque a lienzo

    UI2D_BaseRecorte(0, 0, winW, winH);
    UI2D_DibujarOverlay(x0, y0, dw, dh, esc, 0);

}

// ---- input ----
void W3dGameToque(int winX, int winY, bool activo) {
    float lw, lh; TamLienzo(&lw, &lh);
    float cx = 0, cy = 0;
    if (gUltEsc > 0.0001f) {
        cx = (winX - gUltX0) / gUltEsc - lw * 0.5f;
        cy = (winY - gUltY0) / gUltEsc - lh * 0.5f;
    }
    W3dScriptToque(cx, cy, activo);
}
// MOUSE-OVER: posicion del mouse (sin clic) -> raton() en lua (resaltar la opcion bajo el cursor)
void W3dGameRaton(int winX, int winY, bool dentro) {
    float lw, lh; TamLienzo(&lw, &lh);
    float cx = 0, cy = 0;
    if (gUltEsc > 0.0001f) {
        cx = (winX - gUltX0) / gUltEsc - lw * 0.5f;
        cy = (winY - gUltY0) / gUltEsc - lh * 0.5f;
    }
    W3dScriptRaton(cx, cy, dentro);
}
void W3dGameStick(int cual, float x, float y) { W3dScriptStick(cual, x, y); }
void W3dGameBoton(const char* nombre, bool v)  { W3dScriptBotonPad(nombre, v); }

#include <SDL2/SDL.h>
void W3dGameTecla(int sdlk, bool apretada) {
    const char* n = 0; char letra[2] = { 0, 0 };
    if (sdlk >= SDLK_a && sdlk <= SDLK_z) { letra[0] = (char)('a' + (sdlk - SDLK_a)); n = letra; }
    else if (sdlk == SDLK_UP)    n = "arriba";
    else if (sdlk == SDLK_DOWN)  n = "abajo";
    else if (sdlk == SDLK_LEFT)  n = "izquierda";
    else if (sdlk == SDLK_RIGHT) n = "derecha";
    else if (sdlk == SDLK_SPACE) n = "espacio";
    else if (sdlk == SDLK_RETURN || sdlk == SDLK_KP_ENTER) n = "enter";
    else if (sdlk >= SDLK_0 && sdlk <= SDLK_9) { letra[0] = (char)('0' + (sdlk - SDLK_0)); n = letra; }
    if (n) W3dScriptTecla(n, apretada);
}

// ---------------------------------------------------------------------------
//  STUBS 3D: el pong es 2D puro (rects + texto). El Core linkea Mesh (Objects/
//  W3dScript lo referencian) pero el juego NUNCA crea uno -> estos metodos de
//  edit-mode viven en el editor (main/); aca se stubean para satisfacer el
//  linker. Un juego 3D linkearia el editor/edit real en su lugar.
// ---------------------------------------------------------------------------
#ifdef W3D_GAME_NO_TEX
#include "objects/Mesh.h"
// PuntoFoco es la KEY FUNCTION de Mesh (1er virtual): definirla aca emite la
// vtable de Mesh en el runtime (vive en main/edit/ del editor, que no linkeamos)
Vector3 Mesh::PuntoFoco() const { return Vector3(0,0,0); }
float   Mesh::RadioFoco() const { return 0.0f; }
void Mesh::EditSeleccionarTodo(bool) {}
void Mesh::EditInvertir() {}
void Mesh::LiberarModificadores() {}
void Mesh::LiberarMallaModificada() {}
void Mesh::LiberarCapas(bool) {}
void Mesh::InvalidarEdit() {}
void Mesh::RenderEditOverlay() {}
#endif
