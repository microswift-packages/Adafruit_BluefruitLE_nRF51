SETTINGS_FOLDER = .project
-include $(SETTINGS_FOLDER)/paths.include
-include $(SETTINGS_FOLDER)/board.include
-include $(SETTINGS_FOLDER)/settings.include

# this expansion point is dynamically created from the project manifest on both folder and bundle projects
# marked as non optional because the build depends on it now, and it should always create
-include $(SETTINGS_FOLDER)/project.include

FULL_BUILD_PATH=build/
CLEAN_PATH=build

ARCH_INCLUDES ?= -I "$(AVR_LIBGCC_INCLUDE_DIR)" -I "$(AVR_LIBC_INCLUDE_DIR)"
ARCH_MODULE_DOC_INCLUDES ?= -I="$(AVR_LIBGCC_INCLUDE_DIR)" -I="$(AVR_LIBC_INCLUDE_DIR)"
ARCH_CLANG_INCLUDES ?= -isystem "$(AVR_LIBGCC_INCLUDE_DIR)" -isystem "$(AVR_LIBC_INCLUDE_DIR)"
ARCH_TARGET ?= avr-atmel-linux-gnueabihf
ARCH_GNU_TOOLS_BIN_DIR ?= $(ATMEL_GNU_AVR_TOOLCHAIN_BIN)
ARCH_TOOL_PREFIX ?= avr-

ARCH_GCC_OPTS = $(AVR_GCC_OPTS)
ARCH_DEFINES = $(AVR_DEFINES)
ARCH_INT_BIT_WIDTH = 16

#####
# AVR
#####

