// ============================================================================
//  w3drun.cpp — ver w3drun.h. El runtime del juego 2D + los globals y stubs
//  que las piezas reusadas del editor esperan (asi el juego linkea sin arrastrar
//  todo el editor).
// ============================================================================
#include "w3drun.h"
#include "objects/Objects.h"
#include "objects/UI.h"
#include "objects/Texto2D.h"
#include "objects/Imagen2D.h"
#include "objects/Elemento2D.h"
#include "io/UI2DFormato.h"
#include "render/UIOverlay.h"
#include "script/W3dScript.h"
#include "script/BindsJuego.h"   // los binds 2D de juego COMPARTIDOS con el editor (Play)
#include "physics/W3dFisica.h"   // paso de fisica del Core (el MISMO que corre el Play del editor)
#include "W3dEscena.h"           // motor multi-escena COMPARTIDO con el editor (activa / cambiarEscena)
#include "w3dGraphics.h"
#include "WhiskUI/draw/glesdraw.h"   // W3dPantallaAlto (flip Y del scissor)

extern "C" {
#include "lua.h"
#include "lauxlib.h"
}

#include <vector>
#include <string>
#include <math.h>   // fabsf() para chocan()

namespace gfx = w3dEngine;

// ---------------------------------------------------------------------------
//  GLOBALS que las piezas reusadas del editor esperan (definidas ACA para el
//  runtime; en el editor las definen variables.cpp / OpcionesRender.cpp).
// ---------------------------------------------------------------------------
bool  g_redraw = true;                 // el editor lo usa para redibujar por evento
float g_gameRenderW = 480.0f;          // tamano de la "ventana de render" del juego
float g_gameRenderH = 480.0f;          // (UIOverlay lo lee via UI2D_TamanoVentana)

// ZONA SEGURA: insets (notch/barras) en px de ventana, los pone la plataforma (Android). El fondo (clear)
// llena TODA la ventana (se ve detras del notch); la UI se acota a este rect. 0 = sin recorte (PC/web).
static float g_safeL = 0, g_safeT = 0, g_safeR = 0, g_safeB = 0;
void W3dGameSafeArea(int l, int t, int r, int b) {
    g_safeL = (float)(l < 0 ? 0 : l); g_safeT = (float)(t < 0 ? 0 : t);
    g_safeR = (float)(r < 0 ? 0 : r); g_safeB = (float)(b < 0 ? 0 : b);
}
// pedido de cierre del juego (lua salir()); la plataforma lo consulta cada frame y corta el loop.
// El flag vive en BindsJuego (donde esta el bind salir()), compartido con el editor.
bool W3dGameQuierePararse() { return BindsJuegoQuierePararse(); }

// la tipografia pixel (font.png); Fuente2D la pide con W3dGameFontPng()
static std::string gFontPng = "font.png";
void W3dGameFontPngSet(const std::string& ruta) { gFontPng = ruta; }
const char* W3dGameFontPng() { return gFontPng.c_str(); }

// ---------------------------------------------------------------------------
//  STUBS de imagen/video: el juego es solo rectangulos + texto, no usa texturas
//  ni video. UIOverlay igual referencia estas funciones (para los otros tipos),
//  asi que se stubean -> el runtime no arrastra ffmpeg ni el cache de video.
//  (Un juego con imagenes linkearia el Textura2D/Video2DCache reales en su lugar.)
// ---------------------------------------------------------------------------
#ifdef W3D_GAME_NO_TEX
// el juego SI usa una imagen (el parlante) -> Textura2DObtener/RutaDecodificable REALES (Textura2D.cpp en
// el build). Pero NO usa video: se stubea solo el video para no arrastrar el cache de video / ffmpeg.
struct VideoPreview;
const VideoPreview* Video2DPreview(const std::string&) { return 0; }
unsigned W3dMsAhora() { return 0; }
#endif

