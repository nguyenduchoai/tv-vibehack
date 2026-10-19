# AirPlay receiver (iPhone / iPad / Mac → TV)

Ad-free background AirPlay receiver, like Chromecast built-in but for Apple devices.
It uses [jqssun/android-airplay-server](https://github.com/jqssun/android-airplay-server), which builds on the
[UxPlay](https://github.com/FDH2/UxPlay) protocol core. That code is **GPL-3** and stays a separate app
(`io.github.jqssun.airplay`). This repo only holds the MIT build/install script and contains no GPL code.

```bash
TV_HOST=192.168.1.50 ./build-and-install.sh
```

What the script does:

- clones the pinned tag (`AIRPLAY_TAG`, default `v0.0.33`) into `../../android-airplay-server`
- builds only the TV's ABI (`AIRPLAY_ABI`, default `armeabi-v7a`), which takes the APK from 27 MB to about 9 MB
- installs the app and names the receiver after the TV's `device_name` (or `AIRPLAY_NAME`)
- turns on start at boot and exempts the app from Doze and background limits

When an iPhone starts mirroring, the receiver opens full screen on its own. When idle, it is a
foreground service using about 40 MB of RAM. Mirroring, YouTube video, and audio (AAC/ALAC) work.
DRM content does not (Netflix, Apple TV+, Disney+), because Apple's FairPlay video DRM cannot be decrypted.

Other settings can be changed over ADB, for example to require a PIN:

```bash
python -I ../tools/tv.py "am broadcast -a io.github.jqssun.airplay.SET_SETTING -n io.github.jqssun.airplay/.SettingsReceiver --es key require_pin --es value true"
```

To list every setting, use the `LIST_SETTINGS` action.
