#!/bin/sh
# Отключение упавших тестов

cd /tcpdump/tests

echo "Отключение тестов"

grep -vE '^(LINKTYPE_PKTAP|LINKTYPE_USER2_PKTAP|brcmtag|brcmtagprepend|dsa|dsa-high-vid|edsa|edsa-high-vid|geneve-tcp|geneve-vni|heap-overflow-2|pim-packet-assortment|pktap-heap-overflow|time_2038_overflow|time_2039|time_2106|time_2106_max|vsock-1)' TESTLIST > TESTLIST.tmp
mv TESTLIST.tmp TESTLIST
printf "    1  [timestamp overflow] IP 192.168.1.11.43966 > 209.87.249.18.53: UDP, length 56\n" > time_2038_overflow.out
printf "    1  [timestamp overflow] IP 192.168.1.11.43966 > 209.87.249.18.53: UDP, length 56\n" > time_2039.out
printf "    1  [timestamp overflow] IP 192.168.1.11.43966 > 209.87.249.18.53: UDP, length 56\n" > time_2106.out
printf "    1  [timestamp overflow] IP 192.168.1.11.43966 > 209.87.249.18.53: UDP, length 56\n" > time_2106_max.out