SOURCE_DIR=/Users/carlpeto/Documents/Code/Adafruit_BluefruitLE_nRF51
CPU_FREQUENCY=16000000
MCU=atmega328p
MAKE_TARGET=all
CPP_EXTRA_DEFINES=-DARDUINO=100
ARDUINO_LIB_CLANG_OPTIONS=-DARDUINO=101
ADDITIONAL_CPP_FILES = Adafruit_BLEBattery.cpp Adafruit_BLEEddystone.cpp Adafruit_BLEGatt.cpp \
Adafruit_BLEMIDI.cpp Adafruit_BluefruitLE_SPI.cpp Adafruit_BluefruitLE_UART.cpp \
utility/Adafruit_FIFO.cpp Adafruit_ATParser.cpp Adafruit_BLE.cpp


FULL_BUILD_PATH=bin/
CLEAN_PATH=bin

ARCH_INCLUDES ?= -I "$(AVR_LIBGCC_INCLUDE_DIR)" -I "$(AVR_LIBC_INCLUDE_DIR)"
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

AVR_BINUTILS_DIR=/usr/local/bin
AVR_GCC_BIN_DIR=/usr/local/bin

CPP_OPTS=-std=c++11 -ffunction-sections -Os
AR_OPTS=rcs

GCC_PLUS_OPTS=-mmcu=$(MCU) $(CPP_OPTS) -I. $(C_PACKAGES_OPTS) $(AVR_DEFINES) $(ARCH_CLANG_INCLUDES) 
AR="$(AVR_BINUTILS_DIR)/avr-ar" $(AR_OPTS)
GCC_PLUS_BIN=$(AVR_GCC_BIN_DIR)/avr-gcc
GCC_PLUS="$(GCC_PLUS_BIN)" $(GCC_PLUS_OPTS)

AVR_LIBC_SUBDIR ?= avr-libc/lib/$(CORE)$(AVR_CORE_SUFFIX)
AVR_LIBC_INCLUDE_SUBDIR ?= avr-libc/include
AVR_LIBGCC_SUBDIR ?= avr-libgcc/$(CORE)$(AVR_CORE_SUFFIX)
AVR_LIBGCC_INCLUDE_SUBDIR ?= avr-libgcc/include
AVR_LD_SCRIPTS_SUBDIR ?= avr-binutils/avr/lib/ldscripts

AVR_LIBC_DIR ?= $(AVR_LINK_LIBRARIES_DIR)/$(AVR_LIBC_SUBDIR)
AVR_LIBC_INCLUDE_DIR ?= $(AVR_LINK_LIBRARIES_DIR)/$(AVR_LIBC_INCLUDE_SUBDIR)
AVR_LIBGCC_DIR ?= $(AVR_LINK_LIBRARIES_DIR)/$(AVR_LIBGCC_SUBDIR)
AVR_LIBGCC_INCLUDE_DIR ?= $(AVR_LINK_LIBRARIES_DIR)/$(AVR_LIBGCC_INCLUDE_SUBDIR)

AVR_LINK_LIBRARIES_DIR ?= $(SCRIPTDIR)/gpl-tools-avr/lib

SCRIPTDIR ?= /Applications/Swift For Arduino.app/Contents/XPCServices/BuildEngine.xpc/Contents/Resources

AVR_CLANG_OPTS = -march=$(CORE)
AVR_DEFINES = -DAVR_LIBC_DEFINED -DLIBC_DEFINED -DF_CPU=$(CPU_FREQUENCY)
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

TARGET_OPTS ?= -target $(ARCH_TARGET)

MODULEMAP ?= $(wildcard ./module.modulemap)

# *** MAIN PHONEY TARGETS ***
.PHONY : all clean packages packages-clean packages-update packages-build

# find the module to build if appropriate
# read the module name from the modulemap file
# try to run this command only once, use simple rather than recursive variable
BUILD_MODULE_NAMED := $(shell sed -nEe '/^module /s/^module (.*) .*$$/\1/p' module.modulemap)

