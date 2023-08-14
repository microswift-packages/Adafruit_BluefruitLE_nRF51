



# *** DEFINITIONS AND VARIABLES ***
# (The primary ones, there are many other options.)
# define SCRIPTDIR as the top directory for the tools
# define OTHER_SWIFT_FILE to include library files
# define DEBUGMAKE=true or false to enable/disable debug on make actions
# define ADDITIONAL_C_FILES, ADDITIONAL_CPP_FILES and ADDITIONAL_ASM_FILES to include other C or C++ or assembly files to be built.

# expansion points created by IDE (mostly used in folder projects/command line... usually passed in environment for bundle projects)
SETTINGS_FOLDER = .project
-include $(SETTINGS_FOLDER)/paths.include
-include $(SETTINGS_FOLDER)/board.include
-include $(SETTINGS_FOLDER)/settings.include

# this expansion point is dynamically created from the project manifest on both folder and bundle projects
# marked as non optional because the build depends on it now, and it should always create
-include $(SETTINGS_FOLDER)/project.include

######
# Architecture specific
######

ifeq ($(ARCH),)
$(error "must define an architecture")
endif

ifeq ($(SCRIPTDIR),)
$(error "SCRIPTDIR must point to the build engine tool root")
endif

ifneq ($(BUILD_DIR),)
FULL_BUILD_PATH=$(BUILD_DIR)/
CLEAN_PATH=$(BUILD_DIR)
else
FULL_BUILD_PATH=build/
CLEAN_PATH=build
endif

ifeq ($(ARCH),AVR)
ARCH_INCLUDES ?= -I "$(AVR_LIBGCC_INCLUDE_DIR)" -I "$(AVR_LIBC_INCLUDE_DIR)"
ARCH_MODULE_DOC_INCLUDES ?= -I="$(AVR_LIBGCC_INCLUDE_DIR)" -I="$(AVR_LIBC_INCLUDE_DIR)"
ARCH_CLANG_INCLUDES ?= -isystem "$(AVR_LIBGCC_INCLUDE_DIR)" -isystem "$(AVR_LIBC_INCLUDE_DIR)"
ARCH_TARGET ?= avr-atmel-linux-gnueabihf
ARCH_GNU_TOOLS_BIN_DIR ?= $(ATMEL_GNU_AVR_TOOLCHAIN_BIN)
ARCH_TOOL_PREFIX ?= avr-

ARCH_GCC_OPTS = $(AVR_GCC_OPTS)
ARCH_CLANG_OPTS = $(AVR_CLANG_OPTS)
ARCH_DEFINES = $(AVR_DEFINES)
ARCH_SWIFT_ONLY_DEFINES = $(AVR_SWIFT_ONLY_DEFINES)
ARCH_INT_BIT_WIDTH = 16
ARCH_UPLOAD_FILE_FORMAT = HEX
endif





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


DEBUG_MAKE ?= yes
MAIN_SWIFT_FILE ?= main.swift
MAIN_SWIFT_BITCODE_FILE ?= $(FULL_BUILD_PATH)$(MAIN_SWIFT_FILE:.swift=.bc)

SWIFTC_DIR ?= $(SCRIPTDIR)/swift

ifneq ($(SUBARCH),)
SUBARCH_DIR=/$(SUBARCH)
endif


#llvm
REMOVE_LLVM_LINKER_METADATA ?= yes

#gnu avr binutils/gcc
LLVM_TOOLS_DIR ?= $(SCRIPTDIR)/llvm
SED ?= sed

BUILD_LOG ?= $(FULL_BUILD_PATH)build_log.txt
ERROR_LOG ?= $(FULL_BUILD_PATH)error_log.txt
ERROR_STATUSES ?= abort|error


OBJCOPY ?= "$(LINK_TOOLS_DIR)/$(ARCH_TOOL_PREFIX)objcopy"
OBJDUMP ?= "$(LINK_TOOLS_DIR)/$(ARCH_TOOL_PREFIX)objdump"

IL_TO_OBJ ?= "$(LLC)" $(LLC_OPTS)


AVRSIZE ?= "$(LINK_TOOLS_DIR)/$(ARCH_TOOL_PREFIX)size"
AR = "$(LINK_TOOLS_DIR)/$(ARCH_TOOL_PREFIX)ar" rcs
OUTPUT_MAP_FILE ?= $(FULL_BUILD_PATH)outputMap.json
SWIFT_EXT ?= swift

TARGET_OPTS ?= -target $(ARCH_TARGET)

MODULEMAP ?= $(wildcard ./module.modulemap)

# *** MAIN PHONEY TARGETS ***
.PHONY : all clean_buildlog upload clean diagnostics packages packages-clean packages-update packages-build
.PHONY : abort_check abort_analyze runtime_absence_check build_main_executable simulate simulate-gdb simulate-test.log
.PHONY : AVR_HW_LIB ARM_HW_LIB
.INTERMEDIATE : $(AUTOLINK_FILE)

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
ASM_ELF_FILE=$(ELF_FILE:.elf=.elf.s)
HEX_FILE=$(ELF_FILE:.elf=.hex)
BIN_FILE=$(ELF_FILE:.elf=.bin)

