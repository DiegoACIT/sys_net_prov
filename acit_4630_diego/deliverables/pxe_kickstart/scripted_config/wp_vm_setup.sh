#!/bin/bash

declare script_path="$(readlink -f $0)"

vboxmanage () { VBoxManage.exe "$@"; }

# get the abosolute path of the current script 
declare script_path="$(readlink -f $0)"

# get the path of its enclosing directory us this to setup relative paths
declare script_dir=$(dirname "${script_path}")


# Cludge to get the path of the directory where the vbox file is stored. 
# Used to create hard disk file in same directory as vbox file without using 
# absolute paths

# You will need to change the VM name to match one of your VM's
declare vm_name="test"



vboxmanage createvm --name ${vm_name} --register

#Create Virtual Hard Disk
vboxmanage createhd --filename "/Users/diego/VirtualBox VMs/test/test.vdi" --size 10240 -variant Standard

#Add Storage Controllers
vboxmanage storagectl ${vm_name} --name IDE_PORT --add ide  --bootable on
vboxmanage storagectl ${vm_name} --name SATA_PORT --add sata --bootable on

#Attach an installation ISO
vboxmanage storageattach ${vm_name} --storagectl IDE_PORT  --port 0 --device 0 --type dvddrive --medium "/Users/diego/VirtualBox VMs/CentOS-7-x86_64-Minimal-1708.iso"


vboxmanage storageattach ${vm_name} --storagectl SATA_PORT --port 1 --device 0 --type hdd --medium "C:/Users/diego/VirtualBox VMs/test/test.vdi" --nonrotational on


vboxmanage modifyvm ${vm_name} --groups "/myproject" --ostype "RedHat_64" --cpus 1 --hwvirtex on --nestedpaging on --largepages on --firmware bios --nic1 natnetwork --nat-network1 sys_net_prov --cableconnected1 on --audio none --boot1 disk --boot2 dvd --memory "1280"

vboxmanage startvm ${vm_name} --type gui
