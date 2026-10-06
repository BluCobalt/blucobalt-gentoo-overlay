# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

MY_PN="${PN%-bin}"

inherit pax-utils unpacker xdg-utils

DESCRIPTION="Proton Pass desktop application"
HOMEPAGE="https://proton.me/pass"
SRC_URI="https://proton.me/download/pass/linux/proton-pass_${PV}_amd64.deb -> ${P}.deb"
S="${WORKDIR}"

# The Proton Pass desktop application source is distributed under GPL-3+.
# The bundled Electron/Chromium runtime carries a number of permissive licenses.
# https://github.com/NixOS/nixpkgs/pull/296127#discussion_r1528184212
LICENSE="GPL-3+"
SLOT="0"
KEYWORDS="-* ~amd64"

RESTRICT="bindist mirror strip"

RDEPEND="
	app-accessibility/at-spi2-core:2
	app-crypt/libsecret
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	media-libs/alsa-lib
	media-libs/fontconfig
	media-libs/mesa[gbm(+)]
	net-print/cups
	sys-apps/dbus
	sys-libs/glibc
	virtual/udev
	x11-libs/cairo
	x11-libs/gtk+:3
	x11-libs/libdrm
	x11-libs/libnotify
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libXtst
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/pango
	x11-misc/xdg-utils
"

QA_PREBUILT="usr/lib/${MY_PN}/*"

src_install() {
	insinto /usr
	doins -r usr/lib

	insinto /usr/share
	doins -r usr/share/applications
	doins -r usr/share/pixmaps

	dodoc usr/share/doc/${MY_PN}/copyright

	fperms 0755 "/usr/lib/${MY_PN}/Proton Pass"
	fperms 0755 "/usr/lib/${MY_PN}/chrome_crashpad_handler"

	# The bundled Chromium sandbox requires the setuid bit to function,
	# see https://github.com/electron/electron/issues/17972
	fowners root:root "/usr/lib/${MY_PN}/chrome-sandbox"
	fperms 4711 "/usr/lib/${MY_PN}/chrome-sandbox"

	pax-mark m "${ED}/usr/lib/${MY_PN}/Proton Pass"
	pax-mark m "${ED}/usr/lib/${MY_PN}/chrome-sandbox"

	dosym "../lib/${MY_PN}/Proton Pass" "/usr/bin/${MY_PN}"
}

pkg_postinst() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}

pkg_postrm() {
	xdg_desktop_database_update
	xdg_icon_cache_update
}
