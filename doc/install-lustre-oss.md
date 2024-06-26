# Lustre OSS installation

This procedure describes the installation of a RHEL8.9 based OSS server with Lustre 2.15.4. Repeat the steps for every OSS server that you will need to install:

- 1) OS install via your favourite PXE solution the OSS server using the [ossrhel89.ks](../hpcansible/files/kickstarts/ossrhel89.ks) kickstart file.  
- 2) Make sure that postinstall the system is booted in the patched Lustre 2.15.4 kernel, which should be: 
    ``` 
[root@mds1 ~]# uname -a
Linux mds1 4.18.0-513.9.1.el8_lustre.x86_64 #1 SMP Sat Dec 23 05:23:32 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux
    
    ```
     In essence, this makes sure that the *grub2-set-default* command of the [kickstart file](hpcansible/files/kickstarts/ossrhel89.ks) has worked). If not you could be getting errors like the ldiskfs-mount module is missing when you attempt the next step iv.
- 3) Once you have booted in the patched Lustre kernel, install the Lustre server RPM packages:
    ```
    dnf -y install http://192.168.122.33/lustre/2.15.4/el8.9/server/kmod-lustre-2.15.4-1.el8.x86_64.rpm http://192.168.122.33/lustre/2.15.4/el8.9/server/kmod-lustre-osd-ldiskfs-2.15.4-1.el8.x86_64.rpm http://192.168.122.33/lustre/2.15.4/el8.9/server/lustre-2.15.4-1.el8.x86_64.rpm http://192.168.122.33/lustre/2.15.4/el8.9/server/lustre-devel-2.15.4-1.el8.x86_64.rpm http://192.168.122.33/lustre/2.15.4/el8.9/server/lustre-osd-ldiskfs-mount-2.15.4-1.el8.x86_64.rpm http://192.168.122.33/lustre/2.15.4/el8.9/server/lustre-iokit-2.15.4-1.el8.x86_64.rpm
    ```
- 4) Activate the lnet module and configute LNet:
    ```
    modprobe lnet
    ```
    If you get errors that the ldiskfs-mount module is missing, see step ii above.
    Configure LNet now:
    ```
    lnetctl lnet configure [--all]
    lnetctl net add --net tcp --if eno1 --peer-timeout 180 --peer-credits 8
    ```
    The above commands create the *tcp* LNet network that is bound to the *eno1* NIC. This should be the NIC that will carry the LNet traffic. Check the status of the above commands by issuing a:
    ```
    lnetctl global show
    ```
    You should be getting output like the one below:
    ```
    global:
      numa_range: 0
      max_interfaces: 200
      discovery: 1
      drop_asym_route: 0
      retry_count: 2
      transaction_timeout: 50
      health_sensitivity: 100
      recovery_interval: 1
      router_sensitivity: 100
      lnd_timeout: 16
      response_tracking: 3
      recovery_limit: 0
     ```
     Check also that: 
     ```
     lnetctl net show
     ```
     gives you output including an NID, as shown below:
     ```
     nid: 192.168.14.178@tcp
     status: up
     interfaces:
     0: eno1
     ```
     If a node has more than one network interface, you'll typically want to dedicate a specific interface to Lustre. You can do this by including an entry in the */etc/modprobe.d/lustre.conf* file on the node that sets the LNet module networks parameter:
     *options lnet networks=comma-separated list of networks*
     This example specifies that a Lustre node will use a TCP/IP interface and an InfiniBand interface:
     ```
     options lnet networks=tcp0(eth0),o2ib(ib0)
     ```
    At that point, provided that your MDS server is up and set completely as described in the [MDS setup procedures](install-lustre-mds.md) of this repo, it would be good to try and check that you can ping the NID of the MDS server via LNET. Issue an:
    ```
    lnetctl net show
    ```
   at your MDS server and obtain its NID. If for instance its NID is 192.168.14.121@tcp, then move back to your OSS server and issue a:
    ```
    lctl ping 192.168.14.121@tcp
    ```
   If the response is like the one above:
    ```
    12345-0@lo
    12345-192.168.14.121@tcp
    ```
   this means that the LNET communication between the OSS and the MDS server is good. However, if the lctl ping fails as shown below: 
   ```
   failed to ping 192.168.14.121@tcp: Input/output error
   ```
   you will have to rectify and see what the networking problem is first prior continuing with the rest of the procedure steps.

