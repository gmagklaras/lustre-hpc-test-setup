# Lustre MDS installation

This procedure describes the installation of a RHEL8.8 based MDS server with Lustre 2.15.3. 

- 1) OS install via your favourite PXE solution the MDS server using the [mdstoberhel88.ks](hpcansible/files/kickstarts/mdstoberhel88.ks) kickstart file.  
- 2) Make sure that postinstall the system is booted in the patched Lustre 2.15.3 kernel, which should be: 
    ``` 
    [root@mds1 ~]# uname -a
    Linux mds1 4.18.0-477.10.1.el8_lustre.x86_64 #1 SMP Tue Jun 20 00:12:13 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux
    ```
     In essence, this makes sure that the *grub2-set-default* command of the [kickstart file](hpcansible/files/kickstarts/mdstoberhel88.ks) has worked). If not you could be getting errors like the ldiskfs-mount module is missing when you attempt the next step iv.
- 3) Once you have booted in the patched Lustre kernel, install the Lustre server RPM packages:
    ```
    dnf -y install http://192.168.122.33/lustre/2.15.3/el8.8/server/kmod-lustre-2.15.3-1.el8.x86_64.rpm http://192.168.122.33/lustre/2.15.3/el8.8/server/kmod-lustre-osd-ldiskfs-2.15.3-1.el8.x86_64.rpm http://192.168.122.33/lustre/2.15.3/el8.8/server/lustre-2.15.3-1.el8.x86_64.rpm http://192.168.122.33/lustre/2.15.3/el8.8/server/lustre-devel-2.15.3-1.el8.x86_64.rpm http://192.168.122.33/lustre/2.15.3/el8.8/server/lustre-osd-ldiskfs-mount-2.15.3-1.el8.x86_64.rpm http://192.168.122.33/lustre/2.15.3/el8.8/server/lustre-iokit-2.15.3-1.el8.x86_64.rpm 
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
     nid: 192.168.14.121@tcp
     status: up
     interfaces:
     0: eno1
     ```
     Make note of that NID because you will use it in latter steps when you format the Lustre filesystem. 
     If a node has more than one network interface, you'll typically want to dedicate a specific interface to Lustre. You can do this by including an entry in the */etc/modprobe.d/lustre.conf* file on the node that sets the LNet module networks parameter:
     *options lnet networks=comma-separated list of networks*
     This example specifies that a Lustre node will use a TCP/IP interface and an InfiniBand interface:
     ```
     options lnet networks=tcp0(eth0),o2ib(ib0)
     ```
