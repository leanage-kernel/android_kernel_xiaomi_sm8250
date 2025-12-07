#!/bin/bash

# LineageOS Kernel Build Script
# Uses AOSP Clang, ccache and AnyKernel3 for packaging

# Configuration
KERNEL_NAME="leanage"
OUT_DIR="$(pwd)/out"  # Output directory
ANYKERNEL_DIR="$(pwd)/AnyKernel3"  # AnyKernel3 directory
CLANG_DIR="$(pwd)/aosp-clang/clang-r547379"  # Path to AOSP Clang
ARCH="arm64"  # Target architecture
DEVICE_CODENAME="alioth"  # Change to your device codename
DEFCONFIG="${DEVICE_CODENAME}_defconfig"  # Your defconfig name
THREADS=$(nproc --all)  # Number of CPU threads for compilation

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Functions
function clean_build() {
    echo -e "${YELLOW}Cleaning previous build...${NC}"
    make O="$OUT_DIR" clean
    make O="$OUT_DIR" mrproper
    rm -rf "$OUT_DIR"
    mkdir -p "$OUT_DIR"
}

function prepare_anykernel() {
    echo -e "${YELLOW}Preparing AnyKernel3...${NC}"
    if [ ! -d "$ANYKERNEL_DIR" ]; then
        git clone https://github.com/osm0sis/AnyKernel3.git "$ANYKERNEL_DIR"
    else
        git -C "$ANYKERNEL_DIR" pull
    fi

    # AnyKernel3 is a git submodule, keep it clean
    # No need to remove files since we won't be creating them here anymore
}

function build_kernel() {
    echo -e "${YELLOW}Starting kernel build...${NC}"

    # Set up environment variables
    export PATH="$CLANG_DIR/bin:$PATH"
    export ARCH="$ARCH"
    export CROSS_COMPILE="aarch64-linux-gnu-"

    # Make defconfig
    echo -e "${GREEN}Generating defconfig...${NC}"
    make O="$OUT_DIR" "$DEFCONFIG" \
        LLVM=1

    # Start compilation
    echo -e "${GREEN}Compiling kernel with AOSP Clang...${NC}"
    make O="$OUT_DIR" -j"$THREADS" \
        CC="ccache clang" \
        LLVM=1 \
        LLVM_IAS=1

    # Check if build succeeded
    if [ ! -f "$OUT_DIR/arch/$ARCH/boot/Image" ]; then
        echo -e "${RED}Kernel compilation failed!${NC}"
        exit 1
    fi

    echo -e "${GREEN}Kernel compiled successfully!${NC}"
}

function package_kernel() {
    echo -e "${YELLOW}Packaging kernel with AnyKernel3...${NC}"

    # Create temporary packaging directory in out
    PACKAGE_DIR="$OUT_DIR/package"
    rm -rf "$PACKAGE_DIR"
    mkdir -p "$PACKAGE_DIR"

    # Copy AnyKernel3 files to temporary directory (excluding .git directory)
    cp -r "$ANYKERNEL_DIR"/* "$PACKAGE_DIR/" 2>/dev/null || true
    rm -rf "$PACKAGE_DIR/.git"

    # Copy kernel image
    if [ -f "$OUT_DIR/arch/$ARCH/boot/Image" ]; then
        cp "$OUT_DIR/arch/$ARCH/boot/Image" "$PACKAGE_DIR/"
    fi

    # Create zip in out directory
    cd "$PACKAGE_DIR" || exit
    zip -r9 "../${KERNEL_NAME}-${DEVICE_CODENAME}-$(date '+%Y%m%d-%H%M').zip" ./*
    cd - || exit

    # Clean up temporary directory
    rm -rf "$PACKAGE_DIR"

    echo -e "${GREEN}Kernel packaged successfully!${NC}"
    echo -e "${GREEN}Flashable zip created in: $OUT_DIR/${KERNEL_NAME}-${DEVICE_CODENAME}-$(date '+%Y%m%d-%H%M').zip${NC}"
}

# Main execution
echo -e "${GREEN}=== LineageOS Kernel Build Script ===${NC}"

# Check for AOSP Clang
if [ ! -d "$CLANG_DIR" ]; then
    echo -e "${RED}AOSP Clang not found at $CLANG_DIR${NC}"
    echo "Please download AOSP Clang and set the correct path in the script"
    echo "You can get it from: https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/"
    exit 1
fi

# Clean build
clean_build

# Prepare AnyKernel3
prepare_anykernel

# Build kernel
build_kernel

# Package kernel
package_kernel

echo -e "${GREEN}=== Build completed successfully! ===${NC}"
