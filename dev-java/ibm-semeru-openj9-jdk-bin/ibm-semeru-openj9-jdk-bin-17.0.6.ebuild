EAPI=8

inherit java-vm-2 toolchain-funcs

DESCRIPTION="IBM Semeru OpenJ9 is a high-performance, enterprise-class, free Java distribution"
HOMEPAGE="https://developer.ibm.com/javasdk/"
LICENSE="GPL-2-with-classpath-exception"
SLOT="17"
KEYWORDS="~amd64"
IUSE="alsa headless-awt source"

RDEPEND="alsa? ( media-libs/alsa-lib )
sys-libs/zlib
!headless-awt? ( x11-libs/libX11 x11-libs/libXau x11-libs/libXdmcp x11-libs/libXext x11-libs/libXi x11-libs/libXrender x11-libs/libXtst )
media-libs/freetype
media-libs/libpng
x11-libs/libxcb
sys-libs/glibc
app-arch/bzip2
"

RESTRICT="preserve-libs splitdebug"

SRC_URI="https://github.com/ibmruntimes/semeru17-binaries/releases/download/jdk-17.0.6%2B10_openj9-0.36.0/ibm-semeru-open-jdk_x64_linux_17.0.6_10_openj9-0.36.0.tar.gz"
S="${WORKDIR}/jdk-17.0.6+10"

src_unpack() {
    default
}

src_install() {
	local dest="/opt/${P}"
	local ddest="${ED}/${dest#/}"
	if ! use alsa ; then
	    rm -v lib/libjsound.* || die
	fi

	if use headless-awt ; then
	    rm -v lib/lib*{[jx]awt,splashscreen}* || die
	fi

	if ! use source ; then
            rm -v lib/src.zip || die
	fi

	rm -v lib/security/cacerts || die
	dosym -r /etc/ssl/certs/java/cacerts "${dest}"/lib/security/cacerts

	dodir "${dest}"
	cp -pPR * "${ddest}" || die

	# provide stable symlink
	dosym "${P}" "/opt/${PN}-${SLOT}"

	java-vm_install-env "${FILESDIR}"/env.sh
	java-vm_set-pax-markings "${ddest}"
	java-vm_revdep-mask
	java-vm_sandbox-predict /dev/random /proc/self/coredump_filter
}

pkg_postinst() {
    java-vm-2_pkg_postinst
}

