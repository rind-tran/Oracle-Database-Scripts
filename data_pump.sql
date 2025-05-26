--input: 
SOURCE_IMP_DIR, SCHEMA_NAME, email user, DELI ticket
--objectives: 
import schema 
set job automatically decommision schema after 1 month
change password
email to user


1. import schema 
--prepare
GRANT CREATE ANY DIRECTORY TO DBADMIN;
GRANT CREATE TABLESPACE TO DBADMIN;




-- procedure
DECLARE
v_datapump_handle NUMBER;
v_filename_log varchar2(400);
v_filename_dump varchar2(50);
v_log_id NUMBER;
v_parallel number default 8;  --nonprod = 2; prod = 8
v_status varchar2(500);
v_percent_done number;
v_js ku$_JobStatus;
v_sts ku$_Status;
v_encrypt_pass varchar2(30) := '*****';
v_SOURCE_IMP_DIR VARCHAR2(50) := 'SOURCE_IMP_DIR';
v_olduser VARCHAR2(30) := 'CUSTAPP';
v_newuser VARCHAR2(30) := v_olduser || '_AUDIT';
v_oldtbs VARCHAR2(30) := 'CUSTAPP';
v_newtbs VARCHAR2(30) := v_oldtbs || '_AUDIT';
p_filename_src_imp varchar2(50);

BEGIN
  -- Check if required files is created.
  

  -- Create DIRECTORY
  v_log_id := dbadmin.pkg_dbaoperation_log.f_start('Create directory SOURCE_IMP_DIR');
  EXECUTE IMMEDIATE 'CREATE OR REPLACE DIRECTORY SOURCE_IMP_DIR AS ''/backup/dump''' ;
  dbadmin.pkg_dbaoperation_log.p_output(v_log_id,'OUTPUT','CREATE OR REPLACE DIRECTORY SOURCE_IMP_DIR AS ''/backup/dump''');
  
  v_log_id := dbadmin.pkg_dbaoperation_log.f_start('Create directory LIST_DIR');
  EXECUTE IMMEDIATE 'CREATE or replace DIRECTORY LIST_DIR AS ''/backup/scripts/''' ;
  dbadmin.pkg_dbaoperation_log.p_output(v_log_id,'OUTPUT','CREATE OR REPLACE DIRECTORY SOURCE_IMP_DIR AS ''/backup/scripts/''');
  

    -- Create tablespace
    v_log_id := dbadmin.pkg_dbaoperation_log.f_start('Create tablepsace');
    EXECUTE IMMEDIATE 'CREATE TABLESPACE ' || v_newtbs || ' DATAFILE  ''+ASMDISK'' SIZE 1G AUTOEXTEND ON next 1G maxsize unlimited';
    dbadmin.pkg_dbaoperation_log.p_output(v_log_id,'OUTPUT','CREATE TABLESPACE ' || v_newtbs ||' DATAFILE  ''+ASMDISK'' SIZE 1G AUTOEXTEND ON next 1G maxsize unlimited');
	-- End create tablespace
	
	-- Import schema
	v_log_id := dbadmin.pkg_dbaoperation_log.f_start('DBADMIN.BACKUP DUMP IMPORT');
	BEGIN
      p_filename_src_imp := NULL;
      select FILE_NAME into p_filename_src_imp from (select FILE_NAME from DBADMIN.T_SOURCE_IMP_LIST_FILES_DUMP where INSTR((FILE_NAME),v_olduser)>0 and FILE_NAME like '%_01.dmp' order by LAST_MODIFIED desc) where rownum = 1;
    EXCEPTION
    WHEN NO_DATA_FOUND THEN
      dbadmin.pkg_dbaoperation_log.p_output(v_log_id,'OUTPUT',v_olduser||' will be skipped import, because no dump_filename found.');
    END;
	if p_filename_src_imp is not NULL
	then
      dbadmin.pkg_dbaoperation_log.p_output(v_log_id,'OUTPUT',v_newuser || ' - Import start with filename: ' || p_filename_src_imp );
      select REPLACE(p_filename_src_imp,'01.dmp','%U.dmp') into v_filename_dump from dual;
      select v_newuser || '_import_' || to_char(systimestamp,'YYYYMMDD_HH24MISS') ||'.log' into v_filename_log from dual;
      v_datapump_handle := dbms_datapump.open(operation => 'IMPORT', job_mode => 'SCHEMA', job_name => 'IMPORT_SCHEMA_'||v_olduser);
      dbms_datapump.add_file(  handle => v_datapump_handle ,filename  => v_filename_dump , directory => v_SOURCE_IMP_DIR,filetype  => dbms_datapump.ku$_file_type_dump_file);
      dbms_datapump.add_file(  handle => v_datapump_handle ,filename  => v_filename_log , directory => v_SOURCE_IMP_DIR , filetype  => dbms_datapump.ku$_file_type_log_file);
      dbms_datapump.set_parallel( handle => v_datapump_handle, degree => v_parallel);
      dbms_datapump.set_parameter(handle => v_datapump_handle, name => 'ENCRYPTION_PASSWORD', value  => v_encrypt_pass);
      dbms_datapump.metadata_filter( handle => v_datapump_handle, name => 'SCHEMA_LIST', value  => '''' || v_olduser || '''' );
	  dbms_datapump.metadata_remap( handle => v_datapump_handle, name => 'REMAP_SCHEMA', old_value => v_olduser , value  => v_newuser );
	  dbms_datapump.metadata_remap( handle => v_datapump_handle, name => 'REMAP_TABLESPACE', old_value => v_oldtbs , value  => v_newtbs );
      dbms_datapump.metadata_transform(handle => v_datapump_handle, name => 'DISABLE_ARCHIVE_LOGGING', value => 1);
      dbms_datapump.start_job( handle => v_datapump_handle,cluster_ok => 0);
      v_percent_done := 0;
      v_status := 'UNDEFINED';
      while (v_status != 'COMPLETED') and (v_status != 'STOPPED') loop
        dbms_datapump.get_status(v_datapump_handle,dbms_datapump.ku$_status_job_error + dbms_datapump.ku$_status_job_status + dbms_datapump.ku$_status_wip,-1,v_status,v_sts);
        v_js := v_sts.job_status;
        if v_js.percent_done != v_percent_done
        then
          dbadmin.pkg_dbaoperation_log.p_output(v_log_id,'OUTPUT','*** Job import percent done = ' ||to_char(v_js.percent_done));
          v_percent_done := v_js.percent_done;
        end if;
      end loop;
      dbadmin.pkg_dbaoperation_log.p_output(v_log_id,'OUTPUT',v_newuser || ' - Final import state = ' || v_status);
      dbms_datapump.detach(handle => v_datapump_handle);
	end if;
	-- end import schema
	
	-- end
	




END;
/




2. Create job decommision

-- Prepare
grant create job to dbadmin




DECLARE

BEGIN
  FOR x in (select column_value username from sys.dbms_debug_vc2coll('DUCTH','PHATT'))
  LOOP
    DBMS_SCHEDULER.create_job (job_name     => 'DECOMMISION_' || x.username,
                               job_type     => 'PLSQL_BLOCK',
                               job_action   => q'[BEGIN
                                                    'DROP USER ' || x.username ||' CASCADE';

                                                    'DROP TABLESPACE ' || x.username || ' INCLUDING CONTENTS and datafiles';
    
                                                  END;]',
                               start_date   => TIMESTAMP '2023-08-26 00:00:00 -05:00', -- after 30 days: sysdate + 30
                               enabled      => TRUE);
   
  END LOOP;
   
