# Copyright 2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

EAPI=8

# Must be set before inheriting cargo; src/Cargo.toml declares 1.96.0.
RUST_MIN_VER="1.96.0"

inherit cargo git-r3

DESCRIPTION="Unofficial Jellyfin desktop client built on CEF and mpv"
HOMEPAGE="https://github.com/andrewrabert/jellium-desktop"
EGIT_REPO_URI="https://github.com/andrewrabert/jellium-desktop.git"
EGIT_BRANCH="main"
EGIT_SUBMODULES=()

# Prebuilt CEF distribution the crate build scripts expect. This must stay in
# lockstep with the `cef` entry in src/Cargo.lock (currently
# 151.3.0+151.3.16, i.e. CEF 151.3.16). The flat, versioned layout that
# download-cef (and xtask's --external-cef) looks for is:
#   <root>/<CEF_VER>/cef_linux_x86_64/{libcef.so,*.pak,locales/,include/,...}
CEF_VER="151.3.16"
CEF_BUILD="151.3.16+gbe1e15d+chromium-151.0.7922.109"
CEF_ARCH="linux64"
CEF_OSARCH="cef_linux_x86_64"
CEF_ARCHIVE="cef_binary_${CEF_BUILD}_${CEF_ARCH}_minimal.tar.bz2"
CEF_DISTFILE="cef-${CEF_VER}-${CEF_ARCH}.tar.bz2"
CEF_SHA1="13042a73aeaf0e853a719d3ddad0751514665bb9"

LICENSE="GPL-2.0-only"
SLOT="0"
KEYWORDS="~amd64"
IUSE="kde"

# Live ebuild: the git checkout and the Rust crates are fetched in
# src_unpack, which needs network access. The prebuilt CEF tarball is large
# and architecture specific, so it is not mirrored.
PROPERTIES="live"
RESTRICT="mirror test"

SRC_URI="https://cef-builds.spotifycdn.com/${CEF_ARCHIVE} -> ${CEF_DISTFILE}"

# Shared libraries dlopen()'d or linked by the staged libcef.so.
RDEPEND="
	media-video/mpv[libmpv]
	app-accessibility/at-spi2-core
	dev-libs/expat
	dev-libs/glib:2
	dev-libs/nspr
	dev-libs/nss
	dev-libs/wayland
	media-libs/alsa-lib
	media-libs/fontconfig
	media-libs/freetype
	media-libs/libglvnd
	media-libs/libpulse
	media-libs/libva
	media-libs/mesa
	media-libs/vulkan-loader
	net-print/cups
	sys-apps/dbus
	virtual/libudev
	x11-libs/cairo
	x11-libs/libdrm
	x11-libs/libX11
	x11-libs/libXcomposite
	x11-libs/libXdamage
	x11-libs/libXext
	x11-libs/libXfixes
	x11-libs/libXrandr
	x11-libs/libXrender
	x11-libs/libXScrnSaver
	x11-libs/libXtst
	x11-libs/libxcb
	x11-libs/libxkbcommon
	x11-libs/libxshmfence
	x11-libs/pango
	x11-misc/xdg-utils
"
DEPEND="
	media-video/mpv[libmpv]
	media-video/ffmpeg
"
BDEPEND="
	dev-build/cmake
	dev-build/ninja
	dev-util/patchelf
	dev-util/pkgconf
	dev-vcs/git
	sys-devel/clang
	sys-devel/llvm
"

# The bundled libcef.so and friends are prebuilt upstream binaries.
QA_PREBUILT="usr/lib*/jellium-desktop/*"

src_unpack() {
	git-r3_src_unpack

	# The Cargo workspace lives in src/, but the git-r3 checkout (and the
	# resources referenced during install) live at the repository root.
	S="${WORKDIR}/${P}/src"
	cargo_live_src_unpack

	unpack "${CEF_DISTFILE}"
	_stage_cef
}

# Rearrange the CEF tarball into the flat, versioned directory layout the
# cef crate / xtask expect, and drop in the archive.json they validate.
_stage_cef() {
	local extracted="${WORKDIR}/cef_binary_${CEF_BUILD}_${CEF_ARCH}_minimal"
	local cef_dir="${WORKDIR}/cef/${CEF_VER}/${CEF_OSARCH}"

	mkdir -p "${cef_dir}" || die

	mv "${extracted}"/Release/* "${cef_dir}/" || die
	mv "${extracted}"/Resources/* "${cef_dir}/" || die
	mv "${extracted}"/CMakeLists.txt "${extracted}"/cmake \
		"${extracted}"/include "${extracted}"/libcef_dll \
		"${extracted}"/CREDITS.html "${cef_dir}/" || die

	cat > "${cef_dir}/archive.json" <<-EOF || die
	{"type":"minimal","name":"${CEF_ARCHIVE}","sha1":"${CEF_SHA1}"}
	EOF
}

src_compile() {
	# xtask's mpv handling assumes <prefix>/lib and <prefix>/include, while
	# Gentoo's native libdir is lib64. Point it at a small symlink farm.
	local mpv_prefix="${WORKDIR}/mpv-prefix"
	mkdir -p "${mpv_prefix}" || die
	ln -sfn "${EPREFIX}/usr/include" "${mpv_prefix}/include" || die
	ln -sfn "${EPREFIX}/usr/$(get_libdir)" "${mpv_prefix}/lib" || die

	local xtask=(
		run --quiet
		--manifest-path "${S}/xtask/Cargo.toml"
		--
		build
		--external-cef "${WORKDIR}/cef"
		--external-mpv "${mpv_prefix}"
		--out build
	)
	use kde || xtask+=( --no-kde-palette )

	cargo_env "${CARGO}" "${xtask[@]}" || die "xtask build failed"
}

src_install() {
	local root="${WORKDIR}/${P}"
	local jdir="/usr/$(get_libdir)/jellium-desktop"

	# xtask bakes $ORIGIN plus the (build-time) mpv prefix into the rpath.
	# Keep only $ORIGIN so the library search stays relocatable and no
	# references to ${WORKDIR} are installed.
	patchelf --force-rpath --set-rpath '$ORIGIN' build/jellium-desktop || die

	# Upstream CEF ships ~1.4 GB of debug info in libcef.so; drop it.
	"$(tc-getSTRIP)" --strip-debug build/libcef.so || die

	exeinto "${jdir}"
	doexe build/jellium-desktop

	insinto "${jdir}"
	doins build/*.so* build/*.bin build/*.pak build/*.dat
	insinto "${jdir}/locales"
	doins build/locales/*.pak

	# The binary resolves libcef.so, its resources and locales from $ORIGIN,
	# so keep the real binary in its private directory and expose it on PATH.
	dosym "../$(get_libdir)/jellium-desktop/jellium-desktop" /usr/bin/jellium-desktop

	insinto /usr/share/applications
	doins "${root}/resources/linux/net.nullsum.JelliumDesktop.desktop"
	insinto /usr/share/icons/hicolor/scalable/apps
	doins "${root}/resources/linux/net.nullsum.JelliumDesktop.svg"
	insinto /usr/share/metainfo
	doins "${root}/resources/linux/net.nullsum.JelliumDesktop.metainfo.xml"
}
