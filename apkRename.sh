#!/bin/bash
log() {
    echo "$*" >&2
}

PROG_DIR="$(cd $(dirname "$0"); pwd)"
PROG_NAME="$(basename "$0")"

usage() {
    log "Usage: $PROG_NAME [OPTIONS] apkPath_or_packageName newPackageName"
    log "  This utility changes APK's package name (not java package name) and "
    log "  prepend java package name to partial class name in AndroidManifest.xml:"
    log "    Application,Activity,Receiver,Service..."
    log "    backupAgent,manageSpaceActivity,targetActivity..."
    log "    meta value(only if start with dot)"
    log ""
    log "Note:"
    log " If apkPath_or_packageName ends with .apk then means a apk file to be changed,"
    log "   otherwise means a packageName and will pull file from device to:"
    log "   ./tmpForApkRename/app.apk then change it"
    log ""
    log " If newPackageFullName ends with ! then it will remove conflict settings:"
    log "   <original-package>,<provider>,android:protectionLevel,process,sharedUserId"
    log ""
    log " For system app, it will pull app's odex file and convert to dex, add to apk."
    log ""
    log " The result APK file is not signed, to install it please use apkSign.sh."
    log ""
    log "Options:"
    log "  -H <host>              - Name of adb server host (default: localhost)"
    log "  -P <port>              - Port of adb server (default: 5037)"
    log "  -s <devSerialNumber>   - Device Serial Number or qualifier"
    log
    log "Examples:"
    log " $PROG_NAME /tmp/old.apk        com.exampe.newapp "
    log " $PROG_NAME com.example.app     com.exampe.newapp "
    log " $PROG_NAME com.android.browser com.exampe.newapp!"
    log " $PROG_NAME -s HTC123123 com.android.browser com.exampe.newapp!"
    exit 1
}

ADB_OPTION=()   #array
restArgs=() #array

while (( $# > 0 )); do
    case "$1" in
        '-H'|'-P'|'-s' )
            if [[ -z "$2" ]] || [[ "$2" =~ ^-+ ]]; then log "option requires an argument for $1"; exit 1; fi
            ADB_OPTION+=("$1" "$2")
            shift 2
            ;;
        '--help' )
            usage
            ;;
        -*)
            log "invalid option: $1, please use --help to see usage"; exit 1;
            ;;
        *)
            restArgs+=("$1")
            shift 1
            ;;
    esac
done
if (( ${#restArgs[@]} < 2 )); then log "too few arguments"; usage; fi

apkPath_or_packageName="${restArgs[0]}"
newPackageName="${restArgs[1]}"
log "~~~~ use newPackageName: $newPackageName"

if echo "$apkPath_or_packageName" | grep -Eiq '[.]apk$'; then
    apkPath="$apkPath_or_packageName"
    if [ ! -f "$apkPath" ]; then log "file does not exist: $apkPath"; exit 1; fi
    packageName=""
    workDir="`dirname "$apkPath"`/tmpForApkRename"
    apkName="`basename "$apkPath"`"
    log "~~~~ use APK file mode: will modify $apkPath"
else
    packageName="$apkPath_or_packageName"
    workDir=./tmpForApkRename/tmpForApkRename
    apkPath=./tmpForApkRename/app.apk
    apkName=app.apk
    log "~~~~ use pull mode: will pull package $packageName from device to $apkPath then modify it"
fi

log "~~~~ prepare work dir: $workDir"
rm -rf "$workDir"
mkdir -p "$workDir" || exit 1
mkdir "$workDir/update" | exit 1

#------------------------------------------------------------------------------------------------
cd "$workDir" || exit 1

needUpdate=0

if [ "$packageName" != "" ]; then
    log ""
    if [ "$ADB_OPTION" != "" ]; then log "~~~~ use ADB_OPTION: ${ADB_OPTION[@]}"; fi
    log "~~~~ get apk remote path of package: $packageName"
    rpath="`adb "${ADB_OPTION[@]}" shell pm path \"$packageName\" | grep package:`"

    rpath="${rpath//$'\r'/}" #remove \r
    rpath="${rpath/package:/}" #remove package:
    if [ "$rpath" == "" ]; then log "can not get path of package $packageName from device"; exit 1; fi
    log "~~~~ remote path: $rpath"

    log ""
    log "~~~~ pull $rpath"
    adb "${ADB_OPTION[@]}" pull "$rpath" "../$apkName" || exit 1

    if [ "`dirname "$rpath"`" == "/system/app" ]; then
        #
        # get classes.odex, convert to classes.dex then add to APK
        #
        RMT_ODEX_PATH="${rpath%.*}.odex" #replace .apk with odex
        log ""
        log "~~~~ pull $RMT_ODEX_PATH"
        if adb "${ADB_OPTION[@]}" pull "$RMT_ODEX_PATH" classes.odex; then
            log ""
            log "~~~~ pull /system/framework/*.odex"
            mkdir framework || exit 1
            for f in `adb "${ADB_OPTION[@]}" shell "ls /system/framework/*.odex"`; do
                f="${f//$'\r'/}" #remove \r
                #log "$f"
                adb "${ADB_OPTION[@]}" pull "$f" framework/ 2> /dev/null || exit 1;
            done

            log ""
            log "~~~~ convert classes.odex to smali"
            "$PROG_DIR/lib/smali/baksmali" -d framework -x classes.odex -o smali_out || exit 1

            if [ "$packageName" == "com.android.browser" ]; then
                for f in `ls framework/multiwindow.odex framework/sec_feature.odex framework/sec_platform_library.odex framework/sechardware.odex 2>/dev/null`; do
                    log ""
                    log "~~~~ convert $f to smali   ***************************************"
                    "$PROG_DIR/lib/smali/baksmali" -d framework -x "$f" -o smali_out || exit 1
                done
                newPackageName="%$newPackageName"
            fi

            log ""
            log "~~~~ convert all smali to classes.dex"
            "$PROG_DIR/lib/smali/smali" smali_out -o update/classes.dex || exit 1

            needUpdate=1
        fi
    fi
fi

log ""
log "~~~~ extract AndroidManifest.xml (binary file)"
jar xvf "../$apkName" AndroidManifest.xml || exit 1

log ""
log "~~~~ change package name of AndroidManifest.xml"
java -jar "$PROG_DIR/lib/AndroidManifestBinaryXml_ChangePackageName/bin/setAxmlPkgName.jar" AndroidManifest.xml "$newPackageName"
rc=$?
if [ $rc == 0 ]; then
    cp AndroidManifest.xml update/
    needUpdate=1
elif [ $rc == 2 ]; then
    log "~~~~ need not change AndroidManifest.xml"
else
    exit 1
fi

log ""
if [ $needUpdate == 1 ]; then
    log "~~~~ update apk"
    jar uvf "../$apkName" -C update/ . || exit 1
else
    log "~~~~ need not update apk"
fi

log ""
log "OK. Result file is: $apkPath"
