package com.whisk3d.calculadora;

import android.os.Build;
import android.os.Bundle;
import android.view.DisplayCutout;
import android.view.View;

import org.libsdl.app.SDLActivity;

// Calculadora (demo Whisk3D) standalone en Android. Extiende SDLActivity (SDL2): carga libSDL2.so + libmain.so
// (el juego, con su main() nativo). Corre en VENTANA NORMAL (con barra de estado y navegacion,
// sin fullscreen) y expone al nativo los insets de la zona segura (normalmente 0 en este modo).
public class CalculadoraActivity extends SDLActivity {
    // {izquierda, arriba, derecha, abajo} en px de ventana. volatile: lo escribe el hilo de UI y lo lee el nativo.
    private volatile int[] safeInsets = new int[]{0, 0, 0, 0};

    @Override
    protected String[] getLibraries() {
        return new String[]{
                "SDL2",
                "main",
        };
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // VENTANA NORMAL (no fullscreen, no detras del notch): la calculadora convive con la
        // barra de estado y la de navegacion (ver styles.xml; el main.cpp tampoco pide
        // fullscreen SDL). La barra de estado ocupa la franja del notch, asi que no hay
        // cutout que esquivar: los insets del listener de abajo quedan en 0 y el juego usa
        // el lienzo entero (areaSegura() = pantalla completa de la ventana).

        // capturar los insets seguros por si algun dispositivo igual reporta un recorte. Corre en el
        // hilo de UI; el nativo solo LEE el array cacheado (getSafeInsets), sin tocar vistas desde su hilo.
        final View decor = getWindow().getDecorView();
        decor.setOnApplyWindowInsetsListener((v, insets) -> {
            int l = 0, t = 0, r = 0, b = 0;
            if (Build.VERSION.SDK_INT >= 28) {
                DisplayCutout c = insets.getDisplayCutout();
                if (c != null) {
                    l = c.getSafeInsetLeft();  t = c.getSafeInsetTop();
                    r = c.getSafeInsetRight(); b = c.getSafeInsetBottom();
                }
            }
            safeInsets = new int[]{ l, t, r, b };
            return insets;
        });
    }

    // llamado desde el nativo (JNI) para acotar la UI a la zona segura. {izq, arriba, der, abajo} en px.
    public int[] getSafeInsets() {
        return safeInsets;
    }
}
