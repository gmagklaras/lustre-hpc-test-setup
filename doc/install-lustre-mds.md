# Lustre MDS installation

This procedure describes the installation of a RHEL8.8 based MDS server with Lustre 2.15.3. 

- 1) OS install via your favourite PXE solution the MDS server using the [mdstoberhel88.ks](hpcansible/files/kickstarts/mdstoberhel88.ks) kickstart file.  

- 2) Make sure that the system is booted in the LUSTRE kernel, which should be: 
  ``` 
  [root@mds1 ~]# uname -a
  Linux mds1 4.18.0-477.10.1.el8_lustre.x86_64 #1 SMP Tue Jun 20 00:12:13 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux
  ```
