#
# Copyright (C) 2012 Digi International.
#
SUMMARY = "Gstreamer framework packagegroup for DEY image"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/LICENSE;md5=3f40d7994397109285ec7b81fdeb3b58"

PACKAGE_ARCH = "${MACHINE_ARCH}"
inherit packagegroup

MACHINE_GSTREAMER_PLUGIN ?= ""

GSTREAMER0_PKGS = " \
    gst-meta-audio \
    gst-meta-video \
    gst-plugins-base-meta \
    gst-plugins-good-meta \
    gst-plugins-ugly-meta \
    gst-plugins-bad-meta \
    ${MACHINE_GSTREAMER_PLUGIN} \
    ${@base_conditional('HAVE_GUI', '1' , '', 'gst-fsl-plugin-gplay', d)} \
    ${@base_conditional('HAVE_BT', '1' , 'gst-plugin-bluetooth', '', d)} \
"

GSTREAMER1_PKGS = " \
    gstreamer1.0-meta-audio \
    gstreamer1.0-meta-video \
    gstreamer1.0-plugins-base-meta \
    gstreamer1.0-plugins-good-meta \
    gstreamer1.0-plugins-ugly-meta \
    gstreamer1.0-plugins-bad-meta \
    ${MACHINE_GSTREAMER_1_0_PLUGIN} \
"

RDEPENDS_${PN} = " \
    ${GSTREAMER0_PKGS} \
    ${GSTREAMER1_PKGS} \
"
