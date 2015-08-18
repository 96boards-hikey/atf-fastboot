#
# Copyright (c) 2013-2014, ARM Limited and Contributors. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
#
# Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
#
# Neither the name of ARM nor the names of its contributors may be used
# to endorse or promote products derived from this software without specific
# prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

#
# Trusted Firmware Version
#
VERSION_MAJOR			:= 1
VERSION_MINOR			:= 1

include make_helpers/build_macros.mk

################################################################################
# Default values for build configurations
################################################################################


# Build verbosity
V				:= 0
# Debug build
DEBUG				:= 0
# Build architecture
ARCH 				:= aarch64
# Build platform
DEFAULT_PLAT			:= hikey
PLAT				:= ${DEFAULT_PLAT}
# SPD choice
SPD				:= none
# Base commit to perform code check on
BASE_COMMIT			:= origin/master
# NS timer register save and restore
NS_TIMER_SWITCH			:= 0
# Include FP registers in cpu context
CTX_INCLUDE_FPREGS		:= 0
# Determine the version of ARM GIC architecture to use for interrupt management
# in EL3. The platform port can change this value if needed.
ARM_GIC_ARCH			:=	2
# Flag used to indicate if ASM_ASSERTION should be enabled for the build.
# This defaults to being present in DEBUG builds only.
ASM_ASSERTION			:=	${DEBUG}
# Build option to choose whether Trusted firmware uses Coherent memory or not.
USE_COHERENT_MEM		:=	1
# By default, use the -pedantic option in the gcc command line
DISABLE_PEDANTIC		:= 0
# Flags to generate the Chain of Trust
GENERATE_COT			:= 0
CREATE_KEYS			:= 1
# Flags to build TF with Trusted Boot support
TRUSTED_BOARD_BOOT		:= 0
AUTH_MOD			:= none

# Checkpatch ignores
CHECK_IGNORE		:=	--ignore COMPLEX_MACRO

CHECKPATCH_ARGS		:=	--no-tree --no-signoff ${CHECK_IGNORE}
CHECKCODE_ARGS		:=	--no-patch --no-tree --no-signoff ${CHECK_IGNORE}

ifeq (${V},0)
	Q=@
	CHECKCODE_ARGS	+=	--no-summary --terse
else
	Q=
endif
export Q

# Process Debug flag
$(eval $(call add_define,DEBUG))
ifneq (${DEBUG}, 0)
	BUILD_TYPE	:=	debug
	CFLAGS		+= 	-g
	ASFLAGS		+= 	-g -Wa,--gdwarf-2
	# Use LOG_LEVEL_INFO by default for debug builds
	LOG_LEVEL	:=	40
else
	BUILD_TYPE	:=	release
	# Use LOG_LEVEL_NOTICE by default for release builds
	LOG_LEVEL	:=	20
endif

# Default build string (git branch and commit)
ifeq (${BUILD_STRING},)
	BUILD_STRING	:=	$(shell git log -n 1 --pretty=format:"%h")
endif

VERSION_STRING		:=	v${VERSION_MAJOR}.${VERSION_MINOR}(${BUILD_TYPE}):${BUILD_STRING}


################################################################################
# Toolchain
################################################################################

CC			:=	${CROSS_COMPILE}gcc
CPP			:=	${CROSS_COMPILE}cpp
AS			:=	${CROSS_COMPILE}gcc
AR			:=	${CROSS_COMPILE}ar
LD			:=	${CROSS_COMPILE}ld
OC			:=	${CROSS_COMPILE}objcopy
OD			:=	${CROSS_COMPILE}objdump
NM			:=	${CROSS_COMPILE}nm
PP			:=	${CROSS_COMPILE}gcc -E

ASFLAGS			+= 	-nostdinc -ffreestanding -Wa,--fatal-warnings	\
				-Werror -Wmissing-include-dirs			\
				-mgeneral-regs-only -D__ASSEMBLY__		\
				${DEFINES} ${INCLUDES}
