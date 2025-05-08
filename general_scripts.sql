--1/ Tablespace
SELECT tablespace_name, contents,
       max_size_mb, -- including autoextent
       allocated_mb, -- already allocated by datafiles
       used_mb,
       (max_size_mb-used_mb)free_mb,
       round(used_mb / max_size_mb * 100, 2) percent_used
FROM   (SELECT tablespace_name, contents, max_size_mb, allocated_mb, (allocated_mb - free_mb) used_mb
        FROM   (SELECT t.tablespace_name, t.contents,
                       (SELECT round(SUM(decode(autoextensible, 'YES', maxbytes, bytes)) / 1024 / 1024, 2)
                        FROM   dba_data_files f
                        WHERE  f.tablespace_name = t.tablespace_name) max_size_mb,
                       (SELECT SUM(bytes) / 1024 / 1024 bytes
                        FROM   dba_data_files f
                        WHERE  t.tablespace_name = f.tablespace_name) allocated_mb,
                       (SELECT SUM(bytes) / 1024 / 1024
                        FROM   sys.dba_free_space
                        WHERE  tablespace_name = t.tablespace_name) free_mb
                FROM   dba_tablespaces t
                WHERE  t.contents in ('PERMANENT','UNDO')) t
        UNION
        SELECT t.tablespace_name, t.contents,
               (SELECT round(SUM(decode(autoextensible, 'YES', maxbytes, bytes)) / 1024 / 1024, 2)
                FROM   dba_temp_files f
                WHERE  f.tablespace_name = t.tablespace_name) max_size_mb,
               (SELECT SUM(f.bytes) / 1024 / 1024
                FROM   dba_temp_files f
                WHERE  f.tablespace_name = t.tablespace_name) allocated_mb,
               (SELECT nvl(SUM(a.used_blocks * d.block_size) / 1024 / 1024, 0)
                FROM   v$sort_segment a,
                      (SELECT b.name, c.block_size, round(SUM(c.bytes) / 1024 / 1024, 2) mb_total
                        FROM   v$tablespace b, v$tempfile   c
                        WHERE  b.ts# = c.ts#
                        GROUP  BY b.name, c.block_size) d
                WHERE  a.tablespace_name = d.name
                AND    d.name = t.tablespace_name) used_mb
        FROM   dba_tablespaces t
        WHERE  t.contents = 'TEMPORARY');
              
--2/ Datafiles 
/*SELECT file_name, tablespace_name, ROUND(bytes/1024000) MB 
FROM dba_data_files 
ORDER BY 1;*/

SELECT file_id,file_name,tablespace_name,ROUND(b.bytes/1024000) CREATION_TIME,BLOCK_SIZE,a.STATUS,ENABLED 
FROM v$datafile a,dba_data_files b 
WHERE a.FILE#=b.FILE_ID 
ORDER BY 3,1;    

--3/ ASM DISKGROP
SELECT name
, round(b.OS_GB) "Presented (GB)"
, round(a.total_mb / 1024) "Allocated (GB)"
, round(a.free_mb / 1024) "Free (GB)"
, a.REQUIRED_MIRROR_FREE_MB / 1024 "Mirror (GB)"
, Nvl(Round(a.USABLE_FILE_MB / 1024),1) "Useable (GB)"
,CASE a.TYPE
  WHEN 'EXTERN' THEN Round((a.total_mb - a.free_mb) * 100 / a.total_mb)
  WHEN 'NORMAL' THEN Round(((( a.total_mb-a.REQUIRED_MIRROR_FREE_MB ) / 2 ) - a.USABLE_FILE_MB ) / (( a.total_mb-a.REQUIRED_MIRROR_FREE_MB ) / 2 ) * 100)
END "% Used"
,CASE a.TYPE
  WHEN 'EXTERN' THEN Nvl(Round(a.free_mb / a.total_mb * 100),1)
  WHEN 'NORMAL' THEN Round(((a.free_mb - a.REQUIRED_MIRROR_FREE_MB)/2) / ((a.total_mb - a.REQUIRED_MIRROR_FREE_MB)/2)  * 100)
