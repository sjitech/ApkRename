This project contains 4 utilities:
--  name -----------------------------  ------depending utilities------------------
    apkRename.sh                        java, jar
    apkRenameAndInstall.sh              java, jar, zip, jarsigner, adb
    setAxmlPkgName.jar   (in lib/)      java
    apkSign.sh                          zip, jarsigner

----------------------------------------------------------------------------------
apkRename.sh

Usage: apkRename.sh [OPTIONS] apkPath_or_packageName newPackageName
  This utility changes APK's package name (not java package name) and
  prepend java package name to partial class name in AndroidManifest.xml:
    Application,Activity,Receiver,Service...
    backupAgent,manageSpaceActivity,targetActivity...
    meta value(only if start with dot)

Note:
 If apkPath_or_packageName ends with .apk then means a apk file to be changed,
   otherwise means a packageName and will pull file from device to:
   ./tmpForApkRename/app.apk then change it

 If newPackageFullName ends with ! then it will remove conflict settings:
   <original-package>,<provider>,android:protectionLevel,process,sharedUserId

 For system app, it will pull app's odex file and convert to dex, add to apk.

 The result APK file is not signed, to install it please use apkSign.sh.

Options:
  -H <host>              - Name of adb server host (default: localhost)
  -P <port>              - Port of adb server (default: 5037)
  -s <devSerialNumber>   - Device Serial Number or qualifier

Examples:
 apkRename.sh /tmp/test.apk       com.exampe.newapp
 apkRename.sh com.example.app     com.exampe.newapp
 apkRename.sh com.android.browser com.exampe.newapp!
 apkRename.sh -s HTC123123 com.android.browser com.exampe.newapp!

--------------------------------------------------------------------------------------------
apkRenameAndInstall

Usage: apkRenameAndInstall.sh [OPTIONS] packageName newPackageName debugKeyStoreFile
  This script get app from all connected android device and change app name
  then install a new one to devices.
  When -s option is specified, only the specified device will be applied.

Options:
  -H <host>              - Name of adb server host (default: localhost)
  -P <port>              - Port of adb server (default: 5037)
  -s <devSerialNumber>   - Device Serial Number or qualifier
  --update               - Update app

Examples:
   apkRenameAndInstall.sh com.android.browser com.android.mybrowser ~/.android/debug.keystore
   apkRenameAndInstall.sh -s HTC12334 com.android.browser com.android.mybrowser ~/.android/debug.keystore

--------------------------------------------------------------------------------------------
setAxmlPkgName.jar

please see lib/.... README.txt
