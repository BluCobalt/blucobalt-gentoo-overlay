# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Upstream publishes no tagged releases yet; the only Linux binaries are nightly
# AppImage artifacts built by GitHub Actions and served through nightly.link.
# This ebuild is pinned to a single workflow run so the distfile is immutable.
#
# To bump:
#   1. gh run list --workflow build-linux-appimage.yml --branch main --status success
#   2. set JELLIUM_RUN to the run id and JELLIUM_SHA to its head sha
#   3. update the date suffix in PV (this is the run's created_at, UTC)
#   4. pkgdev manifest -d <distdir>
#
# Note: GitHub Actions artifacts (and therefore nightly.link) expire ~90 days
# after the run, so the distfile should be re-hosted for long-term use.
JELLIUM_RUN="35469986313"
JELLIUM_SHA="14dc084"

inherit desktop

DESCRIPTION="Unofficial Jellyfin desktop client built on CEF and mpv (binary)"
HOMEPAGE="https://github.com/andrewrabert/jellium-desktop"
SRC_URI="https://nightly.link/andrewrabert/jellium-desktop/actions/runs/${JELLIUM_RUN}/linux-appimage-x86_64.zip -> ${P}.zip"

S="${WORKDIR}"

LICENSE="GPL-2"
SLOT="0"
KEYWORDS="-* ~amd64"

# Prebuilt AppImage: never strip/rebuild the bundled binaries, and do not
# mirror an artifact that only exists behind a temporary signed URL.
RESTRICT="bindist mirror strip"

# The AppImage is self-contained (it bundles glibc, CEF, mpv, ...) except for
# the GPU/DRM libraries, which are deliberately removed so the host kernel
# driver is used.
RDEPEND="
	media-libs/libglvnd
	media-libs/mesa
	media-libs/vulkan-loader
	sys-apps/dbus
	x11-libs/libdrm
	x11-libs/libxshmfence
	x11-misc/xdg-utils
	virtual/libcrypt
"
BDEPEND="app-arch/unzip"

QA_PREBUILT="*"
QA_DT_NEEDED="*"
QA_SONAME="*"

src_unpack() {
	mkdir -p "${S}" || die
	pushd "${S}" >/dev/null || die

	unzip -q "${DISTDIR}/${P}.zip" || die

	local -a appimage=( JelliumDesktop-*.AppImage )
	[[ ${#appimage[@]} -eq 1 ]] \
		|| die "expected exactly one AppImage, found ${#appimage[@]}"
	chmod +x "${appimage[0]}" || die

	# --appimage-extract unpacks the embedded squashfs without needing FUSE.
	"./${appimage[0]}" --appimage-extract || die
	mv squashfs-root appdir || die

	popd >/dev/null || die
}

src_install() {
	local apphome="/opt/${PN}"

	# AppRun resolves the AppDir from its own symlink-resolved path and exports
	# the bundled loader/library/plugin locations at launch, so the tree can be
	# relocated under /opt unchanged.
	dodir "${apphome}"
	cp -a "${S}/appdir/." "${ED}/${apphome}/" || die

	# Upstream's desktop entry uses Exec=jellium-desktop.
	dosym -r "${apphome}/AppRun" /usr/bin/jellium-desktop

	domenu "${S}/appdir/net.nullsum.JelliumDesktop.desktop"
	doicon -s scalable "${S}/appdir/net.nullsum.JelliumDesktop.svg"
	insinto /usr/share/metainfo
	doins "${S}/appdir/usr/share/metainfo/net.nullsum.JelliumDesktop.metainfo.xml"
}

pkg_postinst() {
	xdg_icon_cache_update()
}

pkg_postrm() {
	xdg_icon_cache_update()
}