END "% Free"
, a.TYPE "Redundancy", a.allocation_unit_size/1024/1024 "AU_size (MB)"
FROM v$asm_diskgroup a
,(SELECT dg.name group_name, SUM(d.os_mb)/1024 OS_GB FROM V$ASM_DISKGROUP dg, V$ASM_DISK d WHERE dg.group_number = d.group_number group by dg.name) b
where a.NAME=b.group_name
ORDER BY 8;


--4/ ASM DISK
select ad.NAME, ad.PATH, ad.OS_MB, ad.TOTAL_MB, ad.FREE_MB
, Round((ad.TOTAL_MB - ad.FREE_MB) * 100 / ad.TOTAL_MB) "% Used"
, Nvl(Round(ad.FREE_MB / ad.TOTAL_MB * 100),1) "% Free"
, adg.NAME DISKGROUP_NAME, adg.STATE
from v$asm_disk ad, v$asm_diskgroup adg
where ad.GROUP_NUMBER = adg.GROUP_NUMBER
and ad.MOUNT_STATUS <> 'CLOSED'
order by 6 desc;


-- 5/  List ASM disk in a DG
select concat('+'||gname, sys_connect_by_path(aname, '/')) full_alias_path, 
       system_created, alias_directory, file_type
from ( select b.name gname, a.parent_index pindex, a.name aname, 
              a.reference_index rindex , a.system_created, a.alias_directory,
              c.type file_type
       from v$asm_alias a, v$asm_diskgroup b, v$asm_file c
       where a.group_number = b.group_number
             and a.group_number = c.group_number(+)
             and a.file_number = c.file_number(+)
             and a.file_incarnation = c.incarnation(+)
     )
start with (mod(pindex, power(2, 24))) = 0
            and rindex in 
                ( select a.reference_index
                  from gv$asm_alias a, gv$asm_diskgroup b
                  where a.group_number = b.group_number
                        and (mod(a.parent_index, power(2, 24))) = 0
                       -- and a.name = '&DATABASENAME'
                )
connect by prior rindex = pindex;

-- 6/ Find Out Invalid Database Objects
SELECT  OWNER, OBJECT_NAME, OBJECT_TYPE, STATUS 
FROM    DBA_OBJECTS 
WHERE   STATUS = 'INVALID' 
ORDER BY OWNER, OBJECT_TYPE, OBJECT_NAME; 
--compile errors : execute SQL> @$ORACLE_HOME/rdbms/admin/utlrp.sql
----SELECT * FROM   ALL_ERRORS WHERE  OWNER = 'DCAL';

SELECT 'dba_indexes', index_type||' index '||owner||'.'||index_name||' of '||table_owner||'.'||table_name||' is '||status
FROM dba_indexes
WHERE status <> 'VALID' AND status <> 'N/A';
--ALTER INDEX SYS.IDX_T_LOGON_SNAP REBUILD ONLINE;
          

SELECT 'dba_ind_partitions', partition_name||' of '||index_owner||'.'||index_name||' is '||status
FROM dba_ind_partitions
WHERE status <> 'USABLE' AND status <> 'N/A';

SELECT 'dba_ind_subpartitions', subpartition_name||' of '||partition_name||' of '||index_owner||'.'||index_name||' is '||status
FROM dba_ind_subpartitions
WHERE status <> 'USABLE' AND status <> 'N/A';

SELECT 'dba_registry', 'SCHEMA.'||comp_name||'-'||version||' is '||status
FROM dba_registry
WHERE status <> 'VALID' AND status <> 'OPTION OFF';

SELECT O.object_type, O.owner, O.object_name, O.status
FROM dba_objects O
LEFT OUTER JOIN DBA_MVIEW_refresh_times V ON (O.object_name = V.NAME AND O.owner = V.owner)
LEFT JOIN dba_proxies e ON ( O.owner = e.client)
WHERE STATUS = 'INVALID';


