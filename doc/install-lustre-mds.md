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
     net:
    	- net type: lo
          local NI(s):
            - nid: 0@lo
              status: up
    	- net type: tcp
          local NI(s):
            - nid: 192.168.14.121@tcp
              status: up
              interfaces:
              	  0: eno1
      ```


