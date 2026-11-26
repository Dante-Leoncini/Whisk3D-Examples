LOCAL_PATH := $(call my-dir)
MY_PATH := $(LOCAL_PATH)

# ============================================================================
#  jni/Android.mk - build nativo del WhiskPaddle (demo Whisk3D) via ndk-build.
#  MISMO set de fuentes que platform/web/build_web.sh (backend GLES2 de shaders,
#  runtime del juego), pero empaquetado como APK contra el SDL2 del submodulo del
#  repo Whisk3D. El .lua y el .w3dui van en los assets del APK (los lee el Core
#  con el AAssetManager).
# ============================================================================

# jni/ vive en Whisk3D-Examples/ui/whiskpaddle/platform/android/jni -> Whisk3decosystem esta 6 niveles arriba
ROOT  := $(MY_PATH)/../../../../../..
W3D   := $(ROOT)/Whisk3D
EXAMP := $(ROOT)/Whisk3D-Examples
CORE  := $(W3D)/libs/Whisk3DCore
UILIB := $(W3D)/libs/WhiskUI

# 1) SDL2 real: el Android.mk que YA trae thirdparty/SDL2 (pisa LOCAL_PATH, se restaura abajo)
include $(W3D)/thirdparty/SDL2/Android.mk

# 2) modulo del juego, linkeado contra esa libSDL2.so
LOCAL_PATH := $(MY_PATH)
include $(CLEAR_VARS)
LOCAL_MODULE := main
# ^ "main" por convencion de SDLActivity (System.loadLibrary("main") -> libmain.so).

# El almacen de recursos, los datos compartidos, los flipbooks y los binds de cuerpos rigidos /
# colision contra mallas van SIEMPRE (el Core los nombra sin ifdef): misma lista que kFuentesBase
# de main/io/CompilarJuego.cpp, la de los juegos que compila el editor.
SRC_FILES := \
  $(EXAMP)/ui/whiskpaddle/platform/main.cpp \
  $(EXAMP)/game/w3drun.cpp \
  $(CORE)/gles2/w3dGraphicsGLES2.cpp $(CORE)/gfx/w3dTexture.cpp \
  $(CORE)/io/w3dFilesystem.cpp $(CORE)/io/w3dCompress.cpp \
  $(CORE)/io/W3dTexto.cpp $(CORE)/io/W3dMalla.cpp $(CORE)/io/W3dMallaBin.cpp \
  $(CORE)/io/W3dRecursos.cpp \
  $(CORE)/base/w3dlog.cpp $(CORE)/base/W3dInteractionState.cpp $(CORE)/base/W3dConfig.cpp \
  $(CORE)/math/Vector3.cpp $(CORE)/math/Quaternion.cpp $(CORE)/math/Matrix4.cpp \
  $(CORE)/objects/Objects.cpp $(CORE)/objects/Mesh.cpp $(CORE)/objects/Light.cpp \
  $(CORE)/objects/Materials.cpp $(CORE)/objects/Textures.cpp $(CORE)/objects/CameraBase.cpp \
  $(CORE)/objects/Armature.cpp $(CORE)/objects/RenderColors.cpp \
  $(CORE)/objects/MallaDatos.cpp $(CORE)/objects/MallaRecurso.cpp $(CORE)/objects/TexturaCache.cpp \
  $(CORE)/animation/Animation.cpp $(CORE)/animation/VertexAnimation.cpp \
  $(CORE)/animation/SkeletalAnimation.cpp $(CORE)/animation/Armature2DAnimation.cpp \
  $(CORE)/animation/W3dAnimSet.cpp \
  $(CORE)/animation/Flipbook.cpp \
  $(CORE)/script/W3dScript.cpp \
  $(CORE)/physics/W3dRigido.cpp $(CORE)/physics/W3dColMalla.cpp \
  $(CORE)/physics/W3dHitbox.cpp \
  $(CORE)/physics/W3dFisica.cpp \
  $(CORE)/audio/W3dAudio.cpp $(CORE)/audio/W3dAudioSDL.cpp \
  $(UILIB)/text/W3dFont.cpp $(UILIB)/text/bitmapText.cpp $(UILIB)/text/font.cpp \
  $(UILIB)/draw/glesdraw.cpp $(UILIB)/draw/W3dAtlasPacker.cpp \
  $(UILIB)/core/UI.cpp $(UILIB)/theme/colores.cpp \
  $(W3D)/main/render/UIOverlay.cpp $(W3D)/main/script/BindsJuego.cpp \
  $(W3D)/main/W3dEscena.cpp \
  $(W3D)/main/io/UI2DFormato.cpp $(W3D)/main/io/Fuente2D.cpp \
  $(W3D)/main/io/Textura2D.cpp \
  $(filter-out %/lua.c %/luac.c,$(wildcard $(W3D)/thirdparty/lua/src/*.c))

# ndk-build quiere LOCAL_SRC_FILES relativo a LOCAL_PATH (acepta '..')
LOCAL_SRC_FILES := $(patsubst $(MY_PATH)/%,%,$(SRC_FILES))

LOCAL_C_INCLUDES := \
  $(MY_PATH)/shim \
  $(EXAMP)/game \
  $(W3D) $(W3D)/libs $(W3D)/main $(W3D)/main/render $(W3D)/main/io \
  $(CORE) $(CORE)/base $(CORE)/gfx $(CORE)/io $(CORE)/math $(CORE)/objects \
  $(CORE)/script $(CORE)/animation $(CORE)/thirdparty \
  $(UILIB) $(UILIB)/text $(UILIB)/draw $(UILIB)/core $(UILIB)/theme $(UILIB)/widgets \
  $(W3D)/thirdparty/lua/src \
  $(W3D)/thirdparty/SDL2/include

LOCAL_CPP_FEATURES := exceptions rtti
# lua (C): Android es linux -> posix
# NOTA 32-bit (armeabi-v7a): el NDK 27 fuerza -D_FILE_OFFSET_BITS=64, y en 32 bits
# eso deja fseeko/ftello recien disponibles en API 24 (aca APP_PLATFORM=android-21),
# por lo que liolib.c no compila. Forzamos las macros de lua a la version portable
# fseek/ftell (long): sirve en 32 y 64 bits y alcanza de sobra para scripts/assets
# chicos (no manejamos archivos >2GB). LOCAL_CFLAGS solo afecta a los .c de lua.
LOCAL_CFLAGS   := -DLUA_USE_POSIX \
  '-Dl_fseek(f,o,w)=fseek(f,o,w)' '-Dl_ftell(f)=ftell(f)' -Dl_seeknum=long
# C++: backend shaders GLES2 + runtime del juego + stb + sin texturas de usuario + audio
LOCAL_CPPFLAGS := -std=c++17 -DW3D_GLES2 -DW3D_GAME_RUNTIME -DW3D_GAME_NO_TEX -DW3D_STB_IMPL -DW3D_ENABLE_AUDIO

LOCAL_SHARED_LIBRARIES := SDL2
LOCAL_LDLIBS := -lGLESv2 -llog -landroid

include $(BUILD_SHARED_LIBRARY)