-- 7/ The following query displays per day the volume in MBytes of archived logs generated, deleted and of those that haven't yet been deleted by RMAN.
SELECT SUM_ARCH.DAY,
         SUM_ARCH.GENERATED_MB,
         SUM_ARCH_DEL.DELETED_MB,
         SUM_ARCH.GENERATED_MB - SUM_ARCH_DEL.DELETED_MB "REMAINING_MB"
    FROM (  SELECT TO_CHAR (COMPLETION_TIME, 'DD/MM/YYYY') DAY,
                   SUM (ROUND ( (blocks * block_size) / (1024 * 1024), 2))
                      GENERATED_MB
              FROM V$ARCHIVED_LOG
             WHERE ARCHIVED = 'YES'
          GROUP BY TO_CHAR (COMPLETION_TIME, 'DD/MM/YYYY')) SUM_ARCH,
         (  SELECT TO_CHAR (COMPLETION_TIME, 'DD/MM/YYYY') DAY,
                   SUM (ROUND ( (blocks * block_size) / (1024 * 1024), 2))
                      DELETED_MB
              FROM V$ARCHIVED_LOG
             WHERE ARCHIVED = 'YES' AND DELETED = 'YES'
          GROUP BY TO_CHAR (COMPLETION_TIME, 'DD/MM/YYYY')) SUM_ARCH_DEL
   WHERE SUM_ARCH.DAY = SUM_ARCH_DEL.DAY(+)
ORDER BY TO_DATE (DAY, 'DD/MM/YYYY') DESC;

-- 8/ FRA
SELECT * FROM V$FLASH_RECOVERY_AREA_USAGE;

-- 9/ Achive dest
select * from v$archive_dest where status='VALID';

-- 10/ RMAN status
SELECT OPERATION, STATUS, ROW_TYPE, OBJECT_TYPE, MBYTES_PROCESSED, START_TIME, END_TIME from V$RMAN_STATUS where START_TIME >= sysdate -5 order by START_TIME DESC;

-- 11/ RMAN detail
SELECT * from v$rman_backup_job_details a where a.START_TIME > sysdate -5 order by START_TIME DESC;

-- 12/ Segment MLOG
select * from dba_segments where segment_name like 'MLOG%' order by bytes desc;

/*-- 13/ Schema Quota
select * from dba_ts_quotas order by max_bytes desc, bytes desc;
*/
-- 14/ Role DBA
select a.username, a.user_id, a.account_status, a.default_tablespace, b.GRANTED_ROLE from dba_users a left join dba_role_privs b on a.username=b.GRANTEE
where a.default_tablespace not in ('SYSAUX') and a.profile not in ('SYSTEM') and b.GRANTED_ROLE='DBA' and a.profile <> 'USERSDBA'
and a.username not in ('APEX_PUBLIC_USER','DISCOVERY','MDDATA','MGMT_VIEW','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','XS$NULL') order by a.username
;

-- Users
select a.USERNAME,a.DEFAULT_TABLESPACE,a.ACCOUNT_STATUS,a.LOCK_DATE,a.EXPIRY_DATE,a.PROFILE
from dba_users a where a.PROFILE not in ('SYSTEM','DEFAULT','MONITORING')
order by 6,1;

-- 15/ Job running but no sessioin
select * from dba_scheduler_running_jobs where session_id is null;

-- 16/ Job failed
select * from dba_scheduler_job_run_details a
where a.LOG_DATE > sysdate -15
and a.STATUS<>'SUCCEEDED'
--and a.OWNER=''
order by a.LOG_DATE desc;

-- job purge
select * from iconvoice1.g_purge_state union all
select * from iconvoice2.g_purge_state union all
select * from iconvoice3.g_purge_state union all
select * from iconvoice4.g_purge_state union all
select * from iconvoice5.g_purge_state union all
select * from iconvoice6.g_purge_state union all
select * from iconvoice7.g_purge_state union all
select * from iconvoice8.g_purge_state union all
select * from icongir1.g_purge_state union all
select * from icongir2.g_purge_state union all
select * from iconocs1.g_purge_state union all
select * from iconocs2.g_purge_state union all
--select * from iconocs3.g_purge_state union all
--select * from iconocs4.g_purge_state union all
select * from iconocs5.g_purge_state union all
select * from iconocs6.g_purge_state
;
/*
PSTATE
--------------------------------------------------
Started



begin  
       DBMS_SCHEDULER.stop_job(job_name =>'iconvoice2.PURGEHISTIDB',force => true);  
end; 

BEGIN
    EXECUTE IMMEDIATE 'TRUNCATE TABLE iconvoice2.g_Purge_State';
	  EXECUTE IMMEDIATE 'TRUNCATE TABLE iconvoice2.gsys_p_mark';
END;
*/

-- job dbadmin
select * from dbadmin.dbaoperation_output a where a.created > sysdate -15 order by a.id desc;

