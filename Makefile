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
VERSION_MAJOR		:= 1
VERSION_MINOR		:= 1

#
# Default values for build configurations
#

# Build verbosity
V			:= 0
# Debug build
DEBUG			:= 0
# Build architecture
ARCH 			:= aarch64
# Build platform
DEFAULT_PLAT		:= hikey
PLAT			:= ${DEFAULT_PLAT}
# SPD choice
SPD			:= none
# Base commit to perform code check on
BASE_COMMIT		:= origin/master
# NS timer register save and restore
NS_TIMER_SWITCH		:= 0
# Include FP registers in cpu context
CTX_INCLUDE_FPREGS		:= 0
# Determine the version of ARM GIC architecture to use for interrupt management
# in EL3. The platform port can change this value if needed.
ARM_GIC_ARCH		:=	2
# Flag used to indicate if ASM_ASSERTION should be enabled for the build.
# This defaults to being present in DEBUG builds only.
ASM_ASSERTION		:=	${DEBUG}
# Build option to choose whether Trusted firmware uses Coherent memory or not.
USE_COHERENT_MEM	:=	1
# By default, use the -pedantic option in the gcc command line
DISABLE_PEDANTIC	:= 0
# Flags to generate the Chain of Trust
GENERATE_COT		:= 0
CREATE_KEYS		:= 1
# Flags to build TF with Trusted Boot support
TRUSTED_BOARD_BOOT	:= 0
AUTH_MOD		:= none

# Checkpatch ignores
CHECK_IGNORE		=	--ignore COMPLEX_MACRO

CHECKPATCH_ARGS		=	--no-tree --no-signoff ${CHECK_IGNORE}
CHECKCODE_ARGS		=	--no-patch --no-tree --no-signoff ${CHECK_IGNORE}

ifeq (${V},0)
	Q=@
	CHECKCODE_ARGS	+=	--no-summary --terse
else
	Q=
endif
export Q

ifneq (${DEBUG}, 0)
	BUILD_TYPE	:=	debug
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

BL_COMMON_SOURCES	:=	common/bl_common.c			\
				common/tf_printf.c			\
				common/aarch64/debug.S			\
				lib/aarch64/cache_helpers.S		\
				lib/aarch64/misc_helpers.S		\
				lib/aarch64/xlat_helpers.c		\
				lib/stdlib/std.c			\
				plat/common/aarch64/platform_helpers.S

BUILD_BASE		:=	./build
BUILD_PLAT		:=	${BUILD_BASE}/${PLAT}/${BUILD_TYPE}

PLATFORMS		:=	$(shell ls -I common plat/)
HELP_PLATFORMS		:=	$(shell echo ${PLATFORMS} | sed 's/ /|/g')

# Convenience function for adding build definitions
# $(eval $(call add_define,FOO)) will have:
# -DFOO if $(FOO) is empty; -DFOO=$(FOO) otherwise
define add_define
DEFINES			+=	-D$(1)$(if $(value $(1)),=$(value $(1)),)
endef

# Convenience function for verifying option has a boolean value
# $(eval $(call assert_boolean,FOO)) will assert FOO is 0 or 1
define assert_boolean
$(and $(patsubst 0,,$(value $(1))),$(patsubst 1,,$(value $(1))),$(error $(1) must be boolean))
endef

ifeq (${PLAT},)
  $(error "Error: Unknown platform. Please use PLAT=<platform name> to specify the platform.")
endif
ifeq ($(findstring ${PLAT},${PLATFORMS}),)
  $(error "Error: Invalid platform. The following platforms are available: ${PLATFORMS}")
endif

all: msg_start

msg_start:
	@echo "Building ${PLAT}"

include plat/${PLAT}/platform.mk

# Include the CPU specific operations makefile. By default all CPU errata
# workarounds and CPU specifc optimisations are disabled. This can be
# overridden by the platform.
include lib/cpus/cpu-ops.mk

ifdef BL1_SOURCES
NEED_BL1 := yes
include bl1/bl1.mk
endif

.PHONY:			all msg_start clean realclean distclean cscope locate-checkpatch checkcodebase checkpatch
.SUFFIXES:

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

# Process DEBUG flag
$(eval $(call assert_boolean,DEBUG))
$(eval $(call add_define,DEBUG))
ifeq (${DEBUG},0)
  $(eval $(call add_define,NDEBUG))
else
CFLAGS			+= 	-g
ASFLAGS			+= 	-g -Wa,--gdwarf-2
endif

