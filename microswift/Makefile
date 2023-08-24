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

# try different versions of AVR GCC
AVR_GCC_BIN_DIR := /usr/local/bin
AVR_BINUTILS_DIR := /usr/local/bin

ifeq ($(wildcard $(AVR_GCC_BIN_DIR)/avr-gcc),)
AVR_GCC_BIN_DIR := /opt/homebrew/bin
AVR_BINUTILS_DIR := /opt/homebrew/bin # Binutils is probably in the same location as avr-gcc, if installed.
ifeq ($(wildcard $(AVR_GCC_BIN_DIR)/avr-gcc),)
$(error avr-gcc not found in the usual locations for homebrew, please check install. AVR GCC is required to build this package.)
endif
endif


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
.PHONY : all clean

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

all: $(FULL_BUILD_PATH) $(ALL_TARGETS)

clean:
	-rm -rf $(CLEAN_PATH) 2> /dev/null
	echo "Cleaned Files"

ifneq ($(FULL_BUILD_PATH),)
$(FULL_BUILD_PATH):
	mkdir -p $(FULL_BUILD_PATH)
endif

$(FULL_BUILD_PATH)lib$(MODULE_NAME).a: $(FULL_BUILD_PATH) $(ALL_CPP_OBJECTS)
	$(AR) -o $@ $(ALL_CPP_OBJECTS)

# automated dependencies, only for C/CPP
-include $(ALL_CLANG_DEPENDENCIES)

$(FULL_BUILD_PATH)Adafruit_FIFO.o: utility/Adafruit_FIFO.cpp
	$(GCC_PLUS) -c -o $@ $<

$(FULL_BUILD_PATH)%.o: %.cpp
	$(GCC_PLUS) -c -o $@ $<


# *** RECIPIES AND RULES ***

%.o : %.s

%.o : %.S

%.o : %.c
