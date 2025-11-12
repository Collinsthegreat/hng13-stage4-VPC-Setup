#!/bin/bash
# Complete VPC Cleanup Script

echo "🧹 Starting complete VPC cleanup..."

# Kill all Python HTTP servers
echo "Stopping web servers..."
sudo pkill -f "python3 -m http.server" 2>/dev/null || true

# Delete all VPCs
echo "Deleting all VPCs..."
for vpc_file in /var/run/vpcctl/*.json; do
    [ -f "$vpc_file" ] || continue
    vpc_name=$(basename "$vpc_file" .json)
    echo "  Deleting VPC: $vpc_name"
    sudo vpcctl delete-vpc --name "$vpc_name" 2>/dev/null || true
done

# Clean up any orphaned namespaces
echo "Cleaning orphaned namespaces..."
for ns in $(sudo ip netns list 2>/dev/null | awk '{print $1}'); do
    if [[ $ns == vpc* ]] || [[ $ns == *test* ]]; then
        echo "  Removing namespace: $ns"
        sudo ip netns del "$ns" 2>/dev/null || true
    fi
done

# Clean up orphaned bridges
echo "Cleaning orphaned bridges..."
for br in $(ip link show type bridge 2>/dev/null | grep -o 'vpc[^:]*-br' || true); do
    echo "  Removing bridge: $br"
    sudo ip link set "$br" down 2>/dev/null || true
    sudo ip link del "$br" 2>/dev/null || true
done

# Clean up orphaned veth pairs
echo "Cleaning orphaned veth pairs..."
for veth in $(ip link show type veth 2>/dev/null | grep -o 'veth[a-z0-9]*h' || true); do
    echo "  Removing veth: $veth"
    sudo ip link del "$veth" 2>/dev/null || true
done

# Clean up peering veth pairs
for veth in $(ip link show type veth 2>/dev/null | grep -o 'peer[a-z0-9]*' || true); do
    echo "  Removing peer veth: $veth"
    sudo ip link del "$veth" 2>/dev/null || true
done

# Clean up NAT rules
echo "Cleaning NAT rules..."
sudo iptables -t nat -F POSTROUTING 2>/dev/null || true
sudo iptables -F FORWARD 2>/dev/null || true

# Clean up state directory
echo "Cleaning state files..."
sudo rm -rf /var/run/vpcctl/* 2>/dev/null || true

# Verify cleanup
echo ""
echo "✅ Cleanup complete!"
echo ""
echo "Verification:"
namespaces_count=$(sudo ip netns list 2>/dev/null | grep -c vpc || echo 0)
bridges_count=$(ip link show type bridge 2>/dev/null | grep -c vpc || echo 0)
veth_count=$(ip link show type veth 2>/dev/null | grep -c veth || echo 0)
peer_count=$(ip link show | grep -c 'peer-vpc' || echo 0)
vpc_state_count=$(ls -1 /var/run/vpcctl/*.json 2>/dev/null | wc -l)

echo "  Namespaces: $namespaces_count"
echo "  Bridges: $bridges_count"
echo "  Veth pairs: $veth_count"
echo "  Peer links: $peer_count"
echo "  VPC State Files: $vpc_state_count"
echo ""

# Final cleanup for any leftover peer interfaces
if [ "$peer_count" -gt 0 ]; then
    echo "Cleaning leftover peer interfaces..."
    for iface in $(ip link show | grep -o 'peer-vpc[^:@ ]*'); do
        echo "  Removing $iface"
        sudo ip link del "$iface" 2>/dev/null || true
    done
fi

if [ "$namespaces_count" -eq 0 ] && \
   [ "$bridges_count" -eq 0 ] && \
   [ "$veth_count" -eq 0 ] && \
   [ "$peer_count" -eq 0 ]; then
    echo "✨ System is clean!"
else
    echo "⚠️  Some resources may still exist. Check manually:"
    echo "  sudo ip netns list"
    echo "  ip link show"
fi