MODULE_NAME = $(BUILD_MODULE_NAMED)

# C, C++, S

ALL_CPP_FILES = $(ADDITIONAL_CPP_FILES)
ALL_CPP_FILES_ND = $(notdir $(ALL_CPP_FILES))
ALL_CPP_OBJECTS = $(patsubst %,$(FULL_BUILD_PATH)%,$(ALL_CPP_FILES_ND:.cpp=.o))

ALL_TARGETS := $(FULL_BUILD_PATH)lib$(MODULE_NAME).a

PACKAGE_DIR = .build
PACKAGE_MODULES_DIR = .build/checkouts

BIN_DIR_EXISTS = $(shell test -d $(BIN_DIR) && echo "EXISTS")
IS_CURRENT_DIR_READONLY = $(shell test -w . || echo "READONLY")
IS_BIN_DIR_READONLY = $(shell test -d $(BIN_DIR) && (test -w $(BIN_DIR) || echo "READONLY"))

ifneq ($(wildcard $(GCC_PLUS_BIN)),)

# AVR GCC exists, so we can build.

ifeq ($(IS_BIN_DIR_READONLY),READONLY)
$(info Read only binary directory found, relying on pre-built binaries.)
all:
	echo "DONE"
else
all: packages $(FULL_BUILD_PATH) $(ALL_TARGETS)
endif

else

# AVR GCC not found, so we cannot build, or don't know how. We must have a pre-built binary
# or we can't do anything. We won't report an error though in that case, just in case.

ifneq ($(BIN_DIR_EXISTS),EXISTS)
$(info avr-gcc not found at $(GCC_PLUS_BIN) and no pre-built binaries exist at $(BIN_DIR)... stopping...)
all:
	echo "CANNOT BUILD"
else
$(info avr-gcc not found at $(GCC_PLUS_BIN), relying on pre-built binaries only)
all:
	echo "DONE"
endif

endif

clean:
	-rm -rf $(CLEAN_PATH) 2> /dev/null
	echo "Cleaned Files"

PACKAGE_SUBDIRS = $(sort $(basename $(dir $(wildcard $(PACKAGE_MODULES_DIR)/*/))))
PACKAGES = $(foreach dir,$(PACKAGE_SUBDIRS),$(shell basename $(dir)))

packages-clean:
	-rm -rf $(PACKAGE_DIR)
	-rm Package.resolved

packages-update:
	swift package update

packages-build: $(PACKAGE_SUBDIRS)
	for i in $^; do echo Making $$i;make -C $$i; done

ifeq ($(IS_CURRENT_DIR_READONLY),READONLY)
$(info Current directory is readonly, assuming this is a downloaded SPM package.)
packages:
	echo "Transitive dependencies skipped"
else
packages: packages-update packages-build
endif

SWIFTC_PACKAGES_OPTS = $(PACKAGE_SUBDIRS:%=-I%)
C_PACKAGES_OPTS = $(PACKAGE_SUBDIRS:%=-I%)
LINK_PACKAGES_OPTS = $(PACKAGE_SUBDIRS:%=-L%)

ifneq ($(FULL_BUILD_PATH),)
$(FULL_BUILD_PATH):
	mkdir -p $(FULL_BUILD_PATH)
endif

$(FULL_BUILD_PATH)lib$(MODULE_NAME).a: $(FULL_BUILD_PATH) $(ALL_CPP_OBJECTS)
	$(AR) -o $@ $(ALL_CPP_OBJECTS)

# automated dependencies, only for C/CPP
-include $(ALL_CLANG_DEPENDENCIES)

$(info PACKAGE_SUBDIRS $(PACKAGE_SUBDIRS))

$(FULL_BUILD_PATH)Adafruit_FIFO.o: utility/Adafruit_FIFO.cpp
	$(GCC_PLUS) -c -o $@ $<

$(FULL_BUILD_PATH)%.o: %.cpp
	$(GCC_PLUS) -c -o $@ $<


# *** RECIPIES AND RULES ***

%.o : %.s

%.o : %.S

%.o : %.c