// ---------------------------------------------------------------------------
//  BINDINGS 2D del juego: AHORA viven en BindsJuego.{h,cpp} (compartidos con el
//  editor), y se registran via W3dScriptSetBindExtra(BindsJuegoRegistrar) en
//  W3dGameCargarUI. Aca solo queda lo PROPIO del runtime: el UI del juego, el
//  mapeo ventana<->lienzo del input, y el alimentar el estado de BindsJuego.
// ---------------------------------------------------------------------------
static UI* UIJuego() {
    // con el juego corriendo manda la escena ACTIVA (su lienzo/tamano); antes de
    // W3dGameInicio (gActiva NULL) cae a la primera UI de la escena.
    UI* act = W3dEscenaActiva();
    if (act) return act;
    if (!SceneCollection) return 0;
    for (size_t i = 0; i < SceneCollection->Childrens.size(); i++)
        if (SceneCollection->Childrens[i]->getType() == ObjectType::ui)
            return (UI*)SceneCollection->Childrens[i];
    return 0;
}

// mapeo del ULTIMO render (ventana -> lienzo) para el INPUT (WinALienzo): escala + offset del letterbox /
// zona segura. Lo fija W3dGameRender cada frame (y ademas se lo pasa a BindsJuego para areaSegura/cajaUI).
static float gUltEsc = 1.0f, gUltX0 = 0.0f, gUltY0 = 0.0f;

// ---------------------------------------------------------------------------
//  Estado del juego cargado
// ---------------------------------------------------------------------------
static Object* gDuenio = 0;   // el objeto que lleva los scripts (la UI misma)

bool W3dGameCargarUI(const std::string& ruta) {
    // la RAIZ de la escena (el editor usa un Scene; el runtime, un Object pelado):
    // los objetos nuevos se cuelgan de aca, y UI2DCargar necesita que exista
    if (!SceneCollection) SceneCollection = new Object(0, "Scene");
    W3dScriptSetBindExtra(BindsJuegoRegistrar);   // registrar la API 2D compartida antes de cargar scripts
    UI* u = UI2DCargar(ruta);
    if (!u) return false;
    gDuenio = u;
    g_gameRenderW = u->ancho; g_gameRenderH = u->alto;
    return true;
}

// MULTI-ESCENA: carga UNA escena mas (un .w3dui) y la ACUMULA en SceneCollection (UI2DCargar
// se auto-cuelga sin pisar las anteriores). Sus scripts salen del propio .w3dui (array root
// "scripts"), no se agregan con W3dGameScript. Llamar una vez por escena, antes de W3dGameInicio.
bool W3dGameCargarEscena(const std::string& ruta) {
    if (!SceneCollection) SceneCollection = new Object(0, "Scene");
    W3dScriptSetBindExtra(BindsJuegoRegistrar);   // la API 2D compartida (incluye cambiarEscena)
    UI* u = UI2DCargar(ruta);
    if (!u) return false;
    return true;
}
// nombre de la escena que ARRANCA (el campo "nombre" de su .w3dui). Sin esto arranca la primera.
void W3dGameEscenaInicial(const std::string& nombre) { W3dEscenaSetInicial(nombre); }

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

// init de UN subarbol: carga+resuelve+inicio() de cada objeto con script (orden de arbol).
// Las refs se buscan dentro de la RAIZ de la escena del dueno (no en toda SceneCollection),
// para que no colisionen nombres repetidos entre escenas. reiniciar=true recrea los lua_State.
static void RuntimeInitSubtree(Object* o, bool reiniciar) {
    if (!o) return;
    if (o->scriptDatos && !o->scriptDatos->scripts.empty()) {
        if (reiniciar) W3dScriptDescargarDe(o);
        if (W3dScriptCargar(o)) {
            for (size_t e = 0; e < o->scriptDatos->scripts.size(); e++) {
                const W3dScriptEntrada& ent = o->scriptDatos->scripts[e];
                for (size_t r = 0; r < ent.refs.size(); r++) {
                    Object* obj = BuscarPorNombre(W3dEscenaRaizDe(o), ent.refs[r].second);
                    if (obj) W3dScriptResolverRef(o, (int)e, ent.refs[r].first, obj);
                    W3dScriptResolverOpcion(o, (int)e, ent.refs[r].first, ent.refs[r].second);
                }
            }
            W3dScriptInicio(o);
        }
    }
    for (size_t i = 0; i < o->Childrens.size(); i++)
        RuntimeInitSubtree(o->Childrens[i], reiniciar);
}
// callback de init de UNA escena (lo registra W3dEscenaSetInit): lo llama el motor
// al arrancar la inicial y en el init perezoso de cada escena destino de cambiarEscena().
static void RuntimeInitEscena(UI* u, bool reiniciar) { RuntimeInitSubtree((Object*)u, reiniciar); }