CFLAGS			+= 	-nostdinc -ffreestanding -Wall			\
				-Werror -Wmissing-include-dirs			\
				-mgeneral-regs-only -mstrict-align		\
				-std=c99 -c -Os ${DEFINES} ${INCLUDES} -fno-pic
CFLAGS			+=	-ffunction-sections -fdata-sections		\
				-fno-delete-null-pointer-checks

LDFLAGS			+=	--fatal-warnings -O1
LDFLAGS			+=	--gc-sections


################################################################################
# Common sources and include directories
################################################################################

BL_COMMON_SOURCES	+=	common/bl_common.c			\
				common/tf_printf.c			\
				common/aarch64/debug.S			\
				lib/aarch64/cache_helpers.S		\
				lib/aarch64/misc_helpers.S		\
				lib/aarch64/xlat_helpers.c		\
				lib/stdlib/std.c			\
				plat/common/aarch64/platform_helpers.S

INCLUDES		+=	-Iinclude/common		\
				-Iinclude/drivers		\
				-Iinclude/drivers/arm		\
				-Iinclude/drivers/io		\
				-Iinclude/lib			\
				-Iinclude/lib/aarch64		\
				-Iinclude/lib/cpus/aarch64	\
				-Iinclude/plat/common		\
				-Iinclude/stdlib		\
				-Iinclude/stdlib/sys		\
				${PLAT_INCLUDES}		\
				${SPD_INCLUDES}


################################################################################
# Generic definitions
################################################################################

BUILD_BASE		:=	./build
BUILD_PLAT		:=	${BUILD_BASE}/${PLAT}/${BUILD_TYPE}

PLATFORMS		:=	$(shell ls -I common plat/)
HELP_PLATFORMS		:=	$(shell echo ${PLATFORMS} | sed 's/ /|/g')

# Platforms providing their own TBB makefile may override this value
INCLUDE_TBBR_MK		:=	1


################################################################################
# Include SPD Makefile if one has been specified
################################################################################

ifneq (${SPD},none)
	# We expect to locate an spd.mk under the specified SPD directory
	SPD_MAKE	:=	$(shell m="services/spd/${SPD}/${SPD}.mk"; [ -f "$$m" ] && echo "$$m")

	ifeq (${SPD_MAKE},)
	        $(error Error: No services/spd/${SPD}/${SPD}.mk located)
	endif
	$(info Including ${SPD_MAKE})
	include ${SPD_MAKE}

	# If there's BL3-2 companion for the chosen SPD, and the SPD wants to build the
	# BL3-2 from source, we expect that the SPD's Makefile would set NEED_BL32
	# variable to "yes". In case the BL3-2 is a binary which needs to be included in
	# fip, then the NEED_BL32 needs to be set and BL3-2 would need to point to the bin.
endif

################################################################################
# Include the platform specific Makefile after the SPD Makefile (the platform
# makefile may use all previous definitions in this file)
################################################################################

ifeq (${PLAT},)
	$(error "Error: Unknown platform. Please use PLAT=<platform name> to specify the platform.")
endif
ifeq ($(findstring ${PLAT},${PLATFORMS}),)
  $(error "Error: Invalid platform. The following platforms are available: ${PLATFORMS}")
endif

include plat/${PLAT}/platform.mk

# Include the CPU specific operations makefile. By default all CPU errata
# workarounds and CPU specifc optimisations are disabled. This can be
# overridden by the platform.
include lib/cpus/cpu-ops.mk

################################################################################
# Process platform overrideable behaviour
################################################################################

# Check if -pedantic option should be used
ifeq (${DISABLE_PEDANTIC},0)
        CFLAGS		+= 	-pedantic
endif

################################################################################
# Build options checks
################################################################################
$(eval $(call assert_boolean,NS_TIMER_SWITCH))
$(eval $(call assert_boolean,CTX_INCLUDE_FPREGS))
$(eval $(call assert_boolean,ASM_ASSERTION))
$(eval $(call assert_boolean,USE_COHERENT_MEM))

