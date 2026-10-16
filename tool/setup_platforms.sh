#!/usr/bin/env bash
# Gera as pastas de plataforma que faltam e aplica o ID e o nome do app.
# Uso: bash tool/setup_platforms.sh   (rodado pelo GitHub Actions)
set -euo pipefail

flutter create --org br.com.pocketstage --project-name pocketstage_midia \
  --platforms android,ios,windows,macos .

ID='br.com.pocketstage.midia'
NOME='PocketStage Mídia'

troca() { # arquivo, padrão, substituto
  [ -f "$1" ] || return 0
  perl -0pi -e "s/$2/$3/g" "$1"
}

for f in android/app/build.gradle android/app/build.gradle.kts; do
  troca "$f" 'applicationId\s*=?\s*"[^"]*"' "applicationId = \"$ID\""
done
troca android/app/src/main/AndroidManifest.xml 'android:label="[^"]*"' "android:label=\"$NOME\""

troca ios/Runner.xcodeproj/project.pbxproj 'br\.com\.pocketstage\.pocketstage[_]?[Mm]idia' "$ID"
troca ios/Runner/Info.plist '(<key>CFBundleDisplayName<\/key>\s*<string>)[^<]*' "\${1}$NOME"

troca macos/Runner/Configs/AppInfo.xcconfig 'PRODUCT_BUNDLE_IDENTIFIER = .*' "PRODUCT_BUNDLE_IDENTIFIER = $ID"

# Android: a mesa nativa é br.com.pocketstage.midia.MainActivity (telão HDMI + serviço de palco)
find android/app/src/main/kotlin android/app/src/main/java -name 'MainActivity.*' 2>/dev/null \
  | grep -v 'br/com/pocketstage/midia/' | xargs -r rm -f
MAN=android/app/src/main/AndroidManifest.xml
troca "$MAN" 'android:name="\.MainActivity"' 'android:name="br.com.pocketstage.midia.MainActivity"'
if ! grep -q 'ServicoPalco' "$MAN"; then
  perl -0pi -e 's#<application#<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>\n    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK"/>\n    <uses-permission android:name="android.permission.WAKE_LOCK"/>\n    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n    <application#' "$MAN"
  perl -0pi -e 's#</application>#    <service android:name="br.com.pocketstage.midia.ServicoPalco" android:exported="false" android:foregroundServiceType="mediaPlayback"/>\n        <activity android:name="br.com.pocketstage.midia.TelaoActivity" android:exported="false" android:theme="\@style/NormalTheme" android:resizeableActivity="true" android:taskAffinity="br.com.pocketstage.midia.telao" android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode" android:hardwareAccelerated="true" android:windowSoftInputMode="adjustResize"/>\n    </application>#' "$MAN"
fi

# Android: assinatura fixa, se o segredo PSM_KEYSTORE_B64 existir no GitHub
GR=android/app/build.gradle.kts
if [ -n "${PSM_KEYSTORE_B64:-}" ] && [ -f "$GR" ] && ! grep -q 'create("psm")' "$GR"; then
  printf '%s' "$PSM_KEYSTORE_B64" | base64 -d > android/app/psm.jks
  perl -0pi -e 's#(\n\s*buildTypes\s*\{)#\n    signingConfigs {\n        create("psm") {\n            storeFile = file("psm.jks")\n            storePassword = System.getenv("PSM_KEY_PASSWORD")\n            keyAlias = "psm"\n            keyPassword = System.getenv("PSM_KEY_PASSWORD")\n        }\n    }$1#' "$GR"
  perl -0pi -e 's#signingConfig = signingConfigs\.getByName\("debug"\)#signingConfig = signingConfigs.getByName("psm")#' "$GR"
  echo "Assinatura fixa aplicada."
fi

# Android: ExoPlayer (players nativos com escolha da saída de som)
if [ -f "$GR" ] && ! grep -q 'media3-exoplayer' "$GR"; then
  printf '\ndependencies {\n    implementation("androidx.media3:media3-exoplayer:1.5.1")\n}\n' >> "$GR"
fi

# iOS: som em segundo plano
PL=ios/Runner/Info.plist
if [ -f "$PL" ] && ! grep -q 'UIBackgroundModes' "$PL"; then
  perl -0pi -e 's#</dict>\s*</plist>#\t<key>UIBackgroundModes</key>\n\t<array>\n\t\t<string>audio</string>\n\t</array>\n</dict>\n</plist>#' "$PL"
fi

# Computador: a janela do telão também carrega os plugins (media_kit, window_manager…)
FW=windows/runner/flutter_window.cpp
if [ -f "$FW" ] && ! grep -q 'DesktopMultiWindowSetWindowCreatedCallback' "$FW"; then
  perl -0pi -e 's|(#include "flutter_window.h"\r?\n)|$1#include "desktop_multi_window/desktop_multi_window_plugin.h"\n|' "$FW"
  perl -0pi -e 's|(RegisterPlugins\(flutter_controller_->engine\(\)\);\r?\n)|$1  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {\n    auto *flutter_view_controller = reinterpret_cast<flutter::FlutterViewController *>(controller);\n    RegisterPlugins(flutter_view_controller->engine());\n    PsmJanelaRegistrar(flutter_view_controller->engine()->messenger(), flutter_view_controller->view()->GetNativeWindow());\n  });\n|' "$FW"
  perl -0pi -e 's|(#include "flutter_window.h"\r?\n)|$1#include "psm_janela.h"\n|' "$FW"
  grep -q 'DesktopMultiWindowSetWindowCreatedCallback' "$FW" || { echo "ERRO: não consegui ajustar $FW"; case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) exit 1;; esac; }
fi
if [ -d windows/runner ]; then
  cp tool/windows/psm_janela.h tool/windows/psm_janela.cpp windows/runner/
  RC=windows/runner/CMakeLists.txt
  grep -q 'psm_janela.cpp' "$RC" || perl -0pi -e 's|("flutter_window.cpp"\r?\n)|$1  "psm_janela.cpp"\n|' "$RC"
  grep -q 'psm_janela.cpp' "$RC" || { echo "ERRO: não consegui ajustar $RC"; case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) exit 1;; esac; }
fi
MW=macos/Runner/MainFlutterWindow.swift
if [ -f "$MW" ] && ! grep -q 'FlutterMultiWindowPlugin' "$MW"; then
  perl -0pi -e 's|(import FlutterMacOS\r?\n)|$1import desktop_multi_window\n|' "$MW"
  perl -0pi -e 's|(RegisterGeneratedPlugins\(registry: flutterViewController\)\r?\n)|$1    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in\n      RegisterGeneratedPlugins(registry: controller)\n    }\n|' "$MW"
  grep -q 'FlutterMultiWindowPlugin' "$MW" || { echo "ERRO: não consegui ajustar $MW"; [ "$(uname -s)" = Darwin ] && exit 1; }
fi

# macOS: abrir e salvar arquivos escolhidos pelo operador
for f in macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements; do
  [ -f "$f" ] || continue
  grep -q 'files.user-selected.read-write' "$f" || \
    perl -0pi -e 's#</dict>\s*</plist>#\t<key>com.apple.security.files.user-selected.read-write</key>\n\t<true/>\n</dict>\n</plist>#' "$f"
done

echo "Plataformas prontas: $ID"
