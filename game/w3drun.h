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
//  Uso (ver ui/pong/main.cpp):
//     W3dGameFontPngSet("res/font.png");     // la tipografia pixel
//     W3dGameCargarUI("pong.w3dui");
//     W3dGameScript("pong.lua");              // agrega un script
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
bool W3dGameCargarUI(const std::string& ruta);

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

// ---- input ----
void W3dGameTecla(int sdlk, bool apretada);   // teclado (SDL keycode)
// toque/arrastre en PIXELES DE VENTANA (se convierte al lienzo con el escalado
// del ultimo W3dGameRender); activo=false al soltar. Llega a lua como toque()
void W3dGameToque(int winX, int winY, bool activo);
void W3dGameRaton(int winX, int winY, bool dentro); // mouse-over (posicion sin clic) -> raton() en lua
void W3dGameStick(int cual, float x, float y);// stick analogico (0 izq, 1 der)
void W3dGameBoton(const char* nombre, bool v);// boton del gamepad ("a".."y")

#endif // W3DRUN_H
