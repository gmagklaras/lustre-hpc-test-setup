# lustre-test-setup
The purpose of this repository is to test and implement a small and simple Lustre filesystem setup, in order to:
- become familiar with a verified Lustre Setup
- play with features of Lustre (file striping) 
- test procedures (OST outage, OSS outage, file migration from one OST to another)

Small and simple means that we do not implement (yet) failover, interconnect. So, this test setup will implement the following:
- 1 x MDS server based on RHEL 8.8 and Lustre 2.15.3 
- 2 x OSS servers based on RHEL 8.8 and Lustre 2.15.3
- Two Lustre clients based on RHEL 8.8 and Lustre 2.15.3
as the absolute minimum setup, all connected by an ethernet switch.

Most of the procedures and files of this repository should also work with Rocky and Alma Linux. RHEL is used here to validate procedures for an enterprise work setup.

It is recommended that one uses the following Bill Of Materials to implement this setup:
- One dedicated 8 x compute core, 16/32 Gb of RAM server with a RAID1 hardware SSD partition for MDS and at least one 1Gbit Ethernet NIC (Example: refurbished Dell EMC R220 server)
- Two dedicated 8 x compute core, 16/32 Gb of RAM server with a RAID1 hardware SSD partition for serving OSTs and at least 1Gbit Ethernet NIC (Example: refurbished Dell EMC R220 server)
- One server/workstation/laptop with 16 cores and 32 Gb of RAM, 512 Gbyte disk space and two 1xGbit Ethernet connection to provide virtual machines, iPXE and OS deployment features for the clients.

 