void W3dGameInicio() {
    W3dEscenaSetInit(RuntimeInitEscena);
    W3dEscenaRegistrarTodas();
    // inicial: la fijada con W3dGameEscenaInicial()/el .w3d; sino la escena del camino LEGACY
    // (gDuenio, W3dGameCargarUI); sino la primera registrada (fallback de W3dEscenaArrancar).
    std::string ini = W3dEscenaInicial();
    if (ini.empty() && gDuenio) ini = gDuenio->name;
    W3dEscenaSetInicial(ini);
    if (W3dEscenaHayEscenas()) W3dEscenaArrancar();   // muestra + inicia SOLO la escena inicial
    else if (gDuenio)          RuntimeInitSubtree(gDuenio, false);   // defensivo (no deberia pasar)
}

// corre actualizar() de los objetos con script del subarbol de la escena ACTIVA (y visibles).
static void RuntimeActualizarSubtree(Object* o, float dt) {
    if (!o) return;
    if (W3dEscenaEsDeActiva(o) && o->scriptDatos && !o->scriptDatos->scripts.empty())
        W3dScriptActualizar(o, dt);
    for (size_t i = 0; i < o->Childrens.size(); i++)
        RuntimeActualizarSubtree(o->Childrens[i], dt);
}

void W3dGameActualizar(float dt) {
    // FISICA del Core (velocidad + rebotes): PRIMERO se integran las posiciones y despues corren
    // los scripts, asi el script ve la posicion nueva y resuelve el choque (rebotar) en el MISMO
    // frame. Mismo orden y mismo dt que el Play del editor (TickReal en main/script/SimJuego.cpp).
    W3dFisicaPaso(dt);
    UI* act = W3dEscenaActiva();
    if (act)             RuntimeActualizarSubtree((Object*)act, dt);
    else if (gDuenio)    W3dScriptActualizar(gDuenio, dt);   // legacy antes de Inicio (no deberia pasar)
    // SNAPSHOT del estado apretado para el flanco de apretado() del PROXIMO frame: se hace DESPUES de correr
    // los scripts, asi todas las llamadas a apretado() de ESTE frame ven el mismo "estado anterior".
    BindsJuegoSnapshotPunteros();
    // el cambio pedido por cambiarEscena() se aplica ACA, al final del frame (no en el callback:
    // no mutar la iteracion de arriba). El init perezoso de la escena destino corre en este punto.
    W3dEscenaAplicarPendiente();
}

