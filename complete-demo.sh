#!/bin/bash
# Complete VPC Demo Script with Proper Isolation

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   VPC System Complete Demo${NC}"
echo -e "${BLUE}================================${NC}\n"

# Step 1: Cleanup
echo -e "${YELLOW}Step 1: Cleanup existing resources${NC}"
sudo pkill -f "python3 -m http.server" 2>/dev/null || true
sudo vpcctl delete-vpc --name vpc1 2>/dev/null || true
sudo vpcctl delete-vpc --name vpc2 2>/dev/null || true
sudo iptables -F FORWARD
sleep 2
echo -e "${GREEN}✅ Cleanup complete${NC}\n"

# Step 2: Create VPC1
echo -e "${YELLOW}Step 2: Creating VPC1 (10.0.0.0/16)${NC}"
sudo vpcctl create-vpc --name vpc1 --cidr 10.0.0.0/16 --internet-interface eth0
sudo vpcctl add-subnet --vpc vpc1 --name public --cidr 10.0.1.0/24 --type public
sudo vpcctl add-subnet --vpc vpc1 --name private --cidr 10.0.2.0/24 --type private
echo -e "${GREEN}✅ VPC1 created${NC}\n"

# Step 3: Create VPC2
echo -e "${YELLOW}Step 3: Creating VPC2 (172.16.0.0/16)${NC}"
sudo vpcctl create-vpc --name vpc2 --cidr 172.16.0.0/16 --internet-interface eth0
sudo vpcctl add-subnet --vpc vpc2 --name public --cidr 172.16.1.0/24 --type public
echo -e "${GREEN}✅ VPC2 created${NC}\n"

# Step 4: Add isolation rules
echo -e "${YELLOW}Step 4: Enforcing VPC isolation${NC}"
sudo iptables -I FORWARD 1 -s 10.0.0.0/16 -d 172.16.0.0/16 -j DROP
sudo iptables -I FORWARD 1 -s 172.16.0.0/16 -d 10.0.0.0/16 -j DROP
echo "Current FORWARD rules:"
sudo iptables -L FORWARD -n -v --line-numbers | head -10
echo -e "${GREEN}✅ Isolation rules applied${NC}\n"

# Step 5: Deploy web servers
echo -e "${YELLOW}Step 5: Deploying web servers${NC}"
sudo ip netns exec vpc1-public python3 -m http.server 8080 > /dev/null 2>&1 &
PID1=$!
sudo ip netns exec vpc1-private python3 -m http.server 8080 > /dev/null 2>&1 &
PID2=$!
sudo ip netns exec vpc2-public python3 -m http.server 8080 > /dev/null 2>&1 &
PID3=$!
sleep 3
echo -e "${GREEN}✅ Web servers running (PIDs: $PID1, $PID2, $PID3)${NC}\n"

# Step 6: List VPCs
echo -e "${YELLOW}Step 6: VPC Overview${NC}"
sudo vpcctl list-vpcs
echo ""

# Step 7: Basic connectivity tests
echo -e "${BLUE}=== CONNECTIVITY TESTS ===${NC}\n"

echo -e "${YELLOW}Test 1: Host → Public Subnet${NC}"
if curl -s --max-time 3 http://10.0.1.10:8080 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC} - Host can access public subnet\n"
else
    echo -e "${RED}❌ FAIL${NC} - Host cannot access public subnet\n"
fi

echo -e "${YELLOW}Test 2: Host → Private Subnet${NC}"
if curl -s --max-time 3 http://10.0.2.10:8080 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC} - Host can access private subnet\n"
else
    echo -e "${RED}❌ FAIL${NC} - Host cannot access private subnet\n"
fi

echo -e "${YELLOW}Test 3: Public → Private (Intra-VPC)${NC}"
if sudo ip netns exec vpc1-public curl -s --max-time 3 http://10.0.2.10:8080 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC} - Public subnet can reach private subnet in same VPC\n"
else
    echo -e "${RED}❌ FAIL${NC} - Public subnet cannot reach private subnet\n"
fi

echo -e "${YELLOW}Test 4: Public Subnet → Internet${NC}"
if sudo ip netns exec vpc1-public ping -c 3 -W 3 8.8.8.8 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC} - Public subnet has internet access\n"
else
    echo -e "${RED}❌ FAIL${NC} - Public subnet lacks internet access\n"
fi

