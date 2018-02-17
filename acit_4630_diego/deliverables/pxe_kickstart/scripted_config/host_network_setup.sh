#!/bin/bash

vboxmanage () { VBoxManage.exe "$@"; }
declare script_path="$(readlink -f $0)"


vboxmanage natnetwork add --netname sys_net_prov --network 192.168.254.0/24  --enable --dhcp off
vboxmanage natnetwork modify --netname sys_net_prov --port-forward-4 rule1:tcp:[]:50022:[192.168.254.10]:22
vboxmanage natnetwork modify --netname sys_net_prov --port-forward-4 rule2:tcp:[]:50080:[192.168.254.10]:80
vboxmanage natnetwork modify --netname sys_net_prov --port-forward-4 rule3:tcp:[]:50443:[192.168.254.10]:443
vboxmanage natnetwork start --netname sys_net_prov
#vboxmanage setextradata global "NAT/sys_net_prov/SourceIp4" 192.168.1.81
