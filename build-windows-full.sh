#!/bin/bash
# Build script for FULL-FEATURED Windows DLL (via JAR + IKVM)
# This builds the REAL Bluetooth implementation, not the stub

echo "========================================="
echo "Building FULL-FEATURED Windows DLL"
echo "========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Step 1: Build Windows JAR (contains FULL Bluetooth implementation)
echo -e "\n${YELLOW}[1/3] Building Windows JAR with FULL Bluetooth API...${NC}"
./gradlew :nioxplugin:buildWindowsJar

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to build Windows JAR${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Windows JAR built successfully${NC}"
JAR_PATH="nioxplugin/build/outputs/windows/niox-communication-plugin-windows-1.0.0.jar"
echo -e "  Location: $JAR_PATH"

# Check if JAR exists
if [ ! -f "$JAR_PATH" ]; then
    echo -e "${RED}❌ JAR file not found at expected location${NC}"
    exit 1
fi

# Step 2: Check if IKVM is installed
echo -e "\n${YELLOW}[2/3] Checking for IKVM...${NC}"

if ! command -v ikvmc &> /dev/null; then
    echo -e "${YELLOW}⚠ IKVM not found. Installing IKVM...${NC}"
    dotnet tool install -g ikvm

    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to install IKVM${NC}"
        echo -e "${YELLOW}Please install manually: dotnet tool install -g ikvm${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ IKVM installed successfully${NC}"
else
    echo -e "${GREEN}✓ IKVM is already installed${NC}"
    IKVM_VERSION=$(ikvmc -version 2>&1 | head -1)
    echo -e "  Version: $IKVM_VERSION"
fi

# Step 3: Convert JAR to DLL using IKVM
echo -e "\n${YELLOW}[3/3] Converting JAR to .NET DLL...${NC}"

OUTPUT_DIR="nioxplugin/build/outputs/windows"
DLL_PATH="$OUTPUT_DIR/NioxPlugin.dll"

# Change to output directory
cd "$OUTPUT_DIR" || exit 1

# Run IKVM conversion
ikvmc -target:library \
     -out:NioxPlugin.dll \
     -version:1.0.0.0 \
     niox-communication-plugin-windows-1.0.0.jar

IKVM_EXIT_CODE=$?

# Return to original directory
cd - > /dev/null || exit 1

if [ $IKVM_EXIT_CODE -ne 0 ]; then
    echo -e "${RED}❌ Failed to convert JAR to DLL${NC}"
    exit 1
fi

echo -e "${GREEN}✓ DLL created successfully${NC}"
echo -e "  Location: $DLL_PATH"

# Verify DLL exists
if [ ! -f "$DLL_PATH" ]; then
    echo -e "${RED}❌ DLL file not found after conversion${NC}"
    exit 1
fi

# Get file size
DLL_SIZE=$(du -h "$DLL_PATH" | cut -f1)
echo -e "  Size: $DLL_SIZE"

echo -e "\n${CYAN}=========================================${NC}"
echo -e "${GREEN}SUCCESS! Full-Featured DLL Built!${NC}"
echo -e "${CYAN}=========================================${NC}"

echo -e "\n${NC}Your DLL with FULL Bluetooth features is ready:${NC}"
echo -e "  ${CYAN}$DLL_PATH${NC}"

echo -e "\n${NC}This DLL includes:${NC}"
echo -e "  ${GREEN}✓ Bluetooth adapter state checking${NC}"
echo -e "  ${GREEN}✓ Device scanning (Windows Bluetooth API)${NC}"
echo -e "  ${GREEN}✓ NIOX device filtering${NC}"
echo -e "  ${GREEN}✓ Device information (name, address, etc.)${NC}"

echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "  ${NC}1. Copy NioxPlugin.dll to your WinUI/MAUI project${NC}"
echo -e "  ${NC}2. Follow the guide: docs/WINUI3_STEP_BY_STEP.md${NC}"
echo -e "  ${NC}3. Add IKVM NuGet package to your project${NC}"
echo -e "  ${NC}4. Reference the DLL in your .csproj${NC}"

echo -e "\n${CYAN}=========================================${NC}"