// dibuja la UI en 2D (ortho), centrada y escalada para ENTRAR en la ventana
void W3dGameRender(int winW, int winH) {
    if (winW < 1) winW = 1; if (winH < 1) winH = 1;
    // el lienzo del juego: la ventana REAL si la UI es "igual que el render" (dinamico), o su tamaño
    // FIJO si no. Lo leen TANTO el script (TamLienzo) como el overlay (UI2D_TamanoVentana) -> coinciden.
    // zona SEGURA (descuenta notch/barras): la UI se dibuja adentro; el fondo (clear) llena TODA la ventana,
    // asi el color de fondo se ve DETRAS del notch pero la UI no queda tapada.
    float sl = g_safeL, st = g_safeT, sr = g_safeR, sb = g_safeB;
    if (sl + sr >= winW) { sl = 0; sr = 0; }
    if (st + sb >= winH) { st = 0; sb = 0; }
    float safeW = (float)winW - sl - sr, safeH = (float)winH - st - sb;
    UI* ug = UIJuego();
    bool igual = (ug && ug->igualQueRender);
    if (igual) { g_gameRenderW = safeW; g_gameRenderH = safeH; }
    else if (ug) { g_gameRenderW = ug->ancho; g_gameRenderH = ug->alto; }
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

    float lw, lh; UI2D_TamanoLienzo(&lw, &lh);
    if (lw < 1) lw = 1; if (lh < 1) lh = 1;
    float esc, dw, dh, x0, y0;
    if (igual) {
        // lienzo = rect SEGURO, 1:1 (sin letterbox): la UI entra justo en la zona segura
        esc = 1.0f; dw = safeW; dh = safeH; x0 = sl; y0 = st;
    } else {
        // UI de tamaño fijo: encajar (letterbox) DENTRO del rect seguro
        esc = safeW / lw; if (safeH / lh < esc) esc = safeH / lh;
        dw = lw * esc; dh = lh * esc;
        x0 = sl + (safeW - dw) * 0.5f; y0 = st + (safeH - dh) * 0.5f;
    }
    gUltEsc = esc; gUltX0 = x0; gUltY0 = y0;   // para convertir el toque a lienzo (input, WinALienzo)

    UI2D_BaseRecorte(0, 0, winW, winH);
    // pedirle al overlay las posiciones RESUELTAS (para que cajaUI() las lea desde el lua)
    std::vector<UI2DPos> posiciones;
    UI2D_DibujarOverlay(x0, y0, dw, dh, esc, &posiciones);
    // alimentar a BindsJuego el mapeo + el rect SEGURO (px de ventana) + las posiciones resueltas,
    // para que areaSegura()/cajaUI() lean lo mismo que se dibujo (IGUAL que en el editor via SimJuego)
    BindsJuegoRender(esc, x0, y0, sl, st, safeW, safeH, &posiciones);
}

// ---- input ----
// convierte px de VENTANA a px del LIENZO (centro en 0,0) con el escalado del ultimo render. Lo comparten
// las 3 entradas de puntero (toque/dedo/raton): solo cambian a que funcion del script le pasan cx,cy.
static void WinALienzo(int winX, int winY, float* cx, float* cy) {
    float lw, lh; UI2D_TamanoLienzo(&lw, &lh);
    if (lw < 1.0f) lw = 1.0f; if (lh < 1.0f) lh = 1.0f;
    *cx = 0; *cy = 0;
    if (gUltEsc > 0.0001f) {
        *cx = (winX - gUltX0) / gUltEsc - lw * 0.5f;
        *cy = (winY - gUltY0) / gUltEsc - lh * 0.5f;
    }
}
void W3dGameToque(int winX, int winY, bool activo) {
    float cx, cy; WinALienzo(winX, winY, &cx, &cy); W3dScriptToque(cx, cy, activo);
    // cache en LIENZO para apretado()/etc (el toque = dedo/slot 0)
    BindsJuegoPunto(0, cx, cy, activo);
}
// MULTI-TOUCH: un dedo idx (0-based) -> dedo(idx+1) en lua (2 jugadores tactiles, cada uno con su dedo)
void W3dGameDedo(int idx, int winX, int winY, bool activo) {
    float cx, cy; WinALienzo(winX, winY, &cx, &cy); W3dScriptDedo(idx, cx, cy, activo);
    BindsJuegoPunto(idx, cx, cy, activo);
}
// MOUSE-OVER: posicion del mouse SIN clic -> raton() en lua (resaltar la opcion bajo el cursor)
void W3dGameRaton(int winX, int winY, bool dentro) {
    float cx, cy; WinALienzo(winX, winY, &cx, &cy); W3dScriptRaton(cx, cy, dentro);
    // cache en LIENZO para el overlay (borde de hover de los botones). Solo los eventos
    // de MOUSE llegan aca: en tactil no se alimenta y no hay hover.
    BindsJuegoRaton(cx, cy, dentro);
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
//  STUBS 3D: el juego es 2D puro (rects + texto). El Core linkea Mesh (Objects/
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
