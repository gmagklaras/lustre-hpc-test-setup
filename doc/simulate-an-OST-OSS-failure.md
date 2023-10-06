# How to deal with an OST/OSS failure

At the HPC Lustre test setup and while all clients have the filesystem with all of the ISTs mounted:
```
UUID                       bytes        Used   Available Use% Mounted on
DIAS-MDT0000_UUID          52.7G        6.5M	   48.0G   1% /lustre/storeA[M
DT:0]
DIAS-OST0001_UUID          87.6G       25.3G	   57.8G  31% /lustre/storeA[O
ST:1]
DIAS-OST0002_UUID          87.6G       25.3G	   57.8G  31% /lustre/storeA[O
ST:2]
DIAS-OST0003_UUID          72.8G        1.2M	   69.1G   1% /lustre/storeA[O
ST:3]

filesystem_summary:	  248.0G       50.6G	  184.6G  22% /lustre/storeA
```


 lets simulate an OST temporary failure. To do that, perform the following:

- 1) Go on one of the OSS servers and shut it down. Say for example that you power down oss1.
  ```
  [root@oss2 ~]# systemctl poweroff
  Connection to 192.168.14.178 closed by remote host.
  Connection to 192.168.14.178 closed.
  ```

- 2)Go back to one of the clients, you should have the lfs df -h command hanging at the point/order of the index of the OST (1):
  ```
  [root@cn2 ~]# lfs df -h
  UUID                       bytes        Used   Available Use% Mounted on
  DIAS-MDT0000_UUID          52.7G        6.5M       48.0G   1% /lustre/storeA[MDT:0]
  ```
  Cursor hangs before displaying the OST. OSTs DIAS-OST0001 and DIAS-OST0002 are gone now.
  At this point, if you also Control+C the hanging lfs df -h operation and try to navigate the filesystem, you might be getting directory contents that were previously cached by the client/MDS. However, all file I/O operations are going to be hanging:
  ```
  [root@cn2 copiediotars]# cd /lustre/storeA/
  [root@cn2 storeA]# ls
  copiediotars  createfilesbench1.sh  createfilesbench2.sh  georgetouch
  [root@cn2 storeA]# cd copiediotars/
  [root@cn2 copiediotars]# ls
  iotest1.tar  iotest2.tar
  [root@cn2 copiediotars]# file iotest1.tar 
  ---->OP HANGS HERE<-----
  ```
  The only way to recover from this with all the filesystem contents intact is to bring the OSS server back online with each and every one of the OSTs it offers.
  In these cases, it also useful to know note the dmesg/journal messages on the MDS server during the failure/outage event:
  ```
  [Fri Oct  6 11:12:25 2023] Lustre: DIAS-OST0001-osc-MDT0000: Connection to DIAS-OST0001 (at 192.168.14.178@tcp) was lost; in progress operations using this service will wait for recovery to complete
  ```
  The above message shows clearly that the MDT has lost connection to DIAS-OST0001, you also get the NID of the OSS server, so this is where you should start the troubleshooting. The Lustre client will also provides equally useful clues in its dmesg/journal messages:
  ```
  [87885.624991] Lustre: DIAS-OST0001-osc-ffff9d6153c91000: Connection to DIAS-OST0001 (at 192.168.14.178@tcp) was lost; in progress operations using this service will wait for recovery to complete
  [87904.056939] Lustre: 3389:0:(client.c:2295:ptlrpc_expire_one_request()) @@@ Request sent has timed out for slow reply: [sent 1696590759/real 1696590759]  req@0000000044314f25 x1778912219544448/t0(0) o400->DIAS-OST0002-osc-ffff9d6153c91000@192.168.14.178@tcp:28/4 lens 224/224 e 0 to 1 dl 1696590766 ref 1 fl Rpc:XNQr/0/ffffffff rc 0/-1 job:''
  [87904.056972] Lustre: DIAS-OST0002-osc-ffff9d6153c91000: Connection to DIAS-OST0002 (at 192.168.14.178@tcp) was lost; in progress operations using this service will wait for recovery to complete
  ```

- 3)Let's recover now. Power back on oss1 and right after the node boots up, ssh login and issue the following:
  ```
  watch 'cat /proc/fs/lustre/obdfilter/DIAS-OST0*/recovery_status  | grep status: '
  status: RECOVERING
  status: RECOVERING
  ```
  This is the recovery process of the OSS, that is trying to bring the OST targets into a consistent state. Eventually, if all is good with the hardware and OST filesystem, thestatus should turn into COMPLETE:
  ```
  [root@oss1 ~]# cat /proc/fs/lustre/obdfilter/DIAS-OST0*/recovery_status  | grep status: 
  status: COMPLETE
  status: COMPLETE
  ```
  From the moment the status is complete, you should have whatever I/O operations were hanging on the clients completing/returning. You should also consult the journal of the MDS, affected OSS and clients to verify that all is good. 
  At the MDS:
  
  ```
  [root@mds1 ~]# dmesg -T | grep Lustre
  ...
  [Fri Oct  6 11:33:01 2023] Lustre: DIAS-OST0002-osc-MDT0000: Connection restored to 192.168.14.178@tcp (at 192.168.14.178@tcp)
  ... 
  ```

  At the affected OSS (oss1):

  ```
  [root@oss1 ~]# dmesg -T | grep Lustre
  [Fri Oct  6 11:32:02 2023] Lustre: Lustre: Build Version: 2.15.3
  [Fri Oct  6 11:32:04 2023] Lustre: DIAS-OST0002: Imperative Recovery enabled, recovery window shrunk from 300-900 down to 150-900
  [Fri Oct  6 11:32:08 2023] Lustre: DIAS-OST0002: Will be in recovery for at least 2:30, or until 2 clients reconnect
  [Fri Oct  6 11:33:01 2023] Lustre: DIAS-OST0002: Recovery over after 0:53, of 2 clients 2 recovered and 0 were evicted.
  [Fri Oct  6 11:33:01 2023] Lustre: DIAS-OST0001: deleting orphan objects from 0x0:23205 to 0x0:23265
  [Fri Oct  6 11:33:01 2023] Lustre: DIAS-OST0002: deleting orphan objects from 0x0:23205 to 0x0:23265
  ```
 
  And finally on the Lustre clients that were accessing the filesystem during the outage, every I/O operation should return now: 
  
  ```
  [root@cn2 copiediotars]# file iotest1.tar 
  iotest1.tar: POSIX tar archive (GNU)
  ```
 
