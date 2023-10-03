# Georgios Magklaras - Steelcyber.com NFS server for /home/modules and other management filesystems -- RHEL8.8 version
# Assumes a VM with at least 130 Gigs of disk storage on a single virtIO device 
# also registers the system with Redhat using the PPI key
# Pre script, will evaluate which is the smallest drive and use it as OS drive.
# The drive has to be less than 1 TB long, but larger than 100Gb.
# If one or more device is found, a RAID1 will be created.
# Variables should be escaped as this => \$var so cobbler does not complain.
#
%pre --interpreter /usr/bin/bash

vgchange -a n

declare -a avail_devices

for device in /sys/block/[s,v]d[a-z] 
do
  if [ -d "\${device}" ]
  then
    device_size=`cat \${device}/size`
    eval `grep DEVNAME \${device}/uevent`
#    if [ "\$device_size" -gt "209715200" -a "\$device_size" -lt "1000000000" ]
#    if [ "\$device_size" -gt "209715200" -a "\$device_size" -lt "2147483648" ]
#    if [ "\$device_size" -gt "209715200" -a "\$device_size" -lt "4009715200" ]
     avail_devices=("\$DEVNAME" \${avail_devices[*]})
  fi
done

case "\${#avail_devices[*]}" in
  0)
     echo "No drives found"
     exit 1
     ;;
  1)
     os_device=\${avail_devices[0]}
     parted -s /dev/\${avail_devices[0]} mklabel msdos

     echo "bootloader --location=mbr --driveorder=\${os_device} --append=\"console=tty1 console=ttyS0,115200n8 crashkernel=auto rhgb quiet\"" >> /tmp/partition-scheme.cfg
     echo "ignoredisk --only-use=\${os_device}" >> /tmp/partition-scheme.cfg
     echo "clearpart --drives=\${os_device} --initlabel --all" >> /tmp/partition-scheme.cfg
     echo "part /boot --fstype=\"ext4\" --asprimary --ondrive=\${os_device} --size=1024" >> /tmp/partition-scheme.cfg
     echo "part pv.01 --fstype=\"lvmpv\" --ondrive=\${os_device} --size 133120 --grow" >> /tmp/partition-scheme.cfg
     echo "volgroup vg00 pv.01"  >> /tmp/partition-scheme.cfg
     echo "logvol swap --fstype=\"swap\" --grow --size=2048 --maxsize=2048 --name=lv_swap --vgname=vg00" >> /tmp/partition-scheme.cfg
     echo "logvol /  --fstype="ext4" --grow --maxsize=8192 --size=8192 --name=lv_root --vgname=vg00" >> /tmp/partition-scheme.cfg
     echo "logvol /var/log  --fstype="ext4" --grow --maxsize=8192 --size=8192 --name=lv_var_log --vgname=vg00" >> /tmp/partition-scheme.cfg
     echo "logvol /exports/home  --fstype="xfs" --grow --maxsize=12000 --size=12000 --name=lv_home --vgname=vg00" >> /tmp/partition-scheme.cfg
     echo "logvol /exports/modules  --fstype="xfs" --grow --maxsize=103424 --size=103424 --name=lv_modules --vgname=vg00" >> /tmp/partition-scheme.cfg
     ;;
  2)
     raid_members="/dev/\${avail_devices[0]},/dev/\${avail_devices[1]}"
     for raid_device_member in \${avail_devices[@]}
     do
       mdadm --zero-superblock /dev/\$raid_device_member
       parted -s /dev/\$raid_device_member mklabel msdos
     done

     echo "bootloader --location=mbr --driveorder=\${raid_members} --append=\"console=tty1 console=ttyS0,115200n8 crashkernel=auto rhgb quiet\"" >> /tmp/partition-scheme.cfg
     echo "ignoredisk --only-use=\${raid_members}" >> /tmp/partition-scheme.cfg
     echo "clearpart --drives=\${avail_devices[0]},\${avail_devices[1]} --initlabel --all" >> /tmp/partition-scheme.cfg

     echo "part raid.11 --size 500 --asprimary --ondrive=\${avail_devices[0]}" >> /tmp/partition-scheme.cfg
     echo "part raid.12 --size 50000 --grow --ondrive=\${avail_devices[0]}" >> /tmp/partition-scheme.cfg

     echo "part raid.21 --size 500 --asprimary --ondrive=\${avail_devices[1]}" >> /tmp/partition-scheme.cfg
     echo "part raid.22 --size 100000  --grow --ondrive=\${avail_devices[1]}" >> /tmp/partition-scheme.cfg

     echo "raid /boot --fstype ext4 --device=md0 --level=RAID1 raid.11 raid.21" >> /tmp/partition-scheme.cfg
     echo "raid pv.01 --level=RAID1 --device=md1 raid.12 raid.22" >> /tmp/partition-scheme.cfg

     echo "volgroup vg00 pv.01" >> /tmp/partition-scheme.cfg
     echo "logvol swap --fstype=\"swap\" --size=2048 --maxsize=16000  --grow --name=lv_swap --vgname=vg00" >> /tmp/partition-scheme.cfg
     echo "logvol /  --fstype=\"ext4\" --grow --maxsize=25000 --size=10240 --name=lv_root --vgname=vg00" >> /tmp/partition-scheme.cfg
     echo "logvol /var/log  --fstype=\"ext4\" --grow --maxsize=10240 --size=4096 --name=lv_varlog --vgname=vg00" >> /tmp/partition-scheme.cfg
     ;;
  *)
     echo "Many drives found, unsupported configuration"
     echo "Found \${#avail_devices[*]} Devices: \${avail_devices[@]}"
     exit 1