END;
/


3. Change pwd
DECLARE
v_datapump_handle NUMBER;
v_filename_log varchar2(400);
v_log_id NUMBER;
v_parallel number default 16;  --nonprod = 2; prod = 8
v_status varchar2(500);
v_percent_done number;
v_js ku$_JobStatus;
v_sts ku$_Status;
v_SOURCE_IMP_DIR VARCHAR2(50) := 'SOURCE_IMP_DIR';
BEGIN
  FOR x in (select column_value username from sys.dbms_debug_vc2coll('DUCTH'))
  LOOP
    v_log_id := dbadmin.pkg_dbaoperation_log.f_start('Change password user ' || x.username);
    'ALTER USER ' || x.username || ' IDENTIFIED BY ' || x.username || '_1Audit';
	dbadmin.pkg_dbaoperation_log.p_output(v_log_id,'OUTPUT','Successfully changed password user ' || x.username );
  
   END LOOP;	

END;


4. email to user

--Create ACL for user dbadmin

Begin
DBMS_NETWORK_ACL_ADMIN.APPEND_HOST_ACE(
  host => 'smtp-int.vn.prod',
  ace  =>  xs$ace_type(privilege_list => xs$name_list('connect', 'resolve'),
                       principal_name => 'DBADMIN',
                       principal_type => xs_acl.ptype_db));
End;
/

-- Mail 
DECLARE
v_subj VARCHAR2(200); -- DELI?
v_recipient VARCHAR2(200);
v_content1 VARCHAR2(400);
v_content2 VARCHAR2(20);

begin
-- Generate password
  select replace(dbms_random.string('P', 12), ' ', 'x') into v_content2 from dual;
  v_subj := 'Oracle audit testing';
  v_content1 := 'Information about the database for audit:
				Connection string: HOST=my_host.example.com, SERVICE_NAME=db.example.com
				User: x.username
				Password: Please check in another mail';
  v_recipient := 'duc.tranh5@homecredit.vn';
 
-- Mail 1 
  DBADMIN.sendmail(
    recipient => v_recipient,
    subj      => v_subj,
    mail      => v_content1);

-- Mail 2	
  DBADMIN.sendmail(
    recipient => v_recipient,
    subj      => v_subj,
    mail      => v_content2);
    
end;
