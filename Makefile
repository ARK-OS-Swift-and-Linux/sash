SWIFTC ?= swiftc
SWIFTFLAGS = -O

SWIFT_SRCS = Sources/sash/sash.swift Sources/sash/CommandDispatcher.swift Sources/sash/Builtins.swift Sources/sash/JobControl.swift

# Default host build
all: sash

sash: $(SWIFT_SRCS)
	$(SWIFTC) $(SWIFTFLAGS) $(SWIFT_SRCS) -o $@

test:
	swift test

# ==============================================================================
# Target Build Configuration (x86_64-swift-linux-musl)
# ==============================================================================
TARGET_TRIPLE ?= x86_64-swift-linux-musl
SWIFT_SDKS_DIR ?= $(HOME)/.swiftpm/swift-sdks
SWIFT_SDK_BUNDLE ?= $(firstword $(wildcard $(SWIFT_SDKS_DIR)/*static-linux*.artifactbundle))
TARGET_SYSROOT ?= $(firstword $(wildcard $(SWIFT_SDK_BUNDLE)/*/swift-linux-musl/musl-1.2.5.sdk/x86_64))
TARGET_RES_DIR ?= $(TARGET_SYSROOT)/usr/lib/swift_static
SYSROOT ?= ../../boot/build/sysroot
MIMALLOC_OBJ ?= $(SYSROOT)/lib/mimalloc.o

TARGET_SWIFTFLAGS = -target $(TARGET_TRIPLE) \
  -sdk $(TARGET_SYSROOT) \
  -resource-dir $(TARGET_RES_DIR) \
  -Xfrontend -use-static-resource-dir \
  -static-stdlib \
  -Xlinker -lswift_RegexParser \
  -O

TARGET_OUTPUT ?= sash.target

$(TARGET_OUTPUT): $(SWIFT_SRCS)
	@test -d "$(TARGET_SYSROOT)" || { echo "Error: TARGET_SYSROOT not found at $(TARGET_SYSROOT)."; exit 1; }
	@test -f "$(MIMALLOC_OBJ)" || { echo "Error: MIMALLOC_OBJ not found at $(MIMALLOC_OBJ)."; exit 1; }
	@echo "Linking $(TARGET_OUTPUT) with mimalloc object: $(MIMALLOC_OBJ)"
	$(SWIFTC) $(TARGET_SWIFTFLAGS) $(SWIFT_SRCS) "$(MIMALLOC_OBJ)" -o $@

target: $(TARGET_OUTPUT)

clean:
	rm -rf sash sash.target .build

.PHONY: all clean test target

