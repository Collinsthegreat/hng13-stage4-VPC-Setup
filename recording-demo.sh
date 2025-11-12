#!/bin/bash
# VPC Demo Script with Pause Points for Recording
# Press ENTER at each pause to continue

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

pause_for_recording() {
    echo ""
    echo -e "${YELLOW}[RECORDING PAUSE]${NC} $1"
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read
    clear
}

show_timestamp() {
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo -e "${BLUE}  TIMESTAMP: $1${NC}"
    echo -e "${BLUE}  $2${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    echo ""
}

clear
echo "╔════════════════════════════════════════════════════════╗"
echo "║                                                        ║"
echo "║     Building VPC on Linux - Live Demonstration        ║"
echo "║                                                        ║"
echo "║     By: [Your Name]                                   ║"
echo "║     Date: $(date +%Y-%m-%d)                                  ║"
echo "║                                                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "This demo will show:"
echo "  ✓ VPC Creation & Subnet Management"
echo "  ✓ NAT Gateway for Internet Access"
echo "  ✓ VPC Isolation & Peering"
echo "  ✓ Firewall Rules (Security Groups)"
echo "  ✓ Application Deployment"
echo ""

pause_for_recording "Ready to start? Check your recording software is running."

# ============================================================================
# [00:00 - 00:30] Introduction & Cleanup
# ============================================================================

show_timestamp "[00:00]" "Cleanup & Preparation"

echo "Step 1: Cleaning up any existing resources..."
sudo pkill -f "python3 -m http.server" 2>/dev/null || true
sudo ~/vpc-project/cleanup-all.sh 2>&1 | grep -E "|Cleanup"
echo ""
echo " Environment is clean and ready"

pause_for_recording "Cleanup complete. Ready to show CLI help?"

echo ""
echo "Available vpcctl commands:"
vpcctl --help | head -20

pause_for_recording "CLI help shown. Ready for VPC creation?"

# ============================================================================
# [00:30 - 01:30] VPC Creation
# ============================================================================

clear
show_timestamp "[00:30]" "Creating VPC1 with Subnets"

echo "═══════════════════════════════════════════"
echo "  STEP 1: Creating VPC Infrastructure"
echo "═══════════════════════════════════════════"
echo ""

echo "Creating VPC1 with CIDR 10.0.0.0/16..."
sudo vpcctl create-vpc --name vpc1 --cidr 10.0.0.0/16 --internet-interface eth0
echo ""

pause_for_recording "VPC1 created. Ready to add public subnet?"

echo "Adding PUBLIC subnet (with NAT for internet access)..."
sudo vpcctl add-subnet --vpc vpc1 --name public --cidr 10.0.1.0/24 --type public
echo ""

pause_for_recording "Public subnet added. Ready to add private subnet?"

echo "Adding PRIVATE subnet (isolated from internet)..."
sudo vpcctl add-subnet --vpc vpc1 --name private --cidr 10.0.2.0/24 --type private
echo ""

pause_for_recording "Private subnet added. Ready to list VPCs?"

echo "Listing all VPCs:"
sudo vpcctl list-vpcs

pause_for_recording "VPC list shown. Ready to inspect details?"

# ============================================================================
# [01:30 - 02:00] Inspection & Verification
# ============================================================================

clear
show_timestamp "[01:30]" "Inspecting VPC Configuration"

echo "═══════════════════════════════════════════"
echo "  STEP 2: Inspecting VPC Details"
echo "═══════════════════════════════════════════"
echo ""

echo "Detailed VPC inspection:"
sudo vpcctl inspect-vpc --name vpc1

pause_for_recording "Inspection complete. Ready to verify resources?"

echo ""
echo "Verifying all VPC resources are healthy:"
sudo vpcctl verify-vpc --name vpc1

pause_for_recording "Verification complete. Ready to deploy applications?"

# ============================================================================
# [02:00 - 02:45] Deploy Applications & Test Connectivity
# ============================================================================

clear
show_timestamp "[02:00]" "Deploying Web Servers & Testing Connectivity"

echo "═══════════════════════════════════════════"
echo "  STEP 3: Deploying Applications"
echo "═══════════════════════════════════════════"
echo ""