At that point, steps 1 to 3 above demonstrated a very basic recovery, in which an OSS node goes offline (power or OSS server crash outage), causes a filesystem hang on the clients. We showed how to locate the OSS where the OST lies,  power it up/bring it online, run successfully the recovery. This, however is the good scenario. In real life production conditions, things might be more complex.

During the recovery we demonstrated in step 3 above, the OSTs come back onlin and the Lustre file system starts a recovery process to enable clients to reconnect to the OSTs. Lustre servers put a limit on the time they will wait in recovery for clients to reconnect.

During recovery, clients reconnect and replay their requests serially, in the same order they were done originally. Until a client receives a confirmation that a given transaction has been written to stable storage, the client holds on to the transaction, in case it needs to be replayed. Periodically, a progress message prints to the log, stating how_many/expected clients have reconnected. If the recovery is aborted, this log shows how many clients managed to reconnect. When all clients have completed recovery, or if the recovery timeout is reached, the recovery period ends and the OST resumes normal request processing.

If some clients fail to replay their requests during the recovery period, this will not stop the recovery from completing. You may have a situation where the OST recovers, but some clients are not able to participate in recovery (e.g. network problems or client failure), so they are *evicted* and their requests are not replayed. This would result in any operations on the evicted clients failing, including in-progress writes, which would cause cached writes to be lost. This is a normal outcome; the recovery cannot wait indefinitely, or the file system would be hung any time a client failed. The lost transactions are an unfortunate result of the recovery process.

There will be cases where the above recovery process could fail due to storage hardware or other more complex issues causing corruption in the Lustre filesystem. In these cases, e2fsck must be run on the to ensure local OST filesystem consistency. It might also be necessary to  use LFSCK to run a distributed check on the file system to resolve any inconsistencies between the MDTs and OSTs, or among MDTs.

In contrast to the previous recovery process that recovers an OST, an e2fsck operation onan OST must be run with the filesystem stopped. This is what we simulate next. So, in preparation of the e2fsck command:

- 4) Stop all related Lustre I/O activity and umount the filesystem from all clients:
  ```
  (hpcansible) [georgios@cn1 hpcansible]$ ansible -i inventory/ -m shell -a "umount /lustre/storeA" compute
  cn2 | CHANGED | rc=0 >>

  cn1 | CHANGED | rc=0 >>
  ```

- 5) Unmount from all OSSes the OSTs:
  ```
  (hpcansible) [georgios@cn1 hpcansible]$ ansible -i inventory/ -m shell -a "umount /lustre/ost/*" oss1 oss2
  ```

- 6) Unmount the MDT and MGS targets at the MDS:
  ```
  [root@mds1 ~]# umount /lustre/mdt0 
  [root@mds1 ~]# umount /lustre/mgs 
  ```

At that point, the Lustre filesystem is clearly unmounted. So, we can proceed with the e2fsck process now:

- 7) Go to the OSS server (oss1) and do the following:
   - Inspect first the output on OST2: with -fn (do not fix) 
     ```
     [root@oss1 ~]# e2fsck -fn /dev/vg01/LVDIASOST2
     e2fsck 1.47.0-wc4 (22-Jun-2023)
     Pass 1: Checking inodes, blocks, and sizes
     Pass 2: Checking directory structure
     Pass 3: Checking directory connectivity
     Pass 4: Checking reference counts
     Pass 5: Checking group summary information
     DIAS-OST0002: 304/1388160 files (1.3% non-contiguous), 7078064/23592960 blocks
     ```
    
    - If you are sure that this is what you want running it with -fy (fix):
      ```
      [root@oss1 ~]# e2fsck -fy /dev/vg01/LVDIASOST2
      e2fsck 1.47.0-wc4 (22-Jun-2023)
      Pass 1: Checking inodes, blocks, and sizes
      Pass 2: Checking directory structure
      Pass 3: Checking directory connectivity
      Pass 4: Checking reference counts
      Pass 5: Checking group summary information
      DIAS-OST0002: 304/1388160 files (1.3% non-contiguous), 7078064/23592960 blocks
      ```

- 8) At that point if all things pass and fixed, you can bring back the filesystem.


 
 
 







 



 


