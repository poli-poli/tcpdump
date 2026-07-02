#!/bin/sh
# Prepare BPF filter corpus for fuzzing
mkdir -p /fuzz/bpf_corpus

cat > /fuzz/bpf_corpus/tcp.txt << 'EOF'
tcp
EOF

cat > /fuzz/bpf_corpus/port.txt << 'EOF'
port 80
EOF

cat > /fuzz/bpf_corpus/host.txt << 'EOF'
host 192.168.1.1
EOF

cat > /fuzz/bpf_corpus/complex.txt << 'EOF'
tcp port 80 and host 192.168.1.1
EOF

cat > /fuzz/bpf_corpus/proto.txt << 'EOF'
ip proto 6
EOF

cat > /fuzz/bpf_corpus/udp.txt << 'EOF'
udp port 53
EOF

cat > /fuzz/bpf_corpus/icmp.txt << 'EOF'
icmp
EOF

cat > /fuzz/bpf_corpus/gateway.txt << 'EOF'
gateway 10.0.0.1
EOF

cat > /fuzz/bpf_corpus/net.txt << 'EOF'
net 10.0.0.0/8
EOF

cat > /fuzz/bpf_corpus/range.txt << 'EOF'
portrange 1024-65535
EOF

cat > /fuzz/bpf_corpus/not.txt << 'EOF'
not tcp
EOF

cat > /fuzz/bpf_corpus/or.txt << 'EOF'
tcp or udp or icmp
EOF

cat > /fuzz/bpf_corpus/src.txt << 'EOF'
src 192.168.1.0/24
EOF

cat > /fuzz/bpf_corpus/dst.txt << 'EOF'
dst host 10.0.0.1
EOF

cat > /fuzz/bpf_corpus/less.txt << 'EOF'
less 1500
EOF

cat > /fuzz/bpf_corpus/ip6.txt << 'EOF'
ip6 host fe80::1
EOF

cat > /fuzz/bpf_corpus/vlan.txt << 'EOF'
vlan 100
EOF

cat > /fuzz/bpf_corpus/arp.txt << 'EOF'
arp
EOF

cat > /fuzz/bpf_corpus/within.txt << 'EOF'
tcp[0] = 0x02
EOF

cat > /fuzz/bpf_corpus/byte_test.txt << 'EOF'
ip[6:2] = 0x0800
EOF

cat > /fuzz/bpf_corpus/mixed.txt << 'EOF'
(tcp port 80 or port 443) and host 10.0.0.1 and not arp
EOF

cat > /fuzz/bpf_corpus/bpf_program.txt << 'EOF'
tcp[tcpflags] & (tcp-syn|tcp-fin) != 0
EOF

cat > /fuzz/bpf_corpus/dns.txt << 'EOF'
udp port 53 and (ip[2:2] > 512)
EOF

cat > /fuzz/bpf_corpus/broadcast.txt << 'EOF'
broadcast
EOF

cat > /fuzz/bpf_corpus/multicast.txt << 'EOF'
multicast
EOF

cat > /fuzz/bpf_corpus/ether.txt << 'EOF'
ether host 00:11:22:33:44:55
EOF

cat > /fuzz/bpf_corpus/collide.txt << 'EOF'
collide
EOF

cat > /fuzz/bpf_corpus/pon.txt << 'EOF'
pon
EOF

cat > /fuzz/bpf_corpus/pppoe.txt << 'EOF'
pppoe
EOF

echo "BPF corpus prepared: $(ls /fuzz/bpf_corpus/ | wc -l) seed files"
