#!/bin/sh

LIBDIR=${1:-/usr/local/share/satysfi}
INSTALL=${2:-install}

"${INSTALL}" -d "${LIBDIR}"
"${INSTALL}" -d "${LIBDIR}/dist"
"${INSTALL}" -d "${LIBDIR}/dist/unidata"
"${INSTALL}" -m 644 lib-satysfi/dist/unidata/*.txt "${LIBDIR}/dist/unidata"
"${INSTALL}" -d "${LIBDIR}/dist/fonts"
"${INSTALL}" -m 644 lib-satysfi/dist/fonts/* "${LIBDIR}/dist/fonts"
"${INSTALL}" -d "${LIBDIR}/dist/hash"
"${INSTALL}" -m 644 lib-satysfi/dist/hash/* "${LIBDIR}/dist/hash"
"${INSTALL}" -d "${LIBDIR}/dist/hyph"
"${INSTALL}" -m 644 lib-satysfi/dist/hyph/* "${LIBDIR}/dist/hyph"
"${INSTALL}" -d "${LIBDIR}/dist/packages"
(cd lib-satysfi && find dist/packages -type f -exec "${INSTALL}" -Dm 644 "{}" "${LIBDIR}/{}" \;)
"${INSTALL}" -d "${LIBDIR}/dist/md"
"${INSTALL}" -m 644 lib-satysfi/dist/md/* "${LIBDIR}/dist/md"
