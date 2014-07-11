#! /bin/bash

checkinstall -D --nodoc --pkgname=cmake-sbe --maintainer=stefan.bellus@frequentis.com  -A all --requires="cmake \(>= 2.8.10.2-4\)" --provides=cmake-sbe --pkggroup=frequentis make install