################################################################################
# Add definitions to the cpp preprocessor based on the current build options.
# This is done after including the platform specific makefile to allow the
# platform to overwrite the default options
################################################################################
$(eval $(call add_define,NS_TIMER_SWITCH))
$(eval $(call add_define,CTX_INCLUDE_FPREGS))
$(eval $(call add_define,ARM_GIC_ARCH))
$(eval $(call add_define,ASM_ASSERTION))
$(eval $(call add_define,LOG_LEVEL))
$(eval $(call add_define,USE_COHERENT_MEM))

################################################################################
# Include BL specific makefiles
################################################################################
ifdef BL1_SOURCES
NEED_BL1 := yes
include bl1/bl1.mk
endif

################################################################################
# Build targets
################################################################################
# Default target
.DEFAULT_GOAL := all
.PHONY:	all msg_start clean realclean distclean cscope locate-checkpatch checkcodebase checkpatch fiptool fip certtool
.SUFFIXES:
all: msg_start
msg_start:
	@echo "Building ${PLAT}"
# Expand build macros for the different images
ifeq (${NEED_BL1},yes)
$(eval $(call MAKE_BL,1))
endif

locate-checkpatch:
ifndef CHECKPATCH
	$(error "Please set CHECKPATCH to point to the Linux checkpatch.pl file, eg: CHECKPATCH=../linux/script/checkpatch.pl")
else
ifeq (,$(wildcard ${CHECKPATCH}))
	$(error "The file CHECKPATCH points to cannot be found, use eg: CHECKPATCH=../linux/script/checkpatch.pl")
endif
endif

clean:
	@echo "  CLEAN"
	${Q}rm -rf ${BUILD_PLAT}

realclean distclean:
	@echo "  REALCLEAN"
	${Q}rm -rf ${BUILD_BASE}
	${Q}rm -f ${CURDIR}/cscope.*

checkcodebase:		locate-checkpatch
	@echo "  CHECKING STYLE"
	@if test -d .git ; then	\
		git ls-files | grep -v stdlib | while read GIT_FILE ; do ${CHECKPATCH} ${CHECKCODE_ARGS} -f $$GIT_FILE ; done ;	\
	 else			\
		 find . -type f -not -iwholename "*.git*" -not -iwholename "*build*" -not -iwholename "*stdlib*" -exec ${CHECKPATCH} ${CHECKCODE_ARGS} -f {} \; ;	\
	 fi

checkpatch:		locate-checkpatch
	@echo "  CHECKING STYLE"
	@git format-patch --stdout ${BASE_COMMIT} | ${CHECKPATCH} ${CHECKPATCH_ARGS} - || true

cscope:
	@echo "  CSCOPE"
	${Q}find ${CURDIR} -name "*.[chsS]" > cscope.files
	${Q}cscope -b -q -k

help:
	@echo "usage: ${MAKE} PLAT=<${HELP_PLATFORMS}> <all|bl1|distclean|clean|checkcodebase|checkpatch>"
	@echo ""
	@echo "PLAT is used to specify which platform you wish to build."
	@echo "If no platform is specified, PLAT defaults to: ${DEFAULT_PLAT}"
	@echo ""
	@echo "Supported Targets:"
	@echo "  all            Build the BL1 binaries"
	@echo "  bl1            Build the BL1 binary"
	@echo "  checkcodebase  Check the coding style of the entire source tree"
	@echo "  checkpatch     Check the coding style on changes in the current"
	@echo "                 branch against BASE_COMMIT (default origin/master)"
	@echo "  clean          Clean the build for the selected platform"
	@echo "  cscope         Generate cscope index"
	@echo "  distclean      Remove all build artifacts for all platforms"
	@echo ""
	@echo "note: most build targets require PLAT to be set to a specific platform."
	@echo ""
	@echo "example: build all targets for the FVP platform:"
	@echo "  CROSS_COMPILE=aarch64-none-elf- make PLAT=fvp all"
