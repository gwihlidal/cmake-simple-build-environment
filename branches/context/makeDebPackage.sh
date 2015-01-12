#! /bin/bash

mkdir -p build
cd build
cmake ..
cp ../description-pak .
checkinstall -D --nodoc --pkgname=cmake-sbe --maintainer=stefan.bellus@frequentis.com  --pkgarch=all --requires="cmake \(>= 2.8.10.2-4\)" --provides=cmake-sbe --pkggroup=frequentis make install