- 5) Create the Lustre OST filesystem(s): Files in Lustre are composed of one or more OST objects, in addition to the metadata inode stored on the MDS. For every available block device (RAID disk group, partition) we need to make a volume construct. In our case, our OSS server has a RAID partition of approx 185 Gigabytes:
  ```
  Disk /dev/sda: 223 GiB, 239444426752 bytes, 467664896 sectors
  Units: sectors of 1 * 512 = 512 bytes
  Sector size (logical/physical): 512 bytes / 512 bytes
  I/O size (minimum/optimal): 512 bytes / 512 bytes
  Disklabel type: dos
  Disk identifier: 0x80586e4e

  Device     Boot     Start       End   Sectors  Size Id Type
  /dev/sda1  *         2048   1050623   1048576  512M 83 Linux
  /dev/sda2         1050624 389023743 387973120  185G 8e Linux LVM
  /dev/sda3       389023744 467664895  78641152 37.5G 8e Linux LVM
  [root@oss1 ~]#  pvcreate pvoss1 /dev/sda2
  No device found for vgoss1.
  Physical volume "/dev/sda2" successfully created.
  [root@oss1 ~]# vgcreate vgoss1 /dev/sda2
  Volume group "vgoss1" successfully created
  [root@oss1 ~]# lvcreate -L 184g --name LVDIASOST1 vgoss1
  Logical volume "LVDIASOST1" created.
  [root@oss1 ~]# mkfs.lustre --fsname=DIAS --mgsnode=192.168.14.121@tcp --ost --index=1 /dev/vgoss1/LVDIASOST1

  Permanent disk data:
  Target:     DIAS:OST0001
  Index:      1
  Lustre FS:  DIAS
  Mount type: ldiskfs
  Flags:      0x62
             (OST first_time update )
  Persistent mount opts: ,errors=remount-ro
  Parameters: mgsnode=192.168.14.121@tcp

  checking for existing Lustre data: not found
  device size = 188416MB
  formatting backing filesystem ldiskfs on /dev/vgoss1/LVDIASOST1
	target name   DIAS:OST0001
	kilobytes     192937984
	options        -J size=1024 -I 512 -i 69905 -q -O extents,uninit_bg,dir_nlink,quota,project,huge_file,^fast_commit,flex_bg -G 256 -E resize="4290772992",lazy_journal_init="0",lazy_itable_init="0" -F
  mkfs_cmd = mke2fs -j -b 4096 -L DIAS:OST0001  -J size=1024 -I 512 -i 69905 -q -O extents,uninit_bg,dir_nlink,quota,project,huge_file,^fast_commit,flex_bg -G 256 -E resize="4290772992",lazy_journal_init="0",lazy_itable_init="0" -F /dev/vgoss1/LVDIASOST1 192937984k
  Writing CONFIGS/mountdata
  ```

  NOTE: IT IS IMPORTANT TO SPECIFY THE --mgsnode parameter with the IP of the MDS server as well as the same --fsname as the ones on the MDS server in the mkfs.lustre command on the OSS server. Also important is the index number when we join more OSTs (from the same or other servers). Index numbers should not be duplicated amongst different filesystems as this will cause problems when the OSTs will be added to the filesystem! The first index numbers are always the MDTs and then the OSTs follow in index sequence. 

- 6) The next command is to try and mount the filesystem we have constructed. When we mount the constructed OST of the previous step, this will join the live filesystem, so again, make sure you have the index number right:
 ```
 mount -t lustre /dev/vgoss1/LVDIASOST1 /lustre/ost/OST0001/
 ```

and if there are no errors from the mount process on the OSS server, we should check on a client with the lfs df -h command:

 ```
 [root@cn1 storeA]# lfs df -h
 UUID                       bytes        Used   Available Use% Mounted on
 DIAS-MDT0000_UUID          52.7G        5.3M       48.0G   1% /lustre/storeA[MDT:0]
 DIAS-OST0001_UUID         180.2G        1.2M      170.9G   1% /lustre/storeA[OST:1]

 filesystem_summary:       180.2G        1.2M      170.9G   1% /lustre/storeA
 ``

At this point the configuration of the OSS server config is complete!