ifeq ($(subst ',,$(AVR_TINY_STACK)),yes)
AVR_CORE_SUFFIX=/tiny-stack
endif

AVR_LIBC_SUBDIR ?= avr-libc/lib/$(CORE)$(AVR_CORE_SUFFIX)
AVR_LIBC_INCLUDE_SUBDIR ?= avr-libc/include
AVR_LIBGCC_SUBDIR ?= avr-libgcc/$(CORE)$(AVR_CORE_SUFFIX)
AVR_LIBGCC_INCLUDE_SUBDIR ?= avr-libgcc/include
AVR_LD_SCRIPTS_SUBDIR ?= avr-binutils/avr/lib/ldscripts

AVR_LIBC_DIR ?= $(AVR_LINK_LIBRARIES_DIR)/$(AVR_LIBC_SUBDIR)
AVR_LIBC_INCLUDE_DIR ?= $(AVR_LINK_LIBRARIES_DIR)/$(AVR_LIBC_INCLUDE_SUBDIR)
AVR_LIBGCC_DIR ?= $(AVR_LINK_LIBRARIES_DIR)/$(AVR_LIBGCC_SUBDIR)
AVR_LIBGCC_INCLUDE_DIR ?= $(AVR_LINK_LIBRARIES_DIR)/$(AVR_LIBGCC_INCLUDE_SUBDIR)

AVR_CLANG_OPTS = -march=$(CORE)
AVR_DEFINES = -DAVR_LIBC_DEFINED -DLIBC_DEFINED -D$(MCUMACRO) -DF_CPU=$(CPU_FREQUENCY)
#default to Arduino UNO (Atmega 328P)
MCU ?= atmega328p
CORE ?= avr5

# normally llvm will use the same mcu but in some cases (e.g. atmega4809) support is not there yet
# so we will need to specify an override
LLC_MCU ?= $(CORE)

########
# Shared
########

ifneq ($(SUBARCH),)
SUBARCH_DIR=/$(SUBARCH)
endif

#llvm
REMOVE_LLVM_LINKER_METADATA ?= yes

#gnu avr binutils/gcc
SED ?= sed

OBJCOPY ?= "$(LINK_TOOLS_DIR)/$(ARCH_TOOL_PREFIX)objcopy"
OBJDUMP ?= "$(LINK_TOOLS_DIR)/$(ARCH_TOOL_PREFIX)objdump"

AR = "$(LINK_TOOLS_DIR)/$(ARCH_TOOL_PREFIX)ar" rcs

TARGET_OPTS ?= -target $(ARCH_TARGET)

MODULEMAP ?= $(wildcard ./module.modulemap)

# *** MAIN PHONEY TARGETS ***
.PHONY : all clean packages packages-clean packages-update packages-build

# find the module to build if appropriate
ifeq ($(FIND_MODULE_MAP),yes)
# read the module name from the modulemap file
# try to run this command only once, use simple rather than recursive variable
BUILD_MODULE_NAMED := $(shell sed -nEe '/^module /s/^module (.*) .*$$/\1/p' module.modulemap)
# modules must not have a main.swift, it is a compile error
MAIN_SWIFT_FILE =
endif

# main targets
OBJ_FILE=$(FULL_BUILD_PATH)$(MAIN_SWIFT_FILE:.swift=.o)
MAIN_MODULE_NAME=$(MAIN_SWIFT_FILE:.swift=)
ELF_FILE=$(FULL_BUILD_PATH)$(MAIN_SWIFT_FILE:.swift=.elf)
ELF_LINKER_OUTPUT_FILE=$(ELF_FILE:.elf=.elf.linkerOutput.txt)

# C, C++, S

ALL_CPP_FILES = $(ADDITIONAL_CPP_FILES)
ALL_CPP_FILES_ND = $(notdir $(ALL_CPP_FILES))
ALL_CPP_INTERMEDIATES = $(patsubst %,$(FULL_BUILD_PATH)%,$(ALL_CPP_FILES_ND:.cpp=.cpp.bc))
ALL_CPP_OBJECTS = $(patsubst %,$(FULL_BUILD_PATH)%,$(ALL_CPP_FILES_ND:.cpp=.cpp.o))

ALL_TARGETS :=

ifeq ($(BUILD_MODULE_NAMED),)
# if we are NOT building a module, then we will want a HEX for upload, and diagnostics
MODULE_NAME = $(MAIN_MODULE_NAME)
else
# we assume EXPORT_MODULE_PATH must be set, or it is an error
.PHONY: $(EXPORT_MODULE_PATH)
ifneq ($(EXPORT_MODULE_PATH),)
ALL_TARGETS := clean_buildlog $(EXPORT_MODULE_PATH)
else
# unexpected fallback, for a build with no export directory, just build the module binaries
ALL_TARGETS := $(MODULE_OUTPUT_FILES) $(FULL_BUILD_PATH)lib$(MODULE_NAME).a
endif
# modules do not use main.swift, it is a compilation error
MAIN_SWIFT_FILE =
MODULE_NAME = $(BUILD_MODULE_NAMED)
endif


# note this kills exit code so use set -o pipefail
APPEND_BUILD_LOG ?= 2>&1|tee -a $(BUILD_LOG)

PACKAGE_DIR = .build
PACKAGE_MODULES_DIR = .build/checkouts

#packages
all: $(FULL_BUILD_PATH) $(ALL_TARGETS)

$(SETTINGS_FOLDER):
	mkdir -p $@

clean:
	-rm -rf $(CLEAN_PATH) 2> /dev/null
	echo "Cleaned Files"

clean_buildlog:
	cat /dev/null > $(BUILD_LOG)

PACKAGE_SUBDIRS = $(sort $(basename $(dir $(wildcard $(PACKAGE_MODULES_DIR)/*/))))
PACKAGES = $(foreach dir,$(PACKAGE_SUBDIRS),$(shell basename $(dir)))
$(info $(PACKAGE_SUBDIRS))

packages-clean:
	-rm -rf $(PACKAGE_DIR)

packages-update:
	swift package update

packages-build: $(PACKAGE_SUBDIRS)
	for i in $^; do make -C $$i; done

packages: packages-update packages-build

SWIFTC_PACKAGES_OPTS = $(PACKAGE_SUBDIRS:%=-I%)
C_PACKAGES_OPTS = $(PACKAGE_SUBDIRS:%=-I%)
LINK_PACKAGES_OPTS = $(PACKAGE_SUBDIRS:%=-L%)

ifneq ($(FULL_BUILD_PATH),)
$(FULL_BUILD_PATH):
	mkdir -p $(FULL_BUILD_PATH)
endif

ifeq ($(BUILD_MODULE_NAMED),)

else
# alternative, when building a library...

$(FULL_BUILD_PATH)lib$(MODULE_NAME).a: $(FULL_BUILD_PATH) $(ALL_SWIFT_OBJECTS) $(ALL_C_OBJECTS) $(ALL_CPP_OBJECTS) $(ALL_ASM_OBJECTS)
	@echo "** Create library $(MODULE_NAME)"
	set -o pipefail && $(AR) -o $@ $(ALL_SWIFT_OBJECTS) $(ALL_C_OBJECTS) $(ALL_CPP_OBJECTS) $(ALL_ASM_OBJECTS) $(APPEND_BUILD_LOG)

endif


# automated dependencies, only for C/CPP, swift should automatically depend on all swift files in the module (see below)
# note this still misses swift's downward dependencies on a tree of .h files, not sure how to fix that
-include $(ALL_CLANG_DEPENDENCIES)


# *** RECIPIES AND RULES ***

%.o : %.s

%.o : %.S

%.o : %.c