# Process NS_TIMER_SWITCH flag
$(eval $(call assert_boolean,NS_TIMER_SWITCH))
$(eval $(call add_define,NS_TIMER_SWITCH))

# Process CTX_INCLUDE_FPREGS flag
$(eval $(call assert_boolean,CTX_INCLUDE_FPREGS))
$(eval $(call add_define,CTX_INCLUDE_FPREGS))

# Process ARM_GIC_ARCH flag
$(eval $(call add_define,ARM_GIC_ARCH))

# Process ASM_ASSERTION flag
$(eval $(call assert_boolean,ASM_ASSERTION))
$(eval $(call add_define,ASM_ASSERTION))

# Process LOG_LEVEL flag
$(eval $(call add_define,LOG_LEVEL))

# Process USE_COHERENT_MEM flag
$(eval $(call assert_boolean,USE_COHERENT_MEM))
$(eval $(call add_define,USE_COHERENT_MEM))

ASFLAGS			+= 	-nostdinc -ffreestanding -Wa,--fatal-warnings	\
				-Werror -Wmissing-include-dirs			\
				-mgeneral-regs-only -D__ASSEMBLY__		\
				${DEFINES} ${INCLUDES}
CFLAGS			+= 	-nostdinc -ffreestanding -Wall			\
				-Werror -Wmissing-include-dirs			\
				-mgeneral-regs-only -mstrict-align		\
				-std=c99 -c -Os	${DEFINES} ${INCLUDES} -fno-pic
CFLAGS			+=	-ffunction-sections -fdata-sections		\
				-fno-delete-null-pointer-checks

LDFLAGS			+=	--fatal-warnings -O1
LDFLAGS			+=	--gc-sections


CC			:=	${CROSS_COMPILE}gcc
CPP			:=	${CROSS_COMPILE}cpp
AS			:=	${CROSS_COMPILE}gcc
AR			:=	${CROSS_COMPILE}ar
LD			:=	${CROSS_COMPILE}ld
OC			:=	${CROSS_COMPILE}objcopy
OD			:=	${CROSS_COMPILE}objdump
NM			:=	${CROSS_COMPILE}nm
PP			:=	${CROSS_COMPILE}gcc -E ${CFLAGS}

# Check if -pedantic option should be used
ifeq (${DISABLE_PEDANTIC},0)
    CFLAGS		+= 	-pedantic
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

define match_goals
$(strip $(foreach goal,$(1),$(filter $(goal),$(MAKECMDGOALS))))
endef

# List of rules that involve building things
BUILD_TARGETS := all bl1

# Does the list of goals specified on the command line include a build target?
ifneq ($(call match_goals,${BUILD_TARGETS}),)
IS_ANYTHING_TO_BUILD := 1
endif

define MAKE_C

$(eval OBJ := $(1)/$(patsubst %.c,%.o,$(notdir $(2))))
$(eval PREREQUISITES := $(patsubst %.o,%.d,$(OBJ)))

$(OBJ) : $(2)
	@echo "  CC      $$<"
	$$(Q)$$(CC) $$(CFLAGS) -DIMAGE_BL$(3) -c $$< -o $$@


$(PREREQUISITES) : $(2)
	@echo "  DEPS    $$@"
	@mkdir -p $(1)
	$$(Q)$$(CC) $$(CFLAGS) -M -MT $(OBJ) -MF $$@ $$<

ifdef IS_ANYTHING_TO_BUILD
-include $(PREREQUISITES)
endif

endef


define MAKE_S

$(eval OBJ := $(1)/$(patsubst %.S,%.o,$(notdir $(2))))
$(eval PREREQUISITES := $(patsubst %.o,%.d,$(OBJ)))

$(OBJ) : $(2)
	@echo "  AS      $$<"
	$$(Q)$$(AS) $$(ASFLAGS) -DIMAGE_BL$(3) -c $$< -o $$@

$(PREREQUISITES) : $(2)
	@echo "  DEPS    $$@"
	@mkdir -p $(1)
	$$(Q)$$(AS) $$(ASFLAGS) -M -MT $(OBJ) -MF $$@ $$<

ifdef IS_ANYTHING_TO_BUILD
-include $(PREREQUISITES)
endif

endef


define MAKE_LD

$(eval PREREQUISITES := $(1).d)

$(1) : $(2)
	@echo "  PP      $$<"
	$$(Q)$$(AS) $$(ASFLAGS) -P -E -D__LINKER__ -o $$@ $$<