-- 17/ Job List - 19 jobs
select b.owner, b.job_name, b.JOB_CREATOR, b.JOB_ACTION, b.start_date
, b.REPEAT_INTERVAL, b.run_count, b.last_start_date, b.next_run_date, b.comments
from dba_scheduler_jobs b 
where b.owner not in ('SYS','EXFSYS','ORACLE_OCM')
and b.STATE = 'SCHEDULED'
order by 1 desc;

-- 18/ Count job (DBAdmin: 5, 2->12: 1, IVR: 3)
select b.owner,count(*)
from dba_scheduler_jobs b 
where b.owner not in ('SYS','EXFSYS','ORACLE_OCM')
and b.STATE = 'SCHEDULED'
group by b.owner
order by 1;

-- 19/ Job pugre log --43job; DBADMIN=9; GVP=2; ICONOCS_=2;ICONVOICE_=16;IVR=6;ORACLE_OCM=8
select * from dba_scheduler_job_run_details a
where (to_char(a.LOG_DATE,'dd/mm/yyyy') = to_char(sysdate-1,'dd/mm/yyyy')or to_char(a.LOG_DATE,'dd/mm/yyyy') = to_char(sysdate,'dd/mm/yyyy'))
and a.OWNER not in ('SYS','EXFSYS')
order by a.LOG_DATE,a.owner;

-- 20/ SGA
select * from gv$sgastat where pool = 'shared pool' and (name in ('free memory', 'sql area', 'library cache', 'miscellaneous', 'row cache', 'KGH: NO ACCESS') ); 

-- 21/ Segment MLOG or Object deleted
/*select * from dba_segments where segment_name like 'MLOG%' order by bytes desc;*/
select * from dba_segments where owner <> 'SYS' and segment_name like 'BIN%' order by bytes desc;

-- 22/ parameter
select * from v$parameter2 a
where a.NAME in ('active_instance_count','archive_lag_target','audit_file_dest','background_dump_dest','cluster_database','cluster_database_ instances'
                ,'cluster_interconnects ','compatible','control_files ','control_management_pack_access','core_dump_dest','db_block_size ','db_cache_size'
                ,'db_create_file_dest','db_domain','db_files','db_name','db_recovery_file_dest','db_unique_name','diagnostic_dest','dml_locks'
                ,'gc_files_to_locks','global_names','instance_name','instance_number','java_pool_size','large_pool_size','license_max_users'
                ,'local_listener','max_commit_ propagation_delay ','memory_max_target','memory_target','open_cursors','parallel_execution_ message_size'
                ,'parallel_max_servers','parallel_servers_target','pga_aggregate_target','processes','remote_login_passwordfile','rollback_ segments'
                ,'row_locking ','service_names','sessions','sga_max_size','sga_target','shared_pool_size','smtp_out_server','spfile ','sql_trace','db_block_size'
                ,'streams_pool_size','thread','trace_enabled','transactions','undo_management','undo_retention','undo_tablespace','user_dump_dest','open_cursors'
                ,'db_file_multiblock_read_count','fal_client','fal_server','log_archive_config','archive_lag_target','job_queue_processes','aq_tm_processes')
;
select * from NLS_DATABASE_PARAMETERS;

--23/ flashback
select DBID,NAME,LOG_MODE,OPEN_MODE,DATABASE_ROLE,d.FORCE_LOGGING,d.PLATFORM_NAME
, PROTECTION_MODE,DATAGUARD_BROKER,FLASHBACK_ON 
from v$database d;

--24/ v$instance;
select * from v$instance;

-- 25/ config
SELECT * FROM sys.props$;

-- 26/ count call_list;
select count(*) from outcontact.cl_lcs;
select count(*) from outcontact.cl_sas_02;

-- 27/ Redo
select * from v$logfile;
select * from v$log;
select * from v$standby_log; 

-- 28/ Track Redo generation by day:
select trunc(completion_time) logdate, count(*) logswitch, round((sum(blocks*block_size)/1024/1024)) "REDO PER DAY (MB)" from v$archived_log group by trunc(completion_time) order by 1 desc;

-- 29/ Track Logon time of DB user and OS user:
Select to_char(logon_time,'dd/mm/yyyy hh24:mi:ss'),osuser,status,schemaname,machine,program,module from gv$session where type !='BACKGROUND' order by 1 desc;

