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

echo "Plataformas prontas: $ID"
