#hpcansible repository

The purpose of this repository is to enable automation and management of the lustre-hpc-test-setup.

Part of the management tasks is to ensure that we have common uid/gids across all compute nodes and the MDS. This is really important to implement issues like quotas:

To install the ansible environment, ensure that you take control of a compute node, *after* the NFS setup is complete. 

Once the NFS setup is complete and the compute nodes have mounted /home, you can issue the following commands on the compute node:

- To ensure that you create the users for the first time, issue as root the following commands:

```
useradd -d /home/georgios -u 1000 georgios
useradd -d /home/user1 -u 1001 user1
useradd -d /home/user2 -u 1002 user2
useradd -d /home/user3 -u 1003 user3
useradd -d /home/user4 -u 1004 user4
```


```dnf install python3.11 python3.11-devel```

to install a recent python version. 






