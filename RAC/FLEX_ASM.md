### Configure /etc/hosts
```
# Public

10.100.175.121 vnoradev21.hcnet.vn vnoradev21
10.100.175.122 vnoradev22.hcnet.vn vnoradev22
10.100.175.123 vnoradev23.hcnet.vn vnoradev23
10.100.175.124 vnoradev24.hcnet.vn vnoradev24

# Private

192.168.11.2 vnoradev21-priv.hcnet.vn vnoradev21-priv
192.168.11.3 vnoradev22-priv.hcnet.vn vnoradev22-priv
192.168.11.4 vnoradev23-priv.hcnet.vn vnoradev23-priv
192.168.11.5 vnoradev24-priv.hcnet.vn vnoradev24priv

# Virtual

10.100.175.161 ractest-vip1.hcnet.vn ractest-vip1
10.100.175.162 ractest-vip2.hcnet.vn ractest-vip2
10.100.175.163 ractest-vip3.hcnet.vn ractest-vip3
10.100.175.164 ractest-vip4.hcnet.vn ractest-vip4

# SCAN

10.19.175.147 ractest-scan.hcnet.vn ractest-scan
10.19.175.148 ractest-scan.hcnet.vn ractest-scan
10.19.175.149 ractest-scan.hcnet.vn ractest-scan
```


### Configure ssh and precheck
```
su - grid

cd $ORACLE_HOME/deinstall

./sshUserSetup.sh -user oracle -hosts "vnoradev21 vnoradev22 vnoradev23 vnoradev24" -noPromptPassphrase -confirm -advanced

./sshUserSetup.sh -user grid -hosts "vnoradev21 vnoradev22 vnoradev23 vnoradev24" -noPromptPassphrase -confirm -advanced

./runcluvfy.sh stage -pre crsinst -n vnoradev21,vnoradev22,vnoradev23,vnoradev24 -verbose
(Pre-check for cluster services setup was successful.)
```


### Ccreate directory
```
mkdir -p /u01/app/oracle/cfgtoollogs/dbca
mkdir -p /u01/app/oracle/cfgtoollogs/sqlpatch
mkdir -p /u01/app/oracle/cfgtoollogs/netca
mkdir -p /u01/app/oracle/admin
mkdir -p /u01/app/oracle/audit
mkdir -p /u01/app/oraInventory

chown -R oracle:oinstall /u01/app/oracle
chown -R 775 /u01/app/oracle
chown -R grid:oinstall /u01/app/oraInventory
chmod 775 /u01/app/oraInventory
```


