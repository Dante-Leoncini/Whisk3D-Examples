# Plantilla Android de "Compilar juego"

Este es el proyecto Android que usa el editor Whisk3D para compilar CUALQUIER juego a
Android (tarjeta **Juego** > Plataforma Android > **Compilar juego**). El editor lo busca en
`Whisk3D-Examples/ui/whiskpaddle/platform/android`, al lado del repo de Whisk3D.

Lo que trae:

- gradle (`build.gradle`, `settings.gradle`, `gradlew`) y la app (`app/`): la Activity de
  SDL, el `AndroidManifest.xml` y los iconos de fabrica.
- `jni/`: `Application.mk` y los headers de compatibilidad (`shim/`).

Para cada juego, el editor copia esta carpeta a `platform-build/android/androidprj/`, le
pone el nombre del juego (`applicationId` y titulo), su icono y su orientacion, genera su
`jni/Android.mk` (el runtime `game/` + el Core + el `main.cpp` del juego) y arma el APK con
`ndk-build` + `./gradlew assembleDebug`. El APK queda en `build/android/` del juego.

Requisitos: el NDK y el SDK de Android (`local.properties` con `sdk.dir`) y el JDK 17
(`JAVA_HOME`). Lo que se genera al compilar (`app/distribution/`, `libs/`, `obj/`,
`app/src/main/assets/`, `app/src/main/jniLibs/`) no va al repo.
