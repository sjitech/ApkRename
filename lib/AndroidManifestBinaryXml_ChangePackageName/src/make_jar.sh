#!/bin/sh
rm -f ../bin/setAxmlPkgName.jar
cd ../tmp
jar cmfv ../src/MANIFEST.MF  ../bin/setAxmlPkgName.jar jp