### Create response file
```
###############################################################################
## Copyright(c) Oracle Corporation 1998,2019. All rights reserved.           ##
##                                                                           ##
## Specify values for the variables listed below to customize                ##
## your installation.                                                        ##
##                                                                           ##
## Each variable is associated with a comment. The comment                   ##
## can help to populate the variables with the appropriate                   ##
## values.                                                                   ##
##                                                                           ##
## IMPORTANT NOTE: This file contains plain text passwords and               ##
## should be secured to have read permission only by oracle user             ##
## or db administrator who owns this installation.                           ##
##                                                                           ##
###############################################################################

#------------------------------------------------------------------------------
# Do not change the following system generated value.
#------------------------------------------------------------------------------
oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v19.0.0

INVENTORY_LOCATION=/u01/app/oraInventory
oracle.install.option=CRS_CONFIG
ORACLE_BASE=/u01/app/grid
ORACLE_HOME=/u01/app/19.0.0/grid
oracle.install.asm.OSDBA=asmdba
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin
oracle.install.crs.config.scanType=LOCAL_SCAN
oracle.install.crs.config.SCANClientDataFile=
oracle.install.crs.config.gpnp.scanName=ractest-scan
oracle.install.crs.config.gpnp.scanPort=1521


################################################################################
#                                                                              #
#                           SECTION D - CLUSTER & GNS                         #
#                                                                              #
################################################################################

oracle.install.crs.config.ClusterConfiguration=STANDALONE
oracle.install.crs.config.configureAsExtendedCluster=false
oracle.install.crs.config.memberClusterManifestFile=
oracle.install.crs.config.clusterName=ractest
oracle.install.crs.config.gpnp.configureGNS=false
oracle.install.crs.config.autoConfigureClusterNodeVIP=false
oracle.install.crs.config.gpnp.gnsOption=
oracle.install.crs.config.gpnp.gnsClientDataFile=

oracle.install.crs.config.gpnp.gnsSubDomain=
oracle.install.crs.config.gpnp.gnsVIPAddress=

oracle.install.crs.config.sites=


oracle.install.crs.config.clusterNodes=vnoradev21.hcnet.vn:ractest-vip1.hcnet.vn,vnoradev22.hcnet.vn:ractest-vip2.hcnet.vn,vnoradev23.hcnet.vn:ractest-vip3.hcnet.vn,vnoradev24.hcnet.vn:ractest-vip4.hcnet.vn


oracle.install.crs.config.networkInterfaceList=eth0:10.100.175.0:1,eth1:192.168.11.0:5

oracle.install.crs.configureGIMR=false
oracle.install.asm.configureGIMRDataDG=false

################################################################################
#                                                                              #
#                              SECTION E - STORAGE                             #
#                                                                              #
################################################################################

oracle.install.crs.config.storageOption=FLEX_ASM_STORAGE
oracle.install.crs.config.sharedFileSystemStorage.votingDiskLocations=
oracle.install.crs.config.sharedFileSystemStorage.ocrLocations=

################################################################################
#                                                                              #
#                               SECTION F - IPMI                               #
#                                                                              #
################################################################################


oracle.install.crs.config.useIPMI=false
oracle.install.crs.config.ipmi.bmcUsername=
oracle.install.crs.config.ipmi.bmcPassword=

oracle.install.asm.SYSASMPassword=Password1
oracle.install.asm.diskGroup.name=OCR

oracle.install.asm.diskGroup.redundancy=NORMAL
oracle.install.asm.diskGroup.AUSize=4
oracle.install.asm.diskGroup.FailureGroups=

oracle.install.asm.diskGroup.disksWithFailureGroupNames=

oracle.install.asm.diskGroup.disks=/dev/oracleasm/disks/OCR01,/dev/oracleasm/disks/OCR02,/dev/oracleasm/disks/OCR03
oracle.install.asm.diskGroup.quorumFailureGroupNames=

oracle.install.asm.diskGroup.diskDiscoveryString=/dev/oracleasm/disks/*
oracle.install.asm.monitorPassword=Password1
oracle.install.asm.gimrDG.name=

oracle.install.asm.gimrDG.redundancy=
oracle.install.asm.gimrDG.AUSize=1
oracle.install.asm.gimrDG.FailureGroups=
oracle.install.asm.gimrDG.disksWithFailureGroupNames=
oracle.install.asm.gimrDG.disks=
oracle.install.asm.gimrDG.quorumFailureGroupNames=
oracle.install.asm.configureAFD=false
oracle.install.crs.configureRHPS=false
oracle.install.crs.config.ignoreDownNodes=false
oracle.install.config.managementOption=NONE

oracle.install.config.omsHost=
oracle.install.config.omsPort=0
oracle.install.config.emAdminUser=
oracle.install.config.emAdminPassword=
oracle.install.crs.rootconfig.executeRootScript=false
oracle.install.crs.rootconfig.configMethod=
oracle.install.crs.rootconfig.sudoPath=
oracle.install.crs.rootconfig.sudoUserName=

oracle.install.crs.config.batchinfo=
oracle.install.crs.app.applicationAddress=
oracle.install.crs.deleteNode.nodes=
```



### Run precheck
```
su - grid
cd $ORACLE_HOME
./runcluvfy.sh stage -pre crsinst -responseFile /u01/stage/rsp/grid.rsp -verbose
```

### install grid
```
su - grid
cd $ORACLE_HOME
./gridSetup.sh -responseFile /u01/stage/rsp/grid.rsp -silent
```


### Run post script
```
as root:
/u01/app/oraInventory/orainstRoot.sh
/u01/app/19.0.0/grid/root.sh
```

### Create diskgroups
```
#!/bin/bash

/u01/app/19.0.0/grid/bin/asmca -silent -createDiskGroup \
       -diskGroupName DATA \
                     -disk '/dev/oracleasm/disks/DATA01' \
					 -disk '/dev/oracleasm/disks/DATA02' \
        -redundancy external \
        -au_size 4 \
        -compatible.rdbms '19.0.0.0.0' \
        -compatible.asm '19.0.0.0.0' \
		
#!/bin/bash

/u01/app/19.0.0/grid/bin/asmca -silent -createDiskGroup \
       -diskGroupName FRA \
                     -disk '/dev/oracleasm/disks/FRA01' \
        -redundancy external \
        -au_size 4 \
        -compatible.rdbms '19.0.0.0.0' \
        -compatible.asm '19.0.0.0.0' \
		
#!/bin/bash

/u01/app/19.0.0/grid/bin/asmca -silent -createDiskGroup \
       -diskGroupName REDO \
                     -disk '/dev/oracleasm/disks/REDO01' \
        -redundancy external \
        -au_size 4 \
        -compatible.rdbms '19.0.0.0.0' \
        -compatible.asm '19.0.0.0.0' \
		
		
#!/bin/bash

/u01/app/19.0.0/grid/bin/asmca -silent -createDiskGroup \
       -diskGroupName TEMP \
                     -disk '/dev/oracleasm/disks/TEMP01' \
        -redundancy external \
        -au_size 4 \
        -compatible.rdbms '19.0.0.0.0' \
        -compatible.asm '19.0.0.0.0' \
```
