#ifndef W3DRUN_H
#define W3DRUN_H
#include <string>

// ============================================================================
//  w3drun — el RUNTIME de un juego Whisk3D 2D (UI + scripts lua), SIN el editor.
//
//  Un juego hecho en el Editor 2D es: un arbol de UI (.w3dui) + uno o varios
//  scripts lua colgados de un objeto, con sus propiedades expuestas resueltas
//  a objetos de la escena. Este runtime reusa EXACTAMENTE el mismo render 2D y
//  el mismo interprete lua del editor (UIOverlay + W3dScript del Core), asi que
//  el juego se ve y se comporta igual que en el editor, pero corre solo.
//
//  Uso (ver ui/whiskpaddle/main.cpp):
//     W3dGameFontPngSet("res/font.png");     // la tipografia pixel
//     W3dGameCargarUI("whiskpaddle.w3dui");
//     W3dGameScript("whiskpaddle.lua");       // agrega un script
//     W3dGameRef("jugador1", "Pala 1");       // sus referencias (por nombre)
//     W3dGameInicio();                        // resuelve refs + llama inicio()
//     ... por frame:  W3dGameActualizar(dt);  W3dGameRender(w, h);
//     ... input:      W3dGameTecla(sdlk, down);  W3dGameStick(0, x, y);
//
//  El runtime corre en PC (OpenGL) y en la web (WebGL): el mismo binario/wasm.
// ============================================================================

// ruta de font.png (la tipografia pixel del skin). Llamar ANTES de cargar la UI.
void W3dGameFontPngSet(const std::string& ruta);

// carga el arbol de la interfaz (.w3dui). false si no pudo.
// CAMINO LEGACY (una sola escena): despues se le agregan scripts con W3dGameScript/W3dGameRef.
bool W3dGameCargarUI(const std::string& ruta);

// MULTI-ESCENA: carga UNA escena mas (un .w3dui) y la ACUMULA (sin pisar las anteriores). Sus
// scripts salen del propio .w3dui (no se agregan con W3dGameScript). Llamar una por escena.
bool W3dGameCargarEscena(const std::string& ruta);
// nombre de la escena que ARRANCA (el "nombre" de su .w3dui). Sin esto arranca la primera.
void W3dGameEscenaInicial(const std::string& nombre);

// agrega un script lua (se resuelve al llamar W3dGameInicio)
void W3dGameScript(const std::string& rutaLua);
// asigna una propiedad expuesta del ULTIMO script: el nombre del objeto
// referenciado, o la opcion elegida (los desplegables)
void W3dGameRef(const std::string& prop, const std::string& valor);

// resuelve las referencias por nombre y llama inicio() de cada script
void W3dGameInicio();
// un frame de logica (dt en segundos)
void W3dGameActualizar(float dt);
// dibuja la UI centrada y escalada para entrar en (winW x winH)
void W3dGameRender(int winW, int winH);

// ZONA SEGURA: insets (notch/barras) en px de ventana. El fondo llena toda la ventana; la UI se acota
// a este rect. La plataforma lo actualiza (ej. Android, del display cutout). PC/web: 0 (sin recorte).
void W3dGameSafeArea(int l, int t, int r, int b);
// true si el juego pidio cerrarse (lua salir()); la plataforma corta su loop.
bool W3dGameQuierePararse(void);

// ---- input ----
void W3dGameTecla(int sdlk, bool apretada);   // teclado (SDL keycode)
// toque/arrastre en PIXELES DE VENTANA (se convierte al lienzo con el escalado
// del ultimo W3dGameRender); activo=false al soltar. Llega a lua como toque()
void W3dGameToque(int winX, int winY, bool activo);
// multi-touch: dedo idx (0-based) en px de ventana -> dedo(idx+1) en lua (2 jugadores tactiles)
void W3dGameDedo(int idx, int winX, int winY, bool activo);
void W3dGameRaton(int winX, int winY, bool dentro); // mouse-over (posicion sin clic) -> raton() en lua
void W3dGameStick(int cual, float x, float y);// stick analogico (0 izq, 1 der)
void W3dGameBoton(const char* nombre, bool v);// boton del gamepad ("a".."y")

#endif // W3DRUN_H