esac

exec < /dev/tty6 > /dev/tty6 2> /dev/tty6
chvt 6

echo "-------------------------------------------------------------------"
echo "# THIS IS THE STEELCYBER LUSTRE NFS COMPUTE KICKSTART CONFIGURATION SCRIPT#"
echo "-------------------------------------------------------------------"
read -p "Please set the hostname for this OSS server (nfs1, nfs2): " OSS

echo "network --bootproto=dhcp --noipv6 --hostname $OSS --activate" > /tmp/ppihostname.txt

chvt 1
exec < /dev/tty1 > /dev/tty1 2> /dev/tty1

%end

#
# Main section
#
%include /tmp/partition-scheme.cfg
%include /tmp/ppihostname.txt

#version=DEVEL
# System authorization information
auth --enableshadow --passalgo=sha512
# Use network installation by pointing to the cobbler tree
url --url=$tree

text
firstboot --disabled
reboot
# Keyboard layouts
keyboard --vckeymap=no --xlayouts='no','us'
# System language
lang en_GB.UTF-8

# Root password
rootpw --iscrypted $6$tV5Hg4fO32/Ss1jP$5fnz.anhqV./MKNZp2xc3dTMAp8fX.tGWR9YSYFgxl20h8jj8IdZdatUB/0HUlNaPVpYCPsEGiG4fDTFmImHk/

# System services
selinux --disabled
skipx

# System timezone
timezone Etc/UTC --isUtc --ntpservers 0.no.pool.ntp.org,1.no.pool.ntp.org

%packages
@base
@core
@hardware-monitoring
@network-file-system-client
@performance
wget
sssd
kernel-headers
kernel-devel
openssh-server
NetworkManager
kexec-tools
vim
valgrind
evince
nfs-utils

%end

%post

mkdir -p /root/.ssh
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQD6+798ySe8JxvEZNz2DSGS9tEOQc2fcqDkB8siFr40f2cKsi88xjV5gKJ/7pfiV2pwzYTd/SW7bOrV4dLeBcTipUL7Pv1R+WJ2a7OW3yNw3vO7V7XQ77GZYCj6j7yJJ9BfKkOMSoPycpVtUafa5RScYhyL/+gzqwf/CMqnndGG9lp+1NyaEKvi0CS3mVYziVEKIiOgBhp/3pPE1PaBwEbbDmkDJfXYtVaiBCpo8yrHzJIQUP6+hygKS0noqMk013uz+WTg9XbOP3ik9Xh79bLEIrGoORjyPqKEqz2BT1xc4WuRSgvI55do/NVc+lNBisw5bZm/vxEw4X4rB5/gN4MO8E2ihxeJANwpoawanVnDTyPYjCez8e9ioYVjYdY6rIsAKrqAiqfAjdJpeRPy2+/aV7HeVsOLo20Pog+GzPksKSi8BdTeAUK4kpK2km8nmon+u7a9hagKqq6p8kOVZWMpm1Wzszy29uybJ8pkXmseutNr7CCYV/JMJYk7weIPlKs= georgios@agrinio.steelcyber.com" >> /root/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDeOBC3wGJhwBYMNI3qk3QTY5lwK6fqIZ8DGnYlZDgzcRijz3jj0wy1bWPKld5kFGG9C4qEKpYNvtcMZvLhfUQdeZu+W/7o5Xeh0LbKB3/gT2IU0ltbJOcW65S5k4UBjXbtF+kgl8GqhVxpMwu3RxvVYnFYMCpCx87Vzc/slx1ZpUc5ru8zpjQg4R2gfUyFxFgpbbCSpwGe02l5OluEHYZ/1JPHfG5PmXXEO6xfmxiSugvC6QuYXFi3HOCNdP4tDFNQWvgd0HQqj3gSYLX4BXNMAIKOQ43h98Vuh8SQLrDjjC0Ru0JA9sAIbbwA1msowZEHzplacD1haGZ8LZKdMmcmzYS7f5wGwP1mgakrCJ6syeZXWX4cF6gWyUfv5HAVe48zkAtaDS25Hot2rpCiH3TfMohyW8ACtkbABThZVC6eiMsaMwTPtE34h6v/zRJxvitVFxliDAkrFiHGdKWP7lC67Ut7/d4G29SXuf7Hj4Fn1Gb2k8tmzZrDmnU/EiPaI1U= georgios@pxemaster.steelcyber.hpc" >> /root/.ssh/authorized_keys

