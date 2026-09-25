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

echo -e "${YELLOW}Waiting 5 seconds for services to start...${NC}"
sleep 5

# 1. Check if Docker container is running
echo -n "Checking Docker container '$CONTAINER_NAME'... "
if [ "$(docker inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)" == "true" ]; then
    echo -e "[${GREEN}PASSED${NC}]"
else
    echo -e "[${RED}FAILED${NC}]"
    echo -e "${RED}Error: Container is not running.${NC}"
    exit 1
fi

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

# 3. Check Flask Health Endpoint
echo -n "Checking Flask Validator health endpoint... "
if docker exec $CONTAINER_NAME curl -s --fail http://127.0.0.1:8080/health > /dev/null; then
    echo -e "[${GREEN}PASSED${NC}]"
else
    echo -e "[${RED}FAILED${NC}]"
fi

# 4. Check NOALBS component and run unit & integration tests
NOALBS_ENABLED=$(docker exec $CONTAINER_NAME printenv NOALBS_ENABLED 2>/dev/null || echo "false")
if [ "$NOALBS_ENABLED" == "true" ]; then
    echo -n "Checking NOALBS process... "
    if docker exec $CONTAINER_NAME pgrep -f "noalbs.py" > /dev/null; then
        echo -e "[${GREEN}PASSED${NC}]"
    else
        echo -e "[${RED}FAILED${NC}]"
    fi

    echo -n "Running NOALBS test suite inside container... "
    if docker exec $CONTAINER_NAME python3 -m unittest /app/test_noalbs.py > /dev/null 2>&1; then
        echo -e "[${GREEN}PASSED${NC}]"
    else
        echo -e "[${RED}FAILED${NC}]"
        docker exec $CONTAINER_NAME python3 -m unittest /app/test_noalbs.py
    fi

    echo -n "Checking NOALBS default video fallback handling... "
    if docker exec $CONTAINER_NAME python3 -c "from noalbs.noalbs import Noalbs; n = Noalbs(); exit(0 if n.brb_video_url == 'https://filedn.com/lfh40bKbFfD5um9HDFNrJFR/brb.mp4' else 1)" > /dev/null 2>&1; then
        echo -e "[${GREEN}PASSED${NC}]"
    else
        echo -e "[${RED}FAILED${NC}]"
    fi
else
    echo -e "NOALBS is ${YELLOW}DISABLED${NC}, skipping check."
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

echo -e "${BLUE}=====================================${NC}"
echo -e "${GREEN}Integration Test Completed.${NC}"
echo -e "${BLUE}=====================================${NC}"