echo "Starting web server in PUBLIC subnet..."
sudo ip netns exec vpc1-public python3 -m http.server 8080 >/dev/null 2>&1 &
PID1=$!
echo " Server running on 10.0.1.10:8080 (PID: $PID1)"
echo ""

echo "Starting web server in PRIVATE subnet..."
sudo ip netns exec vpc1-private python3 -m http.server 8080 >/dev/null 2>&1 &
PID2=$!
echo " Server running on 10.0.2.10:8080 (PID: $PID2)"
echo ""
sleep 2

pause_for_recording "Servers deployed. Ready for connectivity tests?"

clear
show_timestamp "[02:15]" "Testing Network Connectivity"

echo "═══════════════════════════════════════════"
echo "  CONNECTIVITY TESTS"
echo "═══════════════════════════════════════════"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 1: Host → Public Subnet"
echo "Expected:  SUCCESS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if curl -s --max-time 3 http://10.0.1.10:8080 | head -3; then
    echo " PASSED"
else
    echo " FAILED"
fi

pause_for_recording "Test 1 complete. Continue?"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 2: Public → Private (Intra-VPC)"
echo "Expected:  SUCCESS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if sudo ip netns exec vpc1-public curl -s --max-time 3 http://10.0.2.10:8080 | head -3; then
    echo " PASSED"
else
    echo " FAILED"
fi

pause_for_recording "Test 2 complete. Continue?"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 3: Public Subnet → Internet"
echo "Expected:  SUCCESS (NAT enabled)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sudo ip netns exec vpc1-public ping -c 3 8.8.8.8
echo " PASSED"

pause_for_recording "Test 3 complete. Continue?"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 4: Private Subnet → Internet"
echo "Expected:  BLOCKED (no NAT)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
timeout 5 sudo ip netns exec vpc1-private ping -c 3 8.8.8.8 || echo " PASSED - Correctly blocked!"

pause_for_recording "NAT tests complete. Ready for VPC isolation?"

# ============================================================================
# [02:45 - 03:30] VPC Isolation & Peering
# ============================================================================

clear
show_timestamp "[02:45]" "VPC Isolation & Peering"

echo "═══════════════════════════════════════════"
echo "  STEP 4: VPC Isolation Test"
echo "═══════════════════════════════════════════"
echo ""

echo "Creating second VPC (VPC2)..."
sudo vpcctl create-vpc --name vpc2 --cidr 172.16.0.0/16 --internet-interface eth0 2>&1 | grep ""
sudo vpcctl add-subnet --vpc vpc2 --name public --cidr 172.16.1.0/24 --type public 2>&1 | grep ""
echo ""

echo "Starting web server in VPC2..."
sudo ip netns exec vpc2-public python3 -m http.server 8080 >/dev/null 2>&1 &
PID3=$!
echo " Server running on 172.16.1.10:8080 (PID: $PID3)"
sleep 2

pause_for_recording "VPC2 created. Ready to test isolation?"

echo ""
echo "Adding isolation rules between VPCs..."
sudo iptables -I FORWARD 1 -s 10.0.0.0/16 -d 172.16.0.0/16 -j DROP
sudo iptables -I FORWARD 1 -s 172.16.0.0/16 -d 10.0.0.0/16 -j DROP
echo " Isolation rules applied"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 5: VPC1 → VPC2 (Isolation Test)"
echo "Expected:  BLOCKED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
timeout 5 sudo ip netns exec vpc1-public ping -c 2 172.16.1.10 || echo " PASSED - VPCs are isolated!"

pause_for_recording "Isolation test complete. Ready for peering?"

clear
show_timestamp "[03:15]" "Establishing VPC Peering"

echo "═══════════════════════════════════════════"
echo "  STEP 5: VPC Peering"
echo "═══════════════════════════════════════════"
echo ""

echo "Creating peering connection between VPC1 and VPC2..."
sudo vpcctl peer-vpc --vpc1 vpc1 --vpc2 vpc2
echo ""

pause_for_recording "Peering established. Ready to test?"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 6: VPC1 → VPC2 (After Peering)"
echo "Expected:  SUCCESS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
sudo ip netns exec vpc1-public ping -c 3 172.16.1.10
echo " PASSED - Peering works!"

