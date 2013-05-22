#!/bin/bash
#===============================================================================
#
#  build.sh
#
#  Copyright (C) 2013 by Digi International Inc.
#  All rights reserved.
#
#  This program is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License version 2 as published by
#  the Free Software Foundation.
#
#
#  !Description: Yocto autobuild script from Jenkins.
#
#  Parameters set by Jenkins:
#     DY_BUILD_VARIANTS: Build all platform variants
#     DY_PLATFORMS:      Platforms to build
#     DY_REVISION:       Revision of the manifest repository (for 'repo init')
#     DY_TARGET:  	 Target image (the default is 'del-image-minimal')
#     DY_USE_MIRROR:     Use internal Digi mirror to download packages
#
#===============================================================================

set -e

SCRIPTNAME="$(basename ${0})"
SCRIPTPATH="$(cd $(dirname ${0}) && pwd)"

MANIFEST_URL="git://git.digi.com/del/yocto/digi-yocto-sdk-manifest.git"

DIGI_PREMIRROR_CFG="
# Use internal mirror
SOURCE_MIRROR_URL ?= \"http://build-linux.digi.com/yocto/downloads/\"
INHERIT += \"own-mirrors\"
"

REPO="$(which repo)"

error() {
	printf "${1}"
	exit 1
}

#
# Copy buildresults (images, licenses, packages)
#
#  $1: destination directoy
#
copy_images() {
	# Do not copy all the individual packages when building all the variants
	# The buildserver cannot afford such amount of disk space. In this case
	# just copy the firmware images.
	if [ "${DY_BUILD_VARIANTS}" = "true" ]; then
		cp -r tmp/deploy/images ${1}/
	else
		cp -r tmp/deploy/* ${1}/
	fi
	# Jenkins artifact archiver does not copy symlinks, so remove them
	# beforehand to avoid ending up with several duplicates of the same
	# files.
	find ${1}/images -type l -delete
}

# Sanity check (Jenkins environment)
[ -z "${DY_BUILD_VARIANTS}" ] && error "DY_BUILD_VARIANTS not specified"
[ -z "${DY_PLATFORMS}" ]      && error "DY_PLATFORMS not specified"
[ -z "${DY_REVISION}" ]       && error "DY_REVISION not specified"
[ -z "${DY_USE_MIRROR}" ]     && error "DY_USE_MIRROR not specified"
[ -z "${WORKSPACE}" ]         && error "WORKSPACE not specified"

# Set default build target if Jenkins does not set it
[ -z "${DY_TARGET}" ] && DY_TARGET="del-image-minimal"

# Per-platform variants
while read _pl _var; do
	[ "${DY_BUILD_VARIANTS}" = "false" ] && _var="DONTBUILDVARIANTS"
	eval "${_pl}_var=\"${_var}\""
done<<-_EOF_
	ccardimx28js    - e w wb web web1
	ccimx51js       128 128a 128agv agv eagv w w128a w128agv wagv weagv
	ccimx53js       - 128 4k e e4k w w128 we
	cpx2            -
	wr21            -
_EOF_

YOCTO_IMGS_DIR="${WORKSPACE}/images"
YOCTO_INST_DIR="${WORKSPACE}/digi-yocto-sdk.$(echo ${DY_REVISION} | tr '/' '_')"
YOCTO_PROJ_DIR="${WORKSPACE}/projects"

CPUS="$(grep -c processor /proc/cpuinfo)"
[ ${CPUS} -gt 1 ] && MAKE_JOBS="-j${CPUS}"

printf "\n[INFO] Build Yocto \"${DY_REVISION}\" for \"${DY_PLATFORMS}\" (cpus=${CPUS})\n\n"

# Install/Update Digi's Yocto SDK
mkdir -p ${YOCTO_INST_DIR}
if pushd ${YOCTO_INST_DIR}; then
	# Use git ls-remote to check the revision type
	if [ "${DY_REVISION}" != "master" ]; then
		if git ls-remote --tags --exit-code "${MANIFEST_URL}" "${DY_REVISION}"; then
			printf "[INFO] Using tag \"${DY_REVISION}\"\n"
			repo_revision="-b refs/tags/${DY_REVISION}"
		elif git ls-remote --heads --exit-code "${MANIFEST_URL}" "${DY_REVISION}"; then
			printf "[INFO] Using branch \"${DY_REVISION}\"\n"
			repo_revision="-b ${DY_REVISION}"
		else
			error "Revision \"${DY_REVISION}\" not found"
		fi
	fi
	yes "" 2>/dev/null | ${REPO} init --no-repo-verify -u ${MANIFEST_URL} ${repo_revision}
	${REPO} sync ${MAKE_JOBS}
	popd
fi

# Create projects and build
rm -rf ${YOCTO_IMGS_DIR} ${YOCTO_PROJ_DIR}
for platform in ${DY_PLATFORMS}; do
	eval platform_variants="\${${platform}_var}"
	for variant in ${platform_variants}; do
		_this_prj_dir="${YOCTO_PROJ_DIR}/${platform}"
		_this_img_dir="${YOCTO_IMGS_DIR}/${platform}"
		if [ "${variant}" != "DONTBUILDVARIANTS" ]; then
			_this_prj_dir="${YOCTO_PROJ_DIR}/${platform}_${variant}"
			_this_img_dir="${YOCTO_IMGS_DIR}/${platform}_${variant}"
			_this_var_arg="-v ${variant}"
			[ "${variant}" = "-" ] && _this_var_arg="-v \\"
		fi
		mkdir -p ${_this_img_dir} ${_this_prj_dir}
		if pushd ${_this_prj_dir}; then
			# Configure and build the project in a sub-shell to avoid
			# mixing environments between different platform's projects
			(
				. ${YOCTO_INST_DIR}/mkproject.sh -p ${platform} ${_this_var_arg}
				# Set a common DL_DIR and SSTATE_DIR for all platforms
				sed -i  -e "/^#DL_DIR ?=/cDL_DIR ?= \"${YOCTO_PROJ_DIR}/downloads\"" \
					-e "/^#SSTATE_DIR ?=/cSSTATE_DIR ?= \"${YOCTO_PROJ_DIR}/sstate-cache\"" \
					conf/local.conf
				[ "${DY_USE_MIRROR}" = "true" ] && printf "${DIGI_PREMIRROR_CFG}" >> conf/local.conf
				[ "${DY_BUILD_VARIANTS}" = "true" ] && printf "\nINHERIT += \"rm_work\"\n" >> conf/local.conf
				time bitbake ${DY_TARGET}
			)
			copy_images ${_this_img_dir}
			popd
		fi
	done
done