# lustre-hpc-test-setup
The purpose of this repository is to test and implement a small and simple Lustre filesystem setup, in order to:
- become familiar with a verified Lustre Setup
- play with features of Lustre (file striping) 
- test procedures such as the following:
  - [Install an MDS server](doc/install-lustre-mds.md)
  - [Install OSS servers](doc/install-lustre-oss.md)
  - Install Lustre clients and mount the test Lustre filesystem 
  - [OSS outage and recorery](doc/simulate-an-OST-OSS-failure.md)
  - file migration from one OST to another
  - addition of OSTs
  - removal of OSTs
  - how to interface Lustre filesystems via NFS/CIFS gateways

Small and simple means that we do not implement (yet) failover, interconnect. So, this test setup will implement the following:
- 1 x MDS server based on [RHEL 8.9](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/8.9_release_notes/index) and [Lustre 2.15.4](https://www.lustre.org/lustre-2-15-4-released/) 
- 2 x OSS servers based on [RHEL 8.9](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/8.9_release_notes/index) and [Lustre 2.15.4](https://www.lustre.org/lustre-2-15-4-released/)
- Two Lustre clients based on [RHEL 8.8](https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/8.8_release_notes/index) and [Lustre 2.15.3](https://www.lustre.org/lustre-2-15-3-released/)

as the absolute minimum setup, all connected by a 1 Gbps grade ethernet switch.

Most of the procedures and files of this repository should also work with the [Rocky](https://rockylinux.org/) and [Alma](https://almalinux.org/) Linux distributions. RHEL is used here to validate procedures for an enterprise work setup.

It is recommended that one uses the following Bill Of Materials to implement this setup:
- One dedicated 8 x compute core, 16/32 Gb of RAM server with a RAID1 hardware SSD partition for MDS and at least one 1Gbit Ethernet NIC (Example: refurbished Dell EMC R220 server)
- Two dedicated 8 x compute core, 16/32 Gb of RAM server with a RAID1 hardware SSD partition for serving OSTs and at least 1Gbit Ethernet NIC (Example: refurbished Dell EMC R220 server)
- One server/workstation/laptop with 16 cores and 32 Gb of RAM, 512 Gbyte of disk space and two 1xGbit Ethernet connection to provide virtual machines for:
  - Lustre clients
  - iPXE, OS deployment and other management functionality

Although all of these hosts could be implemented using VMs, it is highly recommended to invest in separate physical machines to implement the MDS and OSS part, so that network and disk performance is realistic. The clients and other management hosts can of course run in VMs. 


 
