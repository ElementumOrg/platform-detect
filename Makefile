CC = cc
CXX = c++

ifneq ($(CROSS_TRIPLE),)
	CC := $(CROSS_TRIPLE)-$(CC)
	CXX := $(CROSS_TRIPLE)-$(CXX)
endif

ifeq ($(TARGET_OS), windows)
	EXT = .dll
else ifeq ($(TARGET_OS), darwin)
	EXT = .so
	# Needs this or cgo will try to link with libgcc, which will fail
	CC := $(CROSS_ROOT)/bin/$(CROSS_TRIPLE)-clang
	CXX := $(CROSS_ROOT)/bin/$(CROSS_TRIPLE)-clang++
	LDFLAGS += "-lm"
else ifeq ($(TARGET_OS), linux)
	EXT = .so
else ifeq ($(TARGET_OS), android)
	EXT = .so
	CC := $(CROSS_ROOT)/bin/$(CROSS_TRIPLE)-clang
	CXX := $(CROSS_ROOT)/bin/$(CROSS_TRIPLE)-clang++
endif

PROJECT = elementumorg
NAME = test
GIT = git
DOCKER = docker
DOCKER_IMAGE = elementumorg/cross-compiler
OBJECT_NAME = $(NAME).o
OUTPUT_NAME = $(NAME)$(EXT)

BUILD_PATH = build/$(TARGET_OS)_$(TARGET_ARCH)
LIBRARY_PATH = libraries/$(TARGET_OS)_$(TARGET_ARCH)

ANDROID_PLATFORMS = \
	android-arm \
	android-arm64 \
	android-x64 \
	android-x86
LINUX_PLATFORMS = \
	linux-armv6 \
	linux-armv7 \
	linux-arm64 \
	linux-x64 \
	linux-x86
WINDOWS_PLATFORMS = \
	windows-x64 \
	windows-x86
DARWIN_PLATFORMS = \
	darwin-x64

PLATFORMS =	$(ANDROID_PLATFORMS) $(LINUX_PLATFORMS) $(WINDOWS_PLATFORMS) $(DARWIN_PLATFORMS)


.PHONY: $(PLATFORMS)

all:
	for i in $(PLATFORMS); do \
		$(MAKE) $$i; \
	done

$(PLATFORMS):
	$(MAKE) build TARGET_OS=$(firstword $(subst -, ,$@)) TARGET_ARCH=$(word 2, $(subst -, ,$@))

force:
	@true

$(BUILD_PATH):
	mkdir -p $(BUILD_PATH)

$(LIBRARY_PATH):
	mkdir -p $(LIBRARY_PATH)

$(LIBRARY_PATH)/$(OUTPUT_NAME): $(BUILD_PATH) $(LIBRARY_PATH) force
	# Make object file
	LDFLAGS='$(LDFLAGS)' \
	CFLAGS='$(CFLAGS)' \
	CC='$(CC)' CXX='$(CXX)' \
	$(CC) \
		-c -o '$(BUILD_PATH)/$(OBJECT_NAME)' \
		src/test.c

	# Make library
	LDFLAGS='$(LDFLAGS)' \
	CFLAGS='$(CFLAGS)' \
	CC='$(CC)' CXX='$(CXX)' \
	$(CC) \
		--shared -o '$(LIBRARY_PATH)/$(OUTPUT_NAME)' \
		'$(BUILD_PATH)/$(OBJECT_NAME)'
	chmod -R 777 $(BUILD_PATH)

	# Copy header file
	cp src/test.h $(LIBRARY_PATH)/
	# Cleanuip object file
	rm -f '$(BUILD_PATH)/$(OBJECT_NAME)'

vendor_darwin vendor_linux:

vendor_windows:

vendor_android:

vendor_libs_windows:

vendor_libs_android:

lib: $(LIBRARY_PATH)/$(OUTPUT_NAME)

re: clean build

clean:
	rm -rf $(BUILD_PATH)
	rm -rf $(LIBRARY_PATH)

distclean:
	rm -rf build

build: force
	$(DOCKER) run --rm -v $(shell pwd):/src/ --ulimit memlock=67108864 -w /src/ $(DOCKER_IMAGE):$(TARGET_OS)-$(TARGET_ARCH) make dist TARGET_OS=$(TARGET_OS) TARGET_ARCH=$(TARGET_ARCH)

docker: force
	$(DOCKER) run --rm -v $(shell pwd):/src/ --ulimit memlock=67108864 -w /src/ $(DOCKER_IMAGE):$(TARGET_OS)-$(TARGET_ARCH)

dist: lib vendor_$(TARGET_OS) 

pull-all:
	for i in $(PLATFORMS); do \
		docker pull $(DOCKER_IMAGE):$$i; \
	done

pull:
	docker pull $(DOCKER_IMAGE):$(PLATFORM)
