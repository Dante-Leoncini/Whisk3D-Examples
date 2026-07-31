package com.whisk3d.consola;

import android.os.Build;
import android.os.Bundle;
import android.view.DisplayCutout;
import android.view.View;
import android.view.WindowManager;

import org.libsdl.app.SDLActivity;

// Consola (demo Whisk3D) standalone en Android. Extiende SDLActivity (SDL2): carga libSDL2.so + libmain.so
// (el juego, con su main() nativo). Ademas configura pantalla completa DETRAS del notch y expone al nativo
// los insets de la zona segura (para que la UI no quede tapada por el notch/barras).
public class ConsolaActivity extends SDLActivity {
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

        // API 28+: permitir que la ventana se extienda DETRAS del notch (el fondo llena la pantalla;
        // la UI se acota a la zona segura via los insets de abajo).
        if (Build.VERSION.SDK_INT >= 28) {
            WindowManager.LayoutParams lp = getWindow().getAttributes();
            lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES;
            getWindow().setAttributes(lp);
        }

        // capturar los insets seguros (el recorte del notch) cuando el sistema los aplica. Corre en el
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
