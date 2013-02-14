SUMMARY = "DEL examples: ADC test application"
SECTION = "examples"
LICENSE = "GPL-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/GPL-2.0;md5=801f80980d171dd6425610833a22dbe6"

PR = "r0"

SRC_URI = "file://adc_test"

UPPER_PLAT = "${@'${MACHINE}'.upper()}"

S = "${WORKDIR}/adc_test"

do_compile() {
	${CC} -O2 -Wall -D${UPPER_PLAT} adc_test.c -o adc_test -lm
}

do_install() {
	install -d ${D}${bindir}
	install -m 0755 adc_test ${D}${bindir}
}

PACKAGE_ARCH = "${MACHINE_ARCH}"