# C, C++, S
ALL_C_FILES = $(ADDITIONAL_C_FILES)
ALL_C_FILES_ND = $(notdir $(ALL_C_FILES))
ALL_C_INTERMEDIATES = $(patsubst %,$(FULL_BUILD_PATH)%,$(ALL_C_FILES_ND:.c=.c.bc))
ALL_C_OBJECTS = $(patsubst %,$(FULL_BUILD_PATH)%,$(ALL_C_FILES_ND:.c=.c.o))

ALL_CPP_FILES = $(ADDITIONAL_CPP_FILES)
ALL_CPP_FILES_ND = $(notdir $(ALL_CPP_FILES))
ALL_CPP_INTERMEDIATES = $(patsubst %,$(FULL_BUILD_PATH)%,$(ALL_CPP_FILES_ND:.cpp=.cpp.bc))
ALL_CPP_OBJECTS = $(patsubst %,$(FULL_BUILD_PATH)%,$(ALL_CPP_FILES_ND:.cpp=.cpp.o))


ALL_TARGETS := clean_buildlog $(ELF_FILE) $(ERROR_LOG) runtime_absence_check abort_check

ifeq ($(BUILD_MODULE_NAMED),)
# if we are NOT building a module, then we will want a HEX for upload, and diagnostics
ALL_TARGETS := $(ALL_TARGETS) $(HEX_FILE) diagnostics sizeReport flashSizeCheck ramSizeReport
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
scan_errors: $(ERROR_LOG)
.PHONY: scan_errors $(ERROR_LOG) # always recreate error log from latest build

$(SETTINGS_FOLDER):
	mkdir -p $@


#project file define
PROJECT_FILES = $(shell ls *.swift4p 2>/dev/null|tr ' ' '?')
# note, we use this weird form instead of $(wildcard *.swift4p) in order to handle spaces in filenames
$(SETTINGS_FOLDER)/project.include: $(SETTINGS_FOLDER) $(PROJECT_FILES)
	cat /dev/null > $@
	[ -n "$(PROJECT_FILES)" ] && "$(SCRIPTDIR)/read_project.awk" $(PROJECT_FILES) >> $@

ifeq ($(ARCH_UPLOAD_FILE_FORMAT),HEX)
upload: upload-$(notdir $(HEX_FILE))
else ifeq ($(ARCH_UPLOAD_FILE_FORMAT),BIN)
upload: upload-$(notdir $(BIN_FILE))
endif

clean:
	-rm -rf $(CLEAN_PATH) 2> /dev/null
	echo "Cleaned Files"

clean_buildlog:
	cat /dev/null > $(BUILD_LOG)

ifeq ($(wildcard Package.swift),)

packages-clean:
packages-update:
packages-build:
packages:

else

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

endif

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

ifneq ($(EXPORT_MODULE_PATH),)
$(EXPORT_MODULE_PATH): $(MODULE_OUTPUT_FILES) $(FULL_BUILD_PATH)lib$(MODULE_NAME).a $(wildcard ./module.modulemap) $(wildcard ./*.h)
	-rm -rf "$@" 2> /dev/null
	mkdir -p "$@"
	cp -a $^ "$@"/
endif

endif

$(ERROR_LOG):
	-@grep -hE "^.*\.swift:[0-9]+:[0-9]+: ($(ERROR_STATUSES)):" $(BUILD_LOG) $(ELF_LINKER_OUTPUT_FILE) > $@

# automated dependencies, only for C/CPP, swift should automatically depend on all swift files in the module (see below)
# note this still misses swift's downward dependencies on a tree of .h files, not sure how to fix that
-include $(ALL_CLANG_DEPENDENCIES)


# *** RECIPIES AND RULES ***

ifeq ($(DEBUGMAKE),true)
.PRECIOUS : %.bc %.ll %.elf %.o %.sil *.bin *.hex
endif

%.ll : %.bc
	"$(LLVM-DIS)" $<

%.o : %.s

%.o : %.S

%.o : %.c

%.sil : %.swift
	$(SWIFT_TO_SIL) -o $@ $<

%.csil : %.swift
	$(SWIFT_TO_CSIL) -o $@ $<

# Generic rule to build the object file from intermediate for swift intermediates other than main
%.o : %.bc
	$(IL_TO_OBJ) -o $@ $(@:.o=.bc)
	echo "Compiled $<"

%.hex : %.elf
	$(OBJCOPY) -j .text -j .data -O ihex $< $@
	echo "Made HEX"

%.bin : %.elf
	$(OBJCOPY) -j .text -j .data -O binary $< $@
	echo "Made BIN"

%.elf.s : %.elf
	$(OBJDUMP) -d -x -z -j .data -j .text $< > $@

%.o.s : %.o
	$(OBJDUMP) -d -x -z $< > $@

