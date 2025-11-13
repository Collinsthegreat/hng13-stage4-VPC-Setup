
A complete VPC implementation on Linux using native networking primitives - network namespaces, vethpairs, Linux bridges, and iptables.

 Overview
This project implements a fully functional Virtual Private Cloud (VPC) system on Linux, demonstrating how cloudproviders like AWS, Azure, and GCP create isolated virtual networks. Using only native Linux networking tools, it provides:
VPC Creation & Management
- Create isolated virtual networks with custom CIDR blocks
Subnet Management
- Public and private subnets with automatic routing
NAT Gateway
- Internet access for public subnets via iptables MASQUERADE
VPC Isolation
- Complete network isolation between different VPCs
VPC Peering
- Controlled cross-VPC communication
Security Groups
- JSON-based firewall rules using iptables
CLI Tool
- Complete command-line interface for VPC management
 Features
Core Functionality
 Create and delete VPCs with custom CIDR ranges
 Add public and private subnets to VPCs
 Automatic routing configuration between subnets
 NAT gateway for public subnet internet access
 VPC-level network isolation using iptables
 VPC peering with static route configuration
 JSON-based security group policies
 Complete resource inspection and verification
 Clean teardown of all resources
 Comprehensive logging
Technical Implementation
Network Namespaces
- Each subnet runs in an isolated namespace
veth Pairs
- Virtual ethernet cables connecting namespaces to bridges
Linux Bridges
- Act as virtual routers for VPCs
iptables
- Provide NAT, firewall rules, and VPC isolation
Python CLI
- Clean argparse-based interface

Architecture
┌─────────────────────────────────────────────────────────────┐
│ Linux Host │
│ │
│ ┌────────────────────────────────────────────────────┐ │
│ │ VPC-1 (10.0.0.0/16) │ │
│ │ │ │
│ │ ┌──────────────────────────────────┐ │ │
│ │ │ Bridge: vpc1-br (10.0.0.1) │ │ │
│ │ └──────────┬──────────┬────────────┘ │ │
│ │ │ │ │ │
│ │ veth │ │ veth │ │
│ │ │ │ │ │
│ │ ┌──────────▼─────┐ ┌▼──────────────┐ │ │
│ │ │ Public Subnet │ │ Private Subnet │ │ │
│ │ │ (namespace) │ │ (namespace) │ │ │
│ │ │ 10.0.1.0/24 │ │ 10.0.2.0/24 │ │ │
│ │ │ │ │ │ │ │
│ │ │ [Web Server] │ │ [Database] │ │ │
│ │ └────────────────┘ └─────────────────┘ │ │
│ └─────────────────────────────────────────────────────┘ │
│ │ │
│ │ NAT (iptables) │
│ ▼ │
│ [Internet via eth0] │
└─────────────────────────────────────────────────────────────┘
Key Components
Component
Linux Equivalent
Purpose
VPC
Linux Bridge
Virtual network router
Subnet
Network Namespace
Isolated network environment
Connection
veth pair
Virtual ethernet cable
NAT Gateway
iptables MASQUERADE
Internet access translation
Security Group
iptables rules
Firewall policies
Route Table
ip route
Traffic routing


Installation
1. Clone the Repository
bash
gitgit
clone https://github.com/collinsthegreat/hng13-stage4-VPC-Setup.git
cdcd
vpc-linux
2. Install vpcctl
bash
 executable# Make the CLI executable
chmodchmod
+x bin/vpcctl
 symlink# Create system-wide symlink
sudosudo
lnln
-sf
$($(
pwdpwd
))
/vpcctl/bin/vpcctl /usr/local/bin/vpcctl
 installation# Verify installation
vpcctl helpvpcctl --help
3. Find Your Internet Interface
bash
 interface Find your default network interface
ipip
route
||
grepgrep
default
 eth0# Output example: default via 192.168.1.1 dev eth0
 enp0s3)# Your interface is after "dev" (e.g., eth0, wlan0, enp0s3)
 Quick Start
Create Your First VPC
bash
 16 Create VPC with CIDR 10.0.0.0/16
sudosudo
vpcctl create-vpc --name myvpc --cidr
10.010.0
.0.0/eth0.0.0/16 --internet-interface eth0
 access) Add public subnet (with internet access)
sudosudo
vpcctl add-subnet --vpc myvpc --name public --cidr
10.010.0
.1.0/public.1.0/24 --type public
 access) Add private subnet (no internet access)
sudosudo
vpcctl add-subnet --vpc myvpc --name private --cidr
10.010.0
.2.0/private.2.0/24 --type private
 VPCs# List all VPCs
sudosudo
vpcctl list-vpcs
 details Inspect VPC details
sudosudo
vpcctl inspect-vpc --name myvpc
Deploy an Application
bash
 subnet Deploy web server in public subnet
sudosudo
ipip
netns
execexec
myvpc-public python3 -m http.server
80808080
&&
 host Test from host
curlcurl
http://10.0.1.10:8080
 subnet Test internet access from public subnet
sudosudo
ipip
netns
execexec
myvpc-public
pingping
-c
33
8.88.8
.8.8.8.8
Clean Up
bash
 resources# Delete VPC and all resources
sudosudo
vpcctl delete-vpc --name myvpc
 cleanup Or use comprehensive cleanup
sudosudo
./cleanup-all.sh
 Usage
Available Commands
bash
vpcctl --help
 commands Show all commands
 Management VPC Management
vpcctl create-vpc
 VPC Create a new VPC
vpcctl delete-vpc
 VPC Delete a VPC
vpcctl list-vpcs
 VPCs List all VPCs
vpcctl inspect-vpc
 details Inspect VPC details
vpcctl verify-vpc
 resources Verify VPC resources
 Management# Subnet Management
vpcctl add-subnet
 VPC Add subnet to VPC
 Security Security
vpcctl apply-firewall
 policy Apply firewall policy
 Peering Peering
vpcctl peer-vpc
 peering Create VPC peering
Command Reference
Create VPC
bash
sudosudo
vpcctl create-vpc
\\
--name
<<
vpc-namevpc-name
>>
\\
--cidr
<<
cidr-blockcidr-block
>>
\\
--internet-interface
<<
interfaceinterface
>>

 How It Works
VPC Creation
1.
Create Linux Bridge
- Acts as the VPC router
2.
Assign Bridge IP
- Gateway IP for the VPC (e.g., 10.0.0.1)
3.
Store State
- Save VPC configuration to
/var/run/vpcctl/
Subnet Addition
1.
Create Network Namespace
- Isolated network environment
2.
Create veth Pair
- Virtual ethernet cable
3.
Connect to Bridge
- Attach one end of veth to bridge
4.
Configure Namespace
- Assign IP, set routes, bring up interface
5.
Enable NAT
(public only) - Configure iptables MASQUERADE
NAT Gateway
bash
 forwarding Enable IP forwarding
echoecho
11
>>
/proc/sys/net/ipv4/ip_forward

VPC Isolation
bash
 traffic Block inter-VPC traffic
iptables -I FORWARD
11
-s
10.010.0
.0.0/16 -d
172.16172.16
.0.0/DROP.0.0/16 -j DROP
iptables -I FORWARD
11
-s
172.16172.16
.0.0/16 -d
10.010.0
.0.0/DROP.0.0/16 -j DROP
VPC Peering
1.
Create veth Pair
- Connect both bridges
2.
Remove Isolation
- Delete DROP rules between VPCs
3.
Add Routes
- Configure routes in namespaces for cross-VPC traffic
4.
Allow Forwarding
- Add ACCEPT rules in iptables
