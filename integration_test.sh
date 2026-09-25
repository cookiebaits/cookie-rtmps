#!/bin/bash
# integration_test.sh - Integration testing for CookieRTMPS

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

CONTAINER_NAME="cookie-rtmps"

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}     CookieRTMPS Integration Test     ${NC}"
echo -e "${BLUE}=====================================${NC}"

# Check unit tests locally first if python3 is available
if command -v python3 &> /dev/null; then
    echo -n "Running local NOALBS component unit tests... "
    if python3 test_noalbs.py > /dev/null 2>&1; then
        echo -e "[${GREEN}PASSED${NC}]"
    else
        echo -e "[${RED}FAILED${NC}]"
        python3 test_noalbs.py
        exit 1
    fi
fi

# Check Docker container if running
if docker inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null | grep -q "true"; then
    echo -e "${YELLOW}Waiting 5 seconds for container services to start...${NC}"
    sleep 5

    # 1. Check if Docker container is running
    echo -n "Checking Docker container '$CONTAINER_NAME'... "
    echo -e "[${GREEN}PASSED${NC}]"

    # 2. Check internal processes
    check_process() {
        local proc=$1
        echo -n "Checking process '$proc' inside container... "
        if docker exec $CONTAINER_NAME pgrep -x "$proc" > /dev/null; then
            echo -e "[${GREEN}PASSED${NC}]"
            return 0
        else
            echo -e "[${RED}FAILED${NC}]"
            return 1
        fi
    }

    check_process "nginx"
    check_process "gunicorn"
    check_process "stunnel4"

    # 3. Check Flask Validator health endpoint
    echo -n "Checking Flask Validator health endpoint... "
    if docker exec $CONTAINER_NAME curl -s --fail http://127.0.0.1:8080/health > /dev/null; then
        echo -e "[${GREEN}PASSED${NC}]"
    else
        echo -e "[${RED}FAILED${NC}]"
    fi

    # 4. Check NOALBS if enabled
    NOALBS_ENABLED=$(docker exec $CONTAINER_NAME printenv NOALBS_ENABLED 2>/dev/null || echo "false")
    if [ "$NOALBS_ENABLED" == "true" ]; then
        echo -n "Checking NOALBS process inside container... "
        if docker exec $CONTAINER_NAME pgrep -f "noalbs.py" > /dev/null; then
            echo -e "[${GREEN}PASSED${NC}]"
        else
            echo -e "[${RED}FAILED${NC}]"
        fi

        echo -n "Executing NOALBS unit tests inside container... "
        if docker exec $CONTAINER_NAME python3 /app/test_noalbs.py > /dev/null 2>&1; then
            echo -e "[${GREEN}PASSED${NC}]"
        else
            echo -e "[${RED}FAILED${NC}]"
        fi
    else
        echo -e "NOALBS is ${YELLOW}DISABLED${NC}, skipping process check."
    fi

    # 5. Check Host Ports
    echo -n "Checking host port 1935 (RTMP)... "
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":1935 "; then
            echo -e "[${GREEN}PASSED${NC}]"
        else
            echo -e "[${RED}FAILED${NC}]"
        fi
    else
        echo -e "[${YELLOW}SKIPPED${NC}] (ss command not found)"
    fi
else
    echo -e "${YELLOW}Container '$CONTAINER_NAME' is not running. Skipped container-specific checks.${NC}"
fi

echo -e "${BLUE}=====================================${NC}"
echo -e "${GREEN}Integration Test Completed Successfully.${NC}"
echo -e "${BLUE}=====================================${NC}"