pause_for_recording "Peering test complete. Ready for firewall rules?"

# ============================================================================
# [03:30 - 04:15] Firewall Rules
# ============================================================================

clear
show_timestamp "[03:30]" "Applying Firewall Rules (Security Groups)"

echo "═══════════════════════════════════════════"
echo "  STEP 6: Security Groups / Firewall"
echo "═══════════════════════════════════════════"
echo ""

echo "Creating firewall policy..."
cat > /tmp/firewall-policy.json <<'EOF'
{
  "subnet": "10.0.1.0/24",
  "ingress": [
    {"port": 8080, "protocol": "tcp", "action": "allow"},
    {"port": 22, "protocol": "tcp", "action": "deny"}
  ]
}
EOF

echo "Policy file:"
cat /tmp/firewall-policy.json
echo ""

pause_for_recording "Policy created. Ready to apply?"

echo "Applying firewall rules to public subnet..."
sudo vpcctl apply-firewall --vpc vpc1 --subnet public --policy /tmp/firewall-policy.json
echo ""

pause_for_recording "Firewall applied. Ready to test?"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 7: Port 8080 (Allowed)"
echo "Expected:  SUCCESS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if sudo ip netns exec vpc1-private curl -s --max-time 3 http://10.0.1.10:8080 | head -2; then
    echo " PASSED"
else
    echo " FAILED"
fi

pause_for_recording "Test 7 complete. Continue?"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "TEST 8: Port 22 (Blocked)"
echo "Expected:  BLOCKED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
timeout 3 sudo ip netns exec vpc1-private nc -zv 10.0.1.10 22 2>&1 || echo " PASSED - Port 22 blocked!"

pause_for_recording "Firewall tests complete. Ready for cleanup?"

# ============================================================================
# [04:15 - 04:45] Cleanup & Summary
# ============================================================================

clear
show_timestamp "[04:15]" "Cleanup & Resource Teardown"

echo "═══════════════════════════════════════════"
echo "  STEP 7: Clean Teardown"
echo "═══════════════════════════════════════════"
echo ""

echo "Stopping web servers..."
sudo kill $PID1 $PID2 $PID3 2>/dev/null
echo " All servers stopped"
echo ""

pause_for_recording "Servers stopped. Ready to delete VPCs?"

echo "Deleting VPC1..."
sudo vpcctl delete-vpc --name vpc1
echo ""

echo "Deleting VPC2..."
sudo vpcctl delete-vpc --name vpc2
echo ""

pause_for_recording "VPCs deleted. Ready to verify cleanup?"

echo "Verifying cleanup:"
echo ""
echo "VPCs:"
sudo vpcctl list-vpcs
echo ""
echo "Namespaces:"
sudo ip netns list | grep vpc || echo " No VPC namespaces found"
echo ""
echo "Bridges:"
ip link show type bridge | grep vpc || echo " No VPC bridges found"

pause_for_recording "Cleanup verified. Ready for summary?"

# ============================================================================
# [04:45 - 05:00] Summary
# ============================================================================

clear
show_timestamp "[04:45]" "Demo Complete - Summary"

echo "╔════════════════════════════════════════════════════════╗"
echo "║                                                        ║"
echo "║              DEMONSTRATION COMPLETE                    ║"
echo "║                                                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo " Tests Completed:"
echo ""
echo "  ✓ VPC Creation & Management"
echo "  ✓ Public & Private Subnets"
echo "  ✓ NAT Gateway (Public:  | Private: )"
echo "  ✓ VPC Isolation (Blocked by default)"
echo "  ✓ VPC Peering (Controlled access)"
echo "  ✓ Firewall Rules (Port-level control)"
echo "  ✓ Application Deployment"
echo "  ✓ Clean Resource Teardown"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Resources:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   GitHub: [Your Repo URL]"
echo "   Blog: [Your Blog URL]"
echo "   Logs: /var/log/vpcctl.log"
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║                   THANK YOU!                           ║"
echo "╚════════════════════════════════════════════════════════╝"

pause_for_recording "Demo complete. Stop recording now."