$(PREREQUISITES) : $(2)
	@echo "  DEPS    $$@"
	@mkdir -p $$(dir $$@)
	$$(Q)$$(AS) $$(ASFLAGS) -M -MT $(1) -MF $$@ $$<

ifdef IS_ANYTHING_TO_BUILD
-include $(PREREQUISITES)
endif

endef


define MAKE_OBJS
	$(eval C_OBJS := $(filter %.c,$(2)))
	$(eval REMAIN := $(filter-out %.c,$(2)))
	$(eval $(foreach obj,$(C_OBJS),$(call MAKE_C,$(1),$(obj),$(3))))

	$(eval S_OBJS := $(filter %.S,$(REMAIN)))
	$(eval REMAIN := $(filter-out %.S,$(REMAIN)))
	$(eval $(foreach obj,$(S_OBJS),$(call MAKE_S,$(1),$(obj),$(3))))

	$(and $(REMAIN),$(error Unexpected source files present: $(REMAIN)))
endef


# NOTE: The line continuation '\' is required in the next define otherwise we
# end up with a line-feed characer at the end of the last c filename.
# Also bare this issue in mind if extending the list of supported filetypes.
define SOURCES_TO_OBJS
	$(notdir $(patsubst %.c,%.o,$(filter %.c,$(1)))) \
	$(notdir $(patsubst %.S,%.o,$(filter %.S,$(1))))
endef


# MAKE_TOOL_ARGS macro defines the command line arguments for the FIP
# tools at each BL stage. Arguments:
#   $(1) = BL stage (2, 30, 31, 32, 33)
#   $(2) = Binary file
define MAKE_TOOL_ARGS

$(eval FIP_DEPS += $(if $3,$(2),))
$(eval FIP_ARGS += $(if $3,--bl$(1) $(2),))
$(eval FIP_ARGS += $(if $4,--bl$(1)-cert $(BUILD_PLAT)/bl$(1).crt))
$(eval FIP_ARGS += $(if $4,$(if $5,--bl$(1)-key-cert $(BUILD_PLAT)/bl$(1)_key.crt)))

endef


# MAKE_BL macro defines the targets and options to build each BL image.
# Arguments:
#   $(1) = BL stage (2, 30, 31, 32, 33)
define MAKE_BL
	$(eval BUILD_DIR  := ${BUILD_PLAT}/bl$(1))
	$(eval SOURCES    := $(BL$(1)_SOURCES) $(BL_COMMON_SOURCES) $(PLAT_BL_COMMON_SOURCES))
	$(eval OBJS       := $(addprefix $(BUILD_DIR)/,$(call SOURCES_TO_OBJS,$(SOURCES))))
	$(eval LINKERFILE := $(BUILD_DIR)/bl$(1).ld)
	$(eval MAPFILE    := $(BUILD_DIR)/bl$(1).map)
	$(eval ELF        := $(BUILD_DIR)/bl$(1).elf)
	$(eval DUMP       := $(BUILD_DIR)/bl$(1).dump)
	$(eval BIN        := $(BUILD_PLAT)/bl$(1).bin)

	$(eval $(call MAKE_OBJS,$(BUILD_DIR),$(SOURCES),$(1)))
	$(eval $(call MAKE_LD,$(LINKERFILE),$(BL$(1)_LINKERFILE)))

$(BUILD_DIR) :
	$$(Q)mkdir -p "$$@"

$(ELF) : $(OBJS) $(LINKERFILE)
	@echo "  LD      $$@"
	@echo 'const char build_message[] = "Built : "__TIME__", "__DATE__; \
	       const char version_string[] = "${VERSION_STRING}";' | \
		$$(CC) $$(CFLAGS) -xc - -o $(BUILD_DIR)/build_message.o
	$$(Q)$$(LD) -o $$@ $$(LDFLAGS) -Map=$(MAPFILE) --script $(LINKERFILE) \
					$(BUILD_DIR)/build_message.o $(OBJS)

$(DUMP) : $(ELF)
	@echo "  OD      $$@"
	$${Q}$${OD} -dx $$< > $$@

$(BIN) : $(ELF)
	@echo "  BIN     $$@"
	$$(Q)$$(OC) -O binary $$< $$@
	@echo
	@echo "Built $$@ successfully"
	@echo

.PHONY : bl$(1)
bl$(1) : $(BUILD_DIR) $(BIN) $(DUMP)

all : bl$(1)

$(eval $(call MAKE_TOOL_ARGS,$(1),$(BIN),$(2),$(3),$(4),$(5)))

endef


ifeq (${NEED_BL1},yes)
$(eval $(call MAKE_BL,1))
endif


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
