#!/usr/bin/env bash
# Build jqssun/android-airplay-server (GPL-3, separate app) from source and install it on the TV
# as a background AirPlay receiver. Only this script lives in this repo; the GPL code is cloned
# into a separate folder next to it and never mixed with the MIT launcher.
set -euo pipefail
cd "$(dirname "$0")"
: "${TV_HOST:?set TV_HOST to the TV IP address, e.g. TV_HOST=192.168.1.50 $0}"
AIRPLAY_TAG="${AIRPLAY_TAG:-v0.0.33}"
AIRPLAY_ABI="${AIRPLAY_ABI:-armeabi-v7a}"   # check with: tv.py getprop ro.product.cpu.abilist
AIRPLAY_NAME="${AIRPLAY_NAME:-}"            # defaults to the TV's device_name
SRC="${AIRPLAY_SRC:-../../android-airplay-server}"
PKG=io.github.jqssun.airplay

export JAVA_HOME="${JAVA_HOME:-$(/usr/libexec/java_home -v 21 2>/dev/null || echo "/Applications/Android Studio.app/Contents/jbr/Contents/Home")}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
PY=../tools/venv/bin/python
[ -x "$PY" ] || PY=../tools/venv/Scripts/python.exe
tv() { "$PY" -I ../tools/tv.py "$@"; }

if [ ! -d "$SRC/.git" ]; then
  git clone --depth 1 --branch "$AIRPLAY_TAG" --recurse-submodules --shallow-submodules \
    https://github.com/jqssun/android-airplay-server.git "$SRC"
fi
(
  cd "$SRC"
  git checkout -q -- app/build.gradle.kts
  # Build only the TV's ABI (27 MB -> ~9 MB) and sign the release build with the debug key.
  sed -i.bak "s/^val allAbis = listOf(.*)/val allAbis = listOf(\"$AIRPLAY_ABI\")/" app/build.gradle.kts
  sed -i.bak 's/signingConfigs.findByName("release")?.let { signingConfig = it }/signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")/' app/build.gradle.kts
  rm -f app/build.gradle.kts.bak
  [ -f local.properties ] || echo "sdk.dir=$ANDROID_HOME" > local.properties
  ./gradlew assembleRelease -q --console=plain
)

"$PY" -I ../tools/b64push.py "$SRC/app/build/outputs/apk/release/app-release.apk" /data/local/tmp/airplay.apk
[ -n "$AIRPLAY_NAME" ] || AIRPLAY_NAME="$(tv settings get global device_name | tr -d '\r\n')"
printf '%s\n' \
  "pm install -r /data/local/tmp/airplay.apk" \
  "rm -f /data/local/tmp/airplay.apk" \
  "am broadcast -a $PKG.SET_SETTING -n $PKG/.SettingsReceiver --es key server_name --es value '$AIRPLAY_NAME'" \
  "am broadcast -a $PKG.SET_SETTING -n $PKG/.SettingsReceiver --es key boot_auto_start --es value true" \
  "dumpsys deviceidle whitelist +$PKG" \
  "cmd appops set $PKG RUN_IN_BACKGROUND allow" \
  "am start -n $PKG/.MainActivity" \
  "input keyevent KEYCODE_HOME" \
  | tv --batch
# Launching the activity once takes the app out of the "stopped" state, so BOOT_COMPLETED reaches it.
echo "Installed. The TV shows up as \"$AIRPLAY_NAME\" in Screen Mirroring on iPhone/iPad/Mac."
