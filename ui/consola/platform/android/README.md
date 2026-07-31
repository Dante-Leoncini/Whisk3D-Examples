# Consola (Whisk3D) en Android

Backend GLES2 (shaders) + SDL2, empaquetado como APK con Gradle.

## Requisitos

- **Android NDK** (define `ANDROID_NDK` o dejalo en `/opt/android-ndk`).
- **JDK 17** + el `gradlew` que ya viene en `platform/android/`. Gradle necesita `JAVA_HOME` apuntando al JDK
  (si no, falla con *"JAVA_HOME is not set"*), por ejemplo:
  `export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64`
- El SDK en `local.properties` (`sdk.dir=...`).

## Compilar

```bash
bash build_android.sh                 # APK fat (armeabi-v7a + arm64-v8a), modo DEBUG
bash build_android.sh arm64-v8a      # una sola ABI
MODO=prod bash build_android.sh      # APK de PRODUCCION (W3D_DEV_LOG=0)
```

El script:
1. Copia `consola.w3dui` + `consola.lua` + `font.png` a los assets del APK.
2. Compila `libmain.so` con `ndk-build` (limpia `obj/` si cambio el MODO).
3. Empaqueta con `./gradlew assembleDebug` (firmado con el keystore de debug).

## Modo debug vs produccion

`MODO=debug` (default) define `W3D_DEV_LOG=1`: los mensajes van a logcat
(`adb logcat -s Whisk3D`), el ring buffer alimenta el panel y el boton DEPURAR
esta visible. `MODO=prod` define `W3D_DEV_LOG=0`: nada de eso existe en el
binario (ver `README.md` de la raiz del ejemplo).

## Salida

El APK queda en `app/distribution/android/app/outputs/apk/debug/whisk3d-consola-<fecha>-Android.apk`.
