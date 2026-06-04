#!/bin/bash
iface=$(ip -c=never -o link show | grep -Eo "^[0-9]: [[:alnum:]]+" | cut -f2 -d" " | egrep -v "^lo|^w" | head -1)
ip link set "$iface" up
dhclient "$iface"
