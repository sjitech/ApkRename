#!/bin/bash
log() {
    echo "$*" >&2
}

if (( $# < 2 )); then log "need parameters: apkPath debugKeyStoreFile"; exit 1; fi
apkPath="$1"
if [ ! -f "$apkPath" ]; then log "file does not exist: $apkPath"; exit 1; fi
debugKeyStoreFile="$2"
if [ ! -f "$debugKeyStoreFile" ]; then log "file does not exist: $debugKeyStoreFile"; exit 1; fi

log ""
log "~~~~ remove signature"
zip -d "$apkPath" META-INF/MANIFEST.MF "META-INF/*.SF" "META-INF/*.RSA" "META-INF/*.DSA" "META-INF/SIG-*"

log ""
log "~~~~ add signature"
jarsigner -keystore "$debugKeyStoreFile" -sigfile CERT -sigalg SHA1withRSA -digestalg SHA1 -storepass android -keypass android "$apkPath" androiddebugkey || exit 1
log "OK"
