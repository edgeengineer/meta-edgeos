#!/bin/bash
# EdgeOS PR Validation Script
# Run this locally before submitting a PR

set -e

echo "========================================="
echo "EdgeOS PR Validation"
echo "========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if we're in the right directory
if [ ! -f "meta-edgeos/conf/layer.conf" ]; then
    echo -e "${RED}Error: Not in EdgeOS repository root${NC}"
    echo "Please run this script from the repository root"
    exit 1
fi

echo -e "\n${GREEN}1. Checking repository structure...${NC}"
errors=0

# Check required files
required_files=(
    "meta-edgeos/conf/layer.conf"
    "bootstrap.sh"
    "README.md"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}✗ Missing: $file${NC}"
        ((errors++))
    else
        echo -e "${GREEN}✓ Found: $file${NC}"
    fi
done

echo -e "\n${GREEN}2. Checking recipe syntax...${NC}"

# Check all recipes have required fields
find meta-edgeos -name "*.bb" -o -name "*.bbappend" | while read recipe; do
    recipe_name=$(basename "$recipe")
    
    # Skip bbappend files for LICENSE check
    if [[ "$recipe" == *.bb ]]; then
        if ! grep -q "LICENSE" "$recipe"; then
            echo -e "${YELLOW}⚠ Missing LICENSE in $recipe_name${NC}"
        fi
        
        if ! grep -q "SUMMARY\|DESCRIPTION" "$recipe"; then
            echo -e "${YELLOW}⚠ Missing SUMMARY/DESCRIPTION in $recipe_name${NC}"
        fi
    fi
    
    # Check for tabs vs spaces (Yocto prefers 4 spaces)
    if grep -q $'\t' "$recipe"; then
        echo -e "${YELLOW}⚠ Contains tabs (should use spaces): $recipe_name${NC}"
    fi
done

echo -e "\n${GREEN}3. Checking bootstrap script...${NC}"

if [ -x "bootstrap.sh" ]; then
    echo -e "${GREEN}✓ bootstrap.sh is executable${NC}"
else
    echo -e "${RED}✗ bootstrap.sh is not executable${NC}"
    echo "  Fix with: chmod +x bootstrap.sh"
    ((errors++))
fi

echo -e "\n${GREEN}4. Checking for common issues...${NC}"

# Check for large files
large_files=$(find . -type f -size +1M -not -path "./.git/*" -not -path "./sources/*" -not -path "./build/*" -not -path "./downloads/*" -not -path "./sstate-cache/*" 2>/dev/null)
if [ -n "$large_files" ]; then
    echo -e "${YELLOW}⚠ Large files detected (>1MB):${NC}"
    echo "$large_files"
fi

# Check for credentials or keys
suspicious_files=$(grep -r -l --include="*.bb" --include="*.bbappend" --include="*.conf" --include="*.sh" \
    -E "(PASSWORD|SECRET|KEY|TOKEN|APIKEY|API_KEY)" meta-edgeos/ 2>/dev/null || true)
if [ -n "$suspicious_files" ]; then
    echo -e "${YELLOW}⚠ Files containing potential secrets:${NC}"
    echo "$suspicious_files"
    echo "  Please ensure no actual secrets are committed"
fi

echo -e "\n${GREEN}5. Quick parse test (if build environment exists)...${NC}"

if [ -d "sources/poky" ] && [ -f "build/conf/local.conf" ]; then
    echo "Running recipe parse test..."
    (
        cd build
        source ../sources/poky/oe-init-build-env . > /dev/null 2>&1
        if bitbake -p > /dev/null 2>&1; then
            echo -e "${GREEN}✓ All recipes parsed successfully${NC}"
        else
            echo -e "${RED}✗ Recipe parsing failed${NC}"
            echo "  Run 'bitbake -p' in build environment for details"
            ((errors++))
        fi
    )
else
    echo -e "${YELLOW}⚠ Build environment not set up, skipping parse test${NC}"
    echo "  Run ./bootstrap.sh first for full validation"
fi

echo -e "\n${GREEN}6. Checking git status...${NC}"

# Check for uncommitted changes
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}⚠ Uncommitted changes detected:${NC}"
    git status --short
fi

# Check branch
current_branch=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $current_branch"

if [ "$current_branch" == "main" ]; then
    echo -e "${YELLOW}⚠ You're on main branch - consider creating a feature branch${NC}"
fi

echo -e "\n========================================="
if [ $errors -eq 0 ]; then
    echo -e "${GREEN}✓ Validation completed successfully!${NC}"
    echo "Your changes appear ready for PR submission."
else
    echo -e "${RED}✗ Validation found $errors error(s)${NC}"
    echo "Please fix the issues before submitting a PR."
    exit 1
fi

echo -e "\nTo run CI tests locally:"
echo "  1. Quick validation: ./scripts/validate-pr.sh"
echo "  2. Full parse test:"
echo "     source sources/poky/oe-init-build-env build"
echo "     bitbake -p"
echo "  3. Build specific recipe:"
echo "     bitbake -c compile <recipe-name>"
echo "========================================="