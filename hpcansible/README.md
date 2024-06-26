# hpcansible repository

The purpose of this repository is to enable automation and management of the lustre-hpc-test-setup.

Part of the management tasks is to ensure that we have common uid/gids across all compute nodes and the MDS. This is really important to implement issues like quotas:

To install the ansible environment, ensure that you take control of a compute node, *after* the NFS setup is complete. The reason we need to complete and mount the NFS setup first is to ensure that the users we will create are going to end up having their home directory structure under the NFS exported home directories.

Once the NFS setup is complete and the compute nodes have mounted /home, you can issue the following commands on the compute node:

- To ensure that you create the users for the first time, issue as root the following commands:
  ```
   useradd -d /home/georgios -u 1000 georgios
   useradd -d /home/user1 -u 1001 user1
   useradd -d /home/user2 -u 1002 user2
   useradd -d /home/user3 -u 1003 user3
   useradd -d /home/user4 -u 1004 user4
  ```

- To ensure that you can create a Python Virtual environment, still as root on the compute node, issue:
  ```
   dnf install python3.11 python3.11-devel
   alternatives --set python /usr/bin/python3.11 
  ```
  to install a recent python version on the RHEL 8.8 plarform (the default Python 3.6 is too old) and ensure that is set as a default python3 for the system.

- Then switch to the non root userid you will choose to perform management functions and make a Python venv:
  ```
   su - georgios
   python3.11 -m venv hpcansible
  ```
  The above should create an hpcansible venv under the $HOME of georgios. 

- Activate this environment and install ansible:
  ```
  source hpcansible/bin/activate
  pip3 install ansible
  ```

You should now be able to clone the lustre-hpc-test-setup git repo under the management user $HOME:
```
git clone https://github.com/gmagklaras/lustre-hpc-test-setup.git 
```

- Test the ansible setup now by doing the following:
  ```
  (hpcansible) [georgios@cn1 ~]$ cd lustre-hpc-test-setup/
  (hpcansible) [georgios@cn1 lustre-hpc-test-setup]$ cd hpcansible/
  (hpcansible) [georgios@cn1 hpcansible]$ ansible all -i inventory/ -m ping
  ```
  If all is well and the systems are setup properly after following the procedure, you should see the ansible ping pong response like the one below:
  ```
  oss1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
  }
  oss2 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
  }
  mds | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
  }
  cn1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
  }
  cn2 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/libexec/platform-python"
    },
    "changed": false,
    "ping": "pong"
  }
  ```

You can try now to setup authentication across the compute nodes and the MDS by running the setauthentication.yml playbook:
```
(hpcansible) [georgios@cn1 hpcansible]$ ansible-playbook -i inventory/ setauthentication.yml -l cn1,cn2,mds --diff
```

If all goes well, you should see output like the one below:
```
PLAY [Setup users and groups] *************************************************************************************

TASK [Gathering Facts] ********************************************************************************************
ok: [mds]
ok: [cn1]
ok: [cn2]

TASK [Copy/sync the /etc/passwd with owner and permissions] *******************************************************
ok: [mds]
ok: [cn2]
ok: [cn1]

TASK [Copy/sync the /etc/group with owner and permissions] ********************************************************
ok: [mds]
ok: [cn1]
ok: [cn2]

TASK [Concatenate to the /etc/passwd if the info does not exist] **************************************************
changed: [mds]
changed: [cn1]
changed: [cn2]

TASK [Concatenate to the /etc/group if the info does not exist] ***************************************************
changed: [mds]
changed: [cn1]
changed: [cn2]

PLAY RECAP ********************************************************************************************************
cn1                        : ok=5    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
cn2                        : ok=5    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0   
mds                        : ok=5    changed=2    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0 
```

and check for example that individual users exist across the nodes:
```
(hpcansible) [georgios@cn1 hpcansible]$ ansible -i inventory/ -m shell -a "cat /etc/passwd /etc/group | grep georgios" compute
cn1 | CHANGED | rc=0 >>
georgios:x:1000:1000::/home/georgios:/bin/bash
georgios:x:1000:
cn2 | CHANGED | rc=0 >>
georgios:x:1000:1000::/home/georgios:/bin/bash
georgios:x:1000:
```