echo -e "${YELLOW}Test 5: Private Subnet → Internet (should be blocked)${NC}"
if sudo ip netns exec vpc1-private ping -c 2 -W 2 8.8.8.8 > /dev/null 2>&1; then
    echo -e "${RED}❌ FAIL${NC} - Private subnet should NOT have internet access\n"
else
    echo -e "${GREEN}✅ PASS${NC} - Private subnet correctly blocked from internet\n"
fi

# Step 8: VPC Isolation test
echo -e "${BLUE}=== VPC ISOLATION TEST ===${NC}\n"
echo -e "${YELLOW}Test 6: VPC1 → VPC2 (should be BLOCKED)${NC}"
if timeout 5 sudo ip netns exec vpc1-public ping -c 2 172.16.1.10 > /dev/null 2>&1; then
    echo -e "${RED}❌ FAIL${NC} - VPCs are NOT isolated (this is a BUG)\n"
else
    echo -e "${GREEN}✅ PASS${NC} - VPCs are properly isolated\n"
fi

# Step 9: VPC Peering
echo -e "${BLUE}=== VPC PEERING ===${NC}\n"
echo -e "${YELLOW}Step 9: Creating VPC peering connection${NC}"
sudo vpcctl peer-vpc --vpc1 vpc1 --vpc2 vpc2
echo -e "${GREEN}✅ Peering established${NC}\n"

echo "Updated FORWARD rules after peering:"
sudo iptables -L FORWARD -n -v --line-numbers | head -10
echo ""

echo -e "${YELLOW}Test 7: VPC1 → VPC2 (after peering, should WORK)${NC}"
if sudo ip netns exec vpc1-public ping -c 3 172.16.1.10 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC} - VPC peering works correctly\n"
else
    echo -e "${RED}❌ FAIL${NC} - VPC peering not working\n"
fi

echo -e "${YELLOW}Test 8: Web access across VPCs${NC}"
if sudo ip netns exec vpc1-public curl -s --max-time 3 http://172.16.1.10:8080 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC} - Can access web server across peered VPCs\n"
else
    echo -e "${RED}❌ FAIL${NC} - Cannot access web server across VPCs\n"
fi

# Step 10: Firewall rules
echo -e "${BLUE}=== FIREWALL RULES ===${NC}\n"
echo -e "${YELLOW}Step 10: Applying firewall policy${NC}"

cat > /tmp/firewall-policy.json <<'EOF'
{
  "subnet": "10.0.1.0/24",
  "ingress": [
    {"port": 80, "protocol": "tcp", "action": "allow"},
    {"port": 8080, "protocol": "tcp", "action": "allow"},
    {"port": 22, "protocol": "tcp", "action": "deny"}
  ]
}
EOF

sudo vpcctl apply-firewall --vpc vpc1 --subnet public --policy /tmp/firewall-policy.json
echo -e "${GREEN}✅ Firewall policy applied${NC}\n"

echo -e "${YELLOW}Test 9: Allowed port (8080)${NC}"
if sudo ip netns exec vpc1-private curl -s --max-time 3 http://10.0.1.10:8080 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ PASS${NC} - Port 8080 is accessible\n"
else
    echo -e "${RED}❌ FAIL${NC} - Port 8080 is blocked\n"
fi

echo -e "${YELLOW}Test 10: Blocked port (22)${NC}"
if sudo ip netns exec vpc1-private timeout 3 nc -zv 10.0.1.10 22 2>&1 | grep -q "succeeded"; then
    echo -e "${RED}❌ FAIL${NC} - Port 22 should be blocked\n"
else
    echo -e "${GREEN}✅ PASS${NC} - Port 22 is correctly blocked\n"
fi

# Summary
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}   TEST SUMMARY${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "VPCs Created: ${GREEN}2${NC}"
echo -e "Subnets Created: ${GREEN}3${NC}"
echo -e "Tests Passed: Check above ✅"
echo -e "Peering Status: ${GREEN}Active${NC}"
echo -e "Logs: ${YELLOW}/var/log/vpcctl.log${NC}"
echo -e "${BLUE}================================${NC}\n"

echo -e "${YELLOW}Web servers still running. To stop:${NC}"
echo "  sudo kill $PID1 $PID2 $PID3"
echo "  OR: sudo pkill -f 'python3 -m http.server'"
echo ""
echo -e "${YELLOW}To clean up everything:${NC}"
echo "  sudo vpcctl delete-vpc --name vpc1"
echo "  sudo vpcctl delete-vpc --name vpc2"
echo "  sudo iptables -F FORWARD"
echo ""
echo -e "${GREEN}Demo complete! 🎉${NC}"
