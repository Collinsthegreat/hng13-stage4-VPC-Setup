#!/bin/bash
# Clean VPC Demo Script - No Cluttered Output

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Suppress vpcctl logs (only show our messages)
export VPCCTL_QUIET=1

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   VPC System Demo${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Step 1: Cleanup
echo -e "${YELLOW}[1/10]${NC} Cleanup..."
sudo pkill -f "python3 -m http.server" 2>/dev/null || true
sudo vpcctl delete-vpc --name vpc1 >/dev/null 2>&1 || true
sudo vpcctl delete-vpc --name vpc2 >/dev/null 2>&1 || true
sudo iptables -F FORWARD
sleep 1
echo -e "      ${GREEN}✓${NC} Done"

# Step 2: Create VPC1
echo -e "${YELLOW}[2/10]${NC} Creating VPC1 (10.0.0.0/16)..."
sudo vpcctl create-vpc --name vpc1 --cidr 10.0.0.0/16 --internet-interface eth0 >/dev/null 2>&1
sudo vpcctl add-subnet --vpc vpc1 --name public --cidr 10.0.1.0/24 --type public >/dev/null 2>&1
sudo vpcctl add-subnet --vpc vpc1 --name private --cidr 10.0.2.0/24 --type private >/dev/null 2>&1
echo -e "      ${GREEN}✓${NC} VPC1 with 2 subnets created"

# Step 3: Create VPC2
echo -e "${YELLOW}[3/10]${NC} Creating VPC2 (172.16.0.0/16)..."
sudo vpcctl create-vpc --name vpc2 --cidr 172.16.0.0/16 --internet-interface eth0 >/dev/null 2>&1
sudo vpcctl add-subnet --vpc vpc2 --name public --cidr 172.16.1.0/24 --type public >/dev/null 2>&1
echo -e "      ${GREEN}✓${NC} VPC2 with 1 subnet created"

# Step 4: Add isolation
echo -e "${YELLOW}[4/10]${NC} Enforcing VPC isolation..."
sudo iptables -I FORWARD 1 -s 10.0.0.0/16 -d 172.16.0.0/16 -j DROP
sudo iptables -I FORWARD 1 -s 172.16.0.0/16 -d 10.0.0.0/16 -j DROP
echo -e "      ${GREEN}✓${NC} Isolation rules applied"

# Step 5: Deploy servers
echo -e "${YELLOW}[5/10]${NC} Deploying web servers..."
sudo ip netns exec vpc1-public python3 -m http.server 8080 >/dev/null 2>&1 &
PID1=$!
sudo ip netns exec vpc1-private python3 -m http.server 8080 >/dev/null 2>&1 &
PID2=$!
sudo ip netns exec vpc2-public python3 -m http.server 8080 >/dev/null 2>&1 &
PID3=$!
sleep 2
echo -e "      ${GREEN}✓${NC} 3 web servers running"

# Step 6: Connectivity tests
echo ""
echo -e "${BLUE}=== Connectivity Tests ===${NC}"

echo -ne "  ${YELLOW}→${NC} Host to Public subnet............... "
if curl -s --max-time 3 http://10.0.1.10:8080 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo -ne "  ${YELLOW}→${NC} Host to Private subnet.............. "
if curl -s --max-time 3 http://10.0.2.10:8080 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo -ne "  ${YELLOW}→${NC} Public to Private (Intra-VPC)....... "
if sudo ip netns exec vpc1-public curl -s --max-time 3 http://10.0.2.10:8080 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo -ne "  ${YELLOW}→${NC} Public subnet Internet access....... "
if sudo ip netns exec vpc1-public ping -c 2 -W 3 8.8.8.8 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo -ne "  ${YELLOW}→${NC} Private subnet Internet (blocked)... "
if sudo ip netns exec vpc1-private ping -c 2 -W 2 8.8.8.8 >/dev/null 2>&1; then
    echo -e "${RED}✗ FAIL${NC}"
else
    echo -e "${GREEN}✓ PASS${NC}"
fi

# Step 7: VPC Isolation
echo ""
echo -e "${BLUE}=== VPC Isolation Test ===${NC}"
echo -ne "  ${YELLOW}→${NC} VPC1 to VPC2 (should be blocked).... "
if timeout 5 sudo ip netns exec vpc1-public ping -c 2 172.16.1.10 >/dev/null 2>&1; then
    echo -e "${RED}✗ FAIL${NC}"
else
    echo -e "${GREEN}✓ PASS${NC}"
fi

# Step 8: VPC Peering
echo ""
echo -e "${BLUE}=== VPC Peering ===${NC}"
echo -e "${YELLOW}[6/10]${NC} Creating peering connection..."
sudo vpcctl peer-vpc --vpc1 vpc1 --vpc2 vpc2 >/dev/null 2>&1
echo -e "      ${GREEN}✓${NC} Peering established"

echo -ne "  ${YELLOW}→${NC} VPC1 to VPC2 (after peering)........ "
if sudo ip netns exec vpc1-public ping -c 3 172.16.1.10 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo -ne "  ${YELLOW}→${NC} Web access across VPCs............... "
if sudo ip netns exec vpc1-public curl -s --max-time 3 http://172.16.1.10:8080 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

# Step 9: Firewall
echo ""
echo -e "${BLUE}=== Firewall Rules ===${NC}"
echo -e "${YELLOW}[7/10]${NC} Applying firewall policy..."

cat > /tmp/fw.json <<'EOF'
{
  "subnet": "10.0.1.0/24",
  "ingress": [
    {"port": 80, "protocol": "tcp", "action": "allow"},
    {"port": 8080, "protocol": "tcp", "action": "allow"},
    {"port": 22, "protocol": "tcp", "action": "deny"}
  ]
}
EOF

sudo vpcctl apply-firewall --vpc vpc1 --subnet public --policy /tmp/fw.json >/dev/null 2>&1
echo -e "      ${GREEN}✓${NC} Firewall rules applied"

echo -ne "  ${YELLOW}→${NC} Allowed port (8080).................. "
if sudo ip netns exec vpc1-private curl -s --max-time 3 http://10.0.1.10:8080 >/dev/null 2>&1; then
    echo -e "${GREEN}✓ PASS${NC}"
else
    echo -e "${RED}✗ FAIL${NC}"
fi

echo -ne "  ${YELLOW}→${NC} Blocked port (22).................... "
if timeout 3 sudo ip netns exec vpc1-private nc -zv 10.0.1.10 22 2>&1 | grep -q "succeeded"; then
    echo -e "${RED}✗ FAIL${NC}"
else
    echo -e "${GREEN}✓ PASS${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   Summary${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "  VPCs Created:      ${GREEN}2${NC}"
echo -e "  Subnets:           ${GREEN}3${NC}"
echo -e "  Tests Run:         ${GREEN}10${NC}"
echo -e "  Peering:           ${GREEN}Active${NC}"
echo -e "  Logs:              /var/log/vpcctl.log"
echo -e "${BLUE}================================${NC}"
echo ""
echo -e "${YELLOW}Web servers running (PIDs: $PID1 $PID2 $PID3)${NC}"
echo ""
echo "Cleanup commands:"
echo "  sudo pkill -f 'python3 -m http.server'"
echo "  sudo vpcctl delete-vpc --name vpc1"
echo "  sudo vpcctl delete-vpc --name vpc2"
echo ""
echo -e "${GREEN}Demo complete!${NC} "