- 5) Create the Lustre management service MGS filesystem. The MGS stores configuration information for one or more Lustre file systems in a cluster and provides this information to other Lustre hosts. Servers and clients connect to the MGS on startup in order to retrieve the configuration log for the file system. Notification of changes to a file system’s configuration, including server restarts, are distributed by the MGS. We will make separate mgs and mdt partitions. This is recommended for scalability. The name of our filesystem will be *DIAS*, the IP of the management node is *192.168.14.121* as shown by the NID obtain in step iv:
  ```
  lvcreate -L 152m -n LVMGSDIAS vg00
  mkfs.lustre --fsname=DIAS --mgs -mgsnode=192.168.14.121 /dev/vg00/LVMGSDIAS
   Permanent disk data:
  Target:     MGS
  Index:      unassigned
  Lustre FS:  DIAS
  Mount type: ldiskfs
  Flags:      0x64
              (MGS first_time update )
  Persistent mount opts: user_xattr,errors=remount-ro
  Parameters: mgsnode=192.168.14.121@tcp

  device size = 152MB
  formatting backing filesystem ldiskfs on /dev/vg00/LVMGSDIAS
	target name   MGS
	kilobytes     155648
	options        -q -O uninit_bg,dir_nlink,quota,project,huge_file,^fast_commit,flex_bg -E lazy_journal_init="0",lazy_itable_init="0" -F mkfs_cmd = mke2fs -j -b 4096 -L MGS  -q -O uninit_bg,dir_nlink,quota,project,huge_file,^fast_commit,flex_bg -E lazy_journal_init="0",lazy_itable_init="0" -F /dev/vg00/LVMGSDIAS 155648k
  Writing CONFIGS/mountdata
  ```
     
     Now the same for the metadata target MDT:

  ```
  lvcreate -L 95g -n LVMDTDIAS vg00
  mkfs.lustre --fsname=DIAS --mdt --mgsnode=192.168.14.121 --index=0 /dev/vg00/LVMDTDIAS
     Permanent disk data:
  Target:     DIAS:MDT0000
  Index:      0
  Lustre FS:  DIAS
  Mount type: ldiskfs
  Flags:      0x61
              (MDT first_time update )
  Persistent mount opts: user_xattr,errors=remount-ro
  Parameters: mgsnode=192.168.14.121@tcp

  checking for existing Lustre data: not found
  device size = 97280MB
  formatting backing filesystem ldiskfs on /dev/vg00/LVMDTDIAS
	target name   DIAS:MDT0000
	kilobytes     99614720
	options        -J size=3891 -I 1024 -i 2560 -q -O dirdata,uninit_bg,^extents,dir_nlink,quota,project,huge_file,ea_inode,large_dir,^fast_commit,flex_bg -E lazy_journal_init="0",lazy_itable_init="0" -F mkfs_cmd = mke2fs -j -b 4096 -L DIAS:MDT0000  -J size=3891 -I 1024 -i 2560 -q -O dirdata,uninit_bg,^extents,dir_nlink,quota,project,huge_file,ea_inode,large_dir,^fast_commit,flex_bg -E lazy_journal_init="0",lazy_itable_init="0" -F /dev/vg00/LVMDTDIAS 99614720k
  Writing CONFIGS/mountdata                               
  ```
  NOTE: IT IS IMPORTANT TO SPECIFY THE --mgsnode parameter with the IP. If you do not, you might not be able to register properly OSTs from OSS nodes. 

  Now, we can mount the MGS and MDT filesystems (assuming the mount points /lustre/mgs and /lustre/mdt0 are made:
  
 ```
 mount -t lustre /dev/vg00/LVMGSDIAS /lustre/mgs
 mount -t lustre /dev/vg00/LVMDTDIAS /lustre/mdt0/
 ```

- 6) Finally, you can enable quotas:
 ```
 lctl set_param -P osd-*.DIAS*.quota_slave_dt.enabled=ugp
 lctl set_param -P osd*.DIAS*.quota_slave_md.enabled=g
 ```
  
  The first command turns user, group and project quotas for BLOCK only (slave_dt) on the MGS. The second turns on group quotas for INODES only (slave_md) on the MGS. It might take a few moments from the time you issue these commands, until you see them effective with the following command:
 ```
 lctl get_param osd-*.*.quota_slave_*.enabled
 osd-ldiskfs.DIAS-MDT0000.quota_slave_dt.enabled=ugp
 osd-ldiskfs.DIAS-MDT0000.quota_slave_md.enabled=g
 ```

 You can also check across all OSS and MDT/MFS servers with something like this:
 ```
 (hpcansible) [georgios@cn1 hpcansible]$ ansible -i inventory/ -m shell -a "lctl get_param osd-*.*.quota_slave_*.enabled" storage
  mds | CHANGED | rc=0 >>
  osd-ldiskfs.DIAS-MDT0000.quota_slave_dt.enabled=ugp
  osd-ldiskfs.DIAS-MDT0000.quota_slave_md.enabled=g
  oss1 | CHANGED | rc=0 >>
  osd-ldiskfs.DIAS-OST0001.quota_slave_dt.enabled=ugp
  osd-ldiskfs.DIAS-OST0002.quota_slave_dt.enabled=ugp
  oss2 | CHANGED | rc=0 >>
  osd-ldiskfs.DIAS-OST0003.quota_slave_dt.enabled=ugp
 ```
 
 Depending on the size and state (how busy is the fs) of the filesystem, it might take some time to see this propagated across all OSSs.


At this point the configuration of the MDT.

 



   
   


