#!/bin/bash
log() {
    echo "$*" >&2
}

PROG_DIR="$(cd $(dirname "$0"); pwd)"
PROG_NAME="$(basename "$0")"

usage() {
    log "Usage: $PROG_NAME [OPTIONS] packageName newPackageName debugKeyStoreFile"
    log "  This script get app from all connected android device and change app name"
    log "  then install a new one to devices."
    log "  When -s option is specified, only the specified device will be applied."
    log
    log "Options:"
    log "  -H <host>              - Name of adb server host (default: localhost)"
    log "  -P <port>              - Port of adb server (default: 5037)"
    log "  -s <devSerialNumber>   - Device Serial Number or qualifier"
    log "  --update               - Update app"
    log
    log "Examples:"
    log "   $PROG_NAME com.android.browser com.android.mybrowser ~/.android/debug.keystore"
    log "   $PROG_NAME -s HTC12334 com.android.browser com.android.mybrowser ~/.android/debug.keystore"
    exit 1
}

ADB_OPTION=()   #array
IS_UPDATE_INSTALL=0
DEV_SPECIFIED=""
restArgs=() #array

while (( $# > 0 )); do
    case "$1" in
        '-H'|'-P'|'-s' )
            if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then log "option requires an argument for $1"; exit 1; fi
            if [ "$1" == "-s" ]; then DEV_SPECIFIED="$2"; else ADB_OPTION+=("$1" "$2"); fi
            shift 2
            ;;
        '--update' )
            IS_UPDATE_INSTALL=1
            shift 1
            ;;
        '--help' )
            usage
            ;;
        -*)
            log "invalid option: $1, please use --help to see usage"; exit 1;
            usage
            ;;
        *)
            restArgs+=("$1")
            shift 1
            ;;
    esac
done
if (( ${#restArgs[@]} < 3 )); then log "too few arguments"; usage; fi

packageName="${restArgs[0]}"
newPackageName="${restArgs[1]}"
debugKeyStoreFile="${restArgs[2]}"
if [ ! -f "$debugKeyStoreFile" ]; then log "file does not exist: $debugKeyStoreFile"; exit 1; fi

if [ "$ADB_OPTION" != "" ]; then log "~~~~ use ADB_OPTION: ${ADB_OPTION[@]}"; fi

renameAppAndInstall() {
    dev="$1"
    "$PROG_DIR/apkRename.sh" "${ADB_OPTION[@]}" -s "$dev" "$packageName" "$newPackageName" || return $?
    "$PROG_DIR/apkSign.sh" ./tmpForApkRename/app.apk "$debugKeyStoreFile" || return $?
    if [ $IS_UPDATE_INSTALL == 0 ]; then
        log ""
        log "~~~~ uninstall $newPackageName from device $dev"
        adb "${ADB_OPTION[@]}" -s "$dev" uninstall "${newPackageName/\!/}"  #remove ! char
    fi
    log ""
    log "~~~~ install ./tmpForApkRename/app.apk to device $dev"
    adb "${ADB_OPTION[@]}" -s "$dev" install -r ./tmpForApkRename/app.apk || return $?
}

if [ "$DEV_SPECIFIED" == "" ]; then
    count_ok=0
    count_ng=0
    log "~~~~ enum devices"
    for dev in `adb "${ADB_OPTION[@]}" devices | grep -v "List of devices" | awk '{print $1}'`; do
        log "-----------------------------dev $dev -------------------------------------------"
        if renameAppAndInstall "$dev"; then
            ((count_ok++))
        else
            ((count_ng++))
        fi
    done
    log ""
    log "Summary:"
    log "  success: $count_ok"
    log "  failure: $count_ng"
    log ""
else
    renameAppAndInstall "$DEV_SPECIFIED"
fi