#Set the hostname for that system from the data we got interactively on the pre section
hostnamectl set-hostname $( cat /tmp/ppihostname.txt )

dnf install -y kernel
dnf install -y kernel-headers
dnf install -y kernel-devel


#Here we install the latest ELrepo and EPEL releases, necessary for DRBD and other requirements
dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
dnf -y install https://www.elrepo.org/elrepo-release-8.el8.elrepo.noarch.rpm
# info about hw errors
#systemctl enable mcelog
#systemctl start mcelog


systemctl enable network.service
systemctl start network.service

systemctl enable NetworkManager
systemctl start NetworkManager

timedatectl set-timezone UTC


#Make the NFS server directories
mkdir -p /exports/home
mkdir -p /exports/modules

cat <<EOF >>/etc/fstab
EOF

cat <<EOF >>/etc/exports
/exports/home		192.168.14.0/24(rw,async,no_root_squash)
/exports/modules	192.168.14.0/24(rw,async,no_root_squash)
EOF

#Default firewall rules to ensure that we do not expose port 22, 111 and others where we should not
#UNTIL we run the ansible recipes
cat <<EOF >>/etc/sysconfig/iptables
*filter
:INPUT ACCEPT [0:0]
:FORWARD ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
EOF


cat <<EOF >/etc/sysctl.d/99-sysctl.conf
# name in /etc/sysctl.d/ and put new settings there.
#
# For more information, see sysctl.conf(5) and sysctl.d(5).
net.ipv6.conf.all.disable_ipv6=1
net.ipv6.conf.default.disable_ipv6=1
net.ipv6.conf.lo.disable_ipv6=1
kernel.panic=60

net.core.rmem_max=67108864
net.core.wmem_max=67108864
net.ipv4.tcp_rmem=4096 87380 33554432
net.ipv4.tcp_wmem=4096 87380 33554432
net.ipv4.tcp_mtu_probing=1
net.core.default_qdisc=fq

net.ipv4.tcp_slow_start_after_idle=0
EOF

#Ensure that firewalld is disabled, will be enabled again from the Ansible
#basic PPI OS configuration scripts
systemctl disable firewalld.service
systemctl stop firewalld.service

#Enable the NFS server
systemctl enable --now nfs-server
systemctl enable --now rpcbind

#Register the system with the PPI key
subscription-manager register --org=5732243 --activationkey=ppi
#This is required for a RHEL8 host to be able to install dkms and libyaml-devel, all requirements for Lustre
subscription-manager repos --enable codeready-builder-for-rhel-8-x86_64-rpms

#Necessary packages
dnf install -y koan rpm-build libtool libsepol-devel libselinux-devel iptables-services 


#Finally register the new node with cobbler based on the hostname we have already set
cobbler-register -s 192.168.14.101 -f $( cat /etc/hostname ) --profile=servernfs

#Enable and start the IPTABLES service
systemctl enable iptables.service
systemctl start iptables.service

#Enable the chronyd service
systemctl enable chronyd.service
systemctl start chronyd.service

# sol
systemctl enable serial-getty@ttyS0.service 
systemctl start serial-getty@ttyS0.service
systemctl enable serial-getty@ttyS1.service
systemctl start serial-getty@ttyS1.service
echo ttyS1 >> /etc/securetty

echo GRUB_CMDLINE_LINUX_DEFAULT=\"nomodeset console=tty0 console=ttyS1,115200n8 consoleblank=0\" >> /etc/default/grub
echo GRUB_TERMINAL=serial >> /etc/default/grub
echo GRUB_SERIAL_COMMAND=\"serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1\" >> /etc/default/grub
grub2-mkconfig > /boot/grub2/grub.cfg

grub2-set-default 0
grub2-mkconfig -o /boot/grub2/grub.cfg

#Finally update system
dnf -y update 
systemctl reboot

%end

