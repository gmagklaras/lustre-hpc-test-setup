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
  dnf -y install http://192.168.122.33/lustre/2.15.3/el8.8/server/kmod-lustre-2.15.3-1.el8.x86_64.rpm http://192.168.122.33/lustre/2.15.3/el8.8/server/kmod-lustre-osd-ldiskfs-2.15.3-1.el8.x86_64.rpm http://192.168.122.33/lustre/2.15.3/el8.8/server/lustre-2.15.3-1.el8.x86_64.rpm http://192.168.122.33/lustre/2.15.3/el8.8/server/lustre
-devel-2.15.3-1.el8.x86_64.rpm http://192.168.122.33/lustre/2.15.3/el8.8/server/lustre-osd-ldiskfs-mount-2.15.3-1.el8.x86_64.rpm http://192.168.122.33/lustre/2.15.3/el8.8/server/lustre-iokit-2.15.3-1.el8.x86_64.rpm 
  ```