-- 30/ Check corrupt data:
SELECT * from gv$database_block_corruption; 

-- 31/ All Users
select * from DBA_USERS order by created;
 
--32/ tracking block for RMAN backup incremental
SELECT status, filename FROM V$BLOCK_CHANGE_TRACKING;
SELECT * FROM gv$sgastat WHERE name LIKE '%CTWR%';
SELECT inst_id, sid, program, status FROM gv$session WHERE program LIKE '%CTWR%';

/*
-- 30/ Display tablespace level database growth per week (Last Seven 7 Days)
SELECT b.tsname tablespace_name,  --tablespace wise average size increase for last 7 days exclude today  
         MAX (b.used_size_mb) cur_used_size_mb,
         ROUND (AVG (inc_used_size_mb), 2) avg_increas_mb
    FROM (SELECT a.days, --Tablespace and day wise tablespace size increase
                 a.tsname,used_size_mb,used_size_mb
                 - LAG (used_size_mb, 1) --LAG function is used to access data from a previous row
                    OVER (PARTITION BY a.tsname ORDER BY a.tsname, a.days) inc_used_size_mb
       FROM(  SELECT TO_CHAR (snp.begin_interval_time, 'MM-DD-YYYY') days, --Upto date Tablespace used
                           ts.tsname,MAX (ROUND ((usgtb.tablespace_usedsize * dt.block_size) / (1024 * 1024), 2)) used_size_mb
                      FROM dba_hist_tbspc_space_usage usgtb, --Display historical tablespace usage statistics
                           dba_hist_tablespace_stat ts,  --Display tablespace information from the control file
                           dba_hist_snapshot snp, --Display Information about the snapshots in the Workload Repository
                           dba_tablespaces dt --Describes the tablespaces accessible to the current user
                     WHERE     usgtb.tablespace_id = ts.ts#
                           AND usgtb.snap_id = snp.snap_id
                           AND ts.tsname = dt.tablespace_name
                           AND (snp.begin_interval_time) BETWEEN  (SYSDATE -8) and (SYSDATE ) --Last 7 days information from  dba_hist_snapshot table exclude today 
                  GROUP BY TO_CHAR (snp.begin_interval_time, 'MM-DD-YYYY'),
                           ts.tsname
HAVING TO_CHAR (snp.begin_interval_time, 'MM-DD-YYYY') <> TO_CHAR(TRUNC(SYSDATE),'MM-DD-YYYY')                  
ORDER BY ts.tsname, days ) a) b
GROUP BY b.tsname
ORDER BY b.tsname;

/*
-- Datafile & Tablespace
select a.NAME DATAFILE_NAME,b.NAME TABLESPACE_NAME,a.STATUS, a.ENABLED, a.CHECKPOINT_CHANGE#, a.BYTES
, a.BLOCKS, b.INCLUDED_IN_DATABASE_BACKUP, b.BIGFILE, b.FLASHBACK_ON 
from v$datafile a, v$tablespace b
where a.TS#=b.TS#;


-- All Instance
select * from gv$instance;


-- Job Genesys
select * from dba_scheduler_job_run_details a
where a.OWNER='IVRAPPS'
order by a.LOG_DATE desc
-- 20 rows : 4 DBADMIN, 8 ICONVOICE1->8, 4 IVRAPPS, 4 ORACLE_OCM
select * from dba_scheduler_job_log a
where a.OWNER not like '%SYS'
and to_char(a.LOG_DATE,'dd/mm/yyyy')=to_char(sysdate,'dd/mm/yyyy')
order by a.LOG_DATE desc

*/

--33/ sessions and processes
select * from gv$parameter2 where NAME in ('sessions','processes');
 
SELECT count(*), s.INST_ID, s.USERNAME, s.STATUS, s.CON_ID --, s.paddr
FROM gv$session s LEFT JOIN gv$process p ON s.paddr = p.addr
GROUP BY s.INST_ID, s.USERNAME, s.STATUS, s.CON_ID --, s.paddr
ORDER BY s.INST_ID, count(*) desc;

SELECT RESOURCE_NAME, CURRENT_UTILIZATION, MAX_UTILIZATION, LIMIT_VALUE FROM V$RESOURCE_LIMIT WHERE RESOURCE_NAME IN ( 'sessions', 'processes');

