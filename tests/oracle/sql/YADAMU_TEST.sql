set echo on
def LOGDIR = &1
spool &LOGDIR/install/COMPILE_ALL.log APPEND
--
def TERMOUT = &2
--
set TERMOUT &TERMOUT
--
set timing on
set feedback on
set echo on
--
ALTER SESSION SET PLSQL_CCFLAGS = 'DEBUG:TRUE'
/
set serveroutput on
--
spool &LOGDIR/install/YADAMU_TEST.log
--
declare
  TABLE_NOT_FOUND EXCEPTION;
  PRAGMA EXCEPTION_INIT( TABLE_NOT_FOUND , -00942 );
begin
  execute immediate 'drop table "SCHEMA_COMPARE_RESULTS"';
exception
  when TABLE_NOT_FOUND then
    null;
  when others then  
    RAISE;
end;
/
create global temporary table SCHEMA_COMPARE_RESULTS (
  SOURCE_SCHEMA    VARCHAR2(128)
 ,TARGET_SCHEMA    VARCHAR2(128)
 ,TABLE_NAME       VARCHAR2(128)
 ,SOURCE_ROW_COUNT NUMBER
 ,TARGET_ROW_COUNT NUMBER
 ,MISSING_ROWS     NUMBER
 ,EXTRA_ROWS       NUMBER
 ,SQLERRM          VARCHAR2(4000)
) 
ON COMMIT PRESERVE  ROWS
/
create or replace package YADAMU_TEST
AUTHID CURRENT_USER
as
  procedure COMPARE_SCHEMAS(P_SOURCE_SCHEMA VARCHAR2, P_TARGET_SCHEMA VARCHAR2, P_TIMESTAMP_PRECISION NUMBER DEFAULT 9);
end;
/
--
set TERMOUT on
--
show errors
--
set TERMOUT &TERMOUT
--
set define off
--
create or replace package body YADAMU_TEST
as
--
procedure COMPARE_SCHEMAS(P_SOURCE_SCHEMA VARCHAR2, P_TARGET_SCHEMA VARCHAR2, P_TIMESTAMP_PRECISION NUMBER DEFAULT 9)
as
  TABLE_NOT_FOUND EXCEPTION;
  PRAGMA EXCEPTION_INIT( TABLE_NOT_FOUND , -00942 );
    
  V_HASH_METHOD      NUMBER := 0;
  V_TIMESTAMP_LENGTH NUMBER  := 20 + P_TIMESTAMP_PRECISION;
  
  cursor getTableList
  is
  select aat.TABLE_NAME
        ,LISTAGG(
           case 
             when ((V_HASH_METHOD < 0) and DATA_TYPE in ('SDO_GEOMETRY','XMLTYPE','ANYDATA','BLOB','CLOB','NCLOB')) then
    		   NULL
             when ((DATA_TYPE like 'TIMESTAMP(%)') and (DATA_SCALE > P_TIMESTAMP_PRECISION)) then
               'substr(to_char("' || COLUMN_NAME || '",''YYYY-MM-DD"T"HH24:MI:SS.FF9''),1,' || V_TIMESTAMP_LENGTH || ') "' || COLUMN_NAME || '"'
             when DATA_TYPE = 'BFILE' then
	           'case when "' || COLUMN_NAME || '" is NULL then NULL else OBJECT_SERIALIZATION.SERIALIZE_BFILE("' || COLUMN_NAME || '") end' 
		     when (DATA_TYPE = 'SDO_GEOMETRY') then
               'case when "' || COLUMN_NAME || '" is NULL then NULL else dbms_crypto.HASH(SDO_UTIL.FROMWKTGEOMETRY("' || COLUMN_NAME || '"),' || V_HASH_METHOD || ') end'
             when DATA_TYPE = 'XMLTYPE' then
		       'case when "' || COLUMN_NAME || '" is NULL then NULL else dbms_crypto.HASH(XMLSERIALIZE(CONTENT "' || COLUMN_NAME || '" as  BLOB ENCODING ''UTF-8''),' || V_HASH_METHOD || ') end' 
		     when DATA_TYPE = 'ANYDATA' then
		       'case when "' || COLUMN_NAME || '" is NULL then NULL else dbms_crypto.HASH(OBJECT_SERIALIZATION.SERIALIZE_ANYDATA("' || COLUMN_NAME || '"),' || V_HASH_METHOD || ') end' 
		     when DATA_TYPE in ('BLOB')  then
   		       'case when "' || COLUMN_NAME || '" is NULL then NULL else dbms_crypto.HASH("' || COLUMN_NAME || '",' || V_HASH_METHOD || ') end'
			 when DATA_TYPE in ('CLOB','NCLOB')  then
		        'case when "' || COLUMN_NAME || '" is NULL then NULL when DBMS_LOB.GETLENGTH("' || COLUMN_NAME || '") = 0 then NULL else dbms_crypto.HASH("' || COLUMN_NAME || '",' || V_HASH_METHOD || ') end'
             else
	     	   '"' || COLUMN_NAME || '"'
		   end,
		',') 
		 WITHIN GROUP (ORDER BY INTERNAL_COLUMN_ID, COLUMN_NAME) COLUMN_LIST
        ,LISTAGG(
           case 
             when ((V_HASH_METHOD < 0) and DATA_TYPE in ('"MDSYS"."SDO_GEOMETRY"','XMLTYPE','BLOB','CLOB','NCLOB')) then
    		   '"' || COLUMN_NAME || '"'
             else 
               NULL
		   end,
		',') 
		 WITHIN GROUP (ORDER BY INTERNAL_COLUMN_ID, COLUMN_NAME) LOB_COLUMN_LIST
  from ALL_ALL_TABLES aat
       inner join ALL_TAB_COLS atc
	           on atc.OWNER = aat.OWNER
	          and atc.TABLE_NAME = aat.TABLE_NAME
       left outer join ALL_TYPES at
	                on at.TYPE_NAME = atc.DATA_TYPE
                   and at.OWNER = atc.DATA_TYPE_OWNER
	   left outer join ALL_MVIEWS amv
		            on amv.OWNER = aat.OWNER
		           and amv.MVIEW_NAME = aat.TABLE_NAME    
       $IF DBMS_DB_VERSION.VER_LE_11_2 $THEN
       left outer join ALL_EXTERNAL_TABLES axt
	                on axt.OWNER = aat.OWNER
	               and axt.TABLE_NAME = aat.TABLE_NAME
       $END
 where aat.STATUS = 'VALID'
   and aat.DROPPED = 'NO'
   and aat.TEMPORARY = 'N'
$IF DBMS_DB_VERSION.VER_LE_11_2 $THEN
   and axt.TYPE_NAME is NULL
$ELSE
   and aat.EXTERNAL = 'NO'
$END
   and aat.NESTED = 'NO'
   and aat.SECONDARY = 'N'
   and (aat.IOT_TYPE is NULL or aat.IOT_TYPE = 'IOT')
   and (
	    ((aat.TABLE_TYPE is NULL) and ((atc.HIDDEN_COLUMN = 'NO') and ((atc.VIRTUAL_COLUMN = 'NO') or ((atc.VIRTUAL_COLUMN = 'YES') and (atc.DATA_TYPE = 'XMLTYPE')))))
        or
	    ((aat.TABLE_TYPE is not NULL) and (COLUMN_NAME in ('SYS_NC_OID$','SYS_NC_ROWINFO$')))
	    or
		((aat.TABLE_TYPE = 'XMLTYPE') and (COLUMN_NAME in ('ACLOID', 'OWNERID')))
       )
	and aat.OWNER = P_SOURCE_SCHEMA
    and ((TYPECODE is NULL) or (at.TYPE_NAME = 'XMLTYPE'))
  group by aat.TABLE_NAME;
  
  V_SQL_STATEMENT     CLOB;
  P_SOURCE_COUNT      NUMBER := 0;
  P_TARGET_COUNT      NUMBER := 0;
  V_SQLERRM           VARCHAR2(4000);
begin
  
  -- Use EXECUTE IMMEDIATE to get the HASH Method Code so we do not get a compile error if accesss has not been granted to DBMS_CRYPTO

  begin
    --
    $IF JSON_FEATURE_DETECTION.PARSING_SUPPORTED $THEN
    --
    execute immediate 'begin :1 := DBMS_CRYPTO.HASH_SH256; end;'  using OUT V_HASH_METHOD;
    --
    $ELSE
    --
    execute immediate 'begin :1 := DBMS_CRYPTO.HASH_MD5; end;'  using OUT  V_HASH_METHOD;
    --
    $END
    --
  exception
    when OTHERS then
      V_HASH_METHOD := -1;
  end;

  begin
    execute immediate 'truncate table "SCHEMA_COMPARE_RESULTS"';
  exception
    when TABLE_NOT_FOUND then
      null;
    when others then  
      RAISE;
  end;

   
  for t in getTableList loop

    if ((V_HASH_METHOD < 0) and (t.LOB_COLUMN_LIST is not NULL)) then
      V_SQLERRM := '''Warning : Package DBMS_CRYPTO is required to compare the following columns: ' || t.LOB_COLUMN_LIST || '.''';
    else
      -- Not a TYPO: NULL is a string in this case.
      V_SQLERRM := 'NULL';
    end if;

    V_SQL_STATEMENT := 'insert into SCHEMA_COMPARE_RESULTS ' || YADAMU_UTILITIES.C_NEWLINE
                    || ' select ''' || P_SOURCE_SCHEMA  || ''' ' || YADAMU_UTILITIES.C_NEWLINE
                    || '       ,''' || P_TARGET_SCHEMA  || ''' ' || YADAMU_UTILITIES.C_NEWLINE
                    || '       ,'''  || t.TABLE_NAME || ''' ' || YADAMU_UTILITIES.C_NEWLINE
                    || '       ,(select count(*) from "' || P_SOURCE_SCHEMA  || '"."' || t.TABLE_NAME || '")'  || YADAMU_UTILITIES.C_NEWLINE
                    || '       ,(select count(*) from "' || P_TARGET_SCHEMA  || '"."' || t.TABLE_NAME || '")'  || YADAMU_UTILITIES.C_NEWLINE
                    || '       ,(select count(*) from (SELECT ' || t.COLUMN_LIST || ' from "' || P_SOURCE_SCHEMA  || '"."' || t.TABLE_NAME || '" MINUS SELECT ' || t.COLUMN_LIST || ' from  "' || P_TARGET_SCHEMA  || '"."' || t.TABLE_NAME || '")) '  || YADAMU_UTILITIES.C_NEWLINE
                    || '       ,(select count(*) from (SELECT ' || t.COLUMN_LIST || ' from "' || P_TARGET_SCHEMA  || '"."' || t.TABLE_NAME || '" MINUS SELECT ' || t.COLUMN_LIST || ' from  "' || P_SOURCE_SCHEMA  || '"."' || t.TABLE_NAME || '")) '  || YADAMU_UTILITIES.C_NEWLINE
                    || '       ,' || V_SQLERRM  || YADAMU_UTILITIES.C_NEWLINE
					|| '  from dual';
                    
	begin
	  EXECUTE IMMEDIATE V_SQL_STATEMENT;
    exception 
      when OTHERS then
        V_SQLERRM := SQLERRM;					  
        begin 
          V_SQL_STATEMENT := 'select count(*) from "' || P_SOURCE_SCHEMA  || '"."' || t.TABLE_NAME || '"';
          execute immediate V_SQL_STATEMENT into P_SOURCE_COUNT;
        exception
          when others then
            V_SQLERRM := SQLERRM;					  
            P_SOURCE_COUNT := -1;
        end;
        begin 
          V_SQL_STATEMENT := 'select count(*) from "' || P_TARGET_SCHEMA  || '"."' || t.TABLE_NAME || '"';
          execute immediate V_SQL_STATEMENT into P_TARGET_COUNT;
        exception
          when others then
            V_SQLERRM := SQLERRM;            
            $IF DBMS_DB_VERSION.VER_LE_11_2 $THEN
            -- Check if the ORA-xxxxx message appears twice in SQLERRM.
            if (INSTR(SUBSTR(V_SQLERRM,11),SUBSTR(V_SQLERRM,1,10)) > 0) then
              V_SQLERRM := SUBSTR(V_SQLERRM,1,INSTR(SUBSTR(V_SQLERRM,11),SUBSTR(V_SQLERRM,1,10))+8);         
            end if;
            $END
            P_TARGET_COUNT := -1;
        end;
        V_SQL_STATEMENT := 'insert into SCHEMA_COMPARE_RESULTS values (:1,:2,:3,:4,:5,:6,:7,:8)';
        execute immediate V_SQL_STATEMENT using P_SOURCE_SCHEMA, P_TARGET_SCHEMA, t.TABLE_NAME, P_SOURCE_COUNT, P_TARGET_COUNT, -1, -1, V_SQLERRM;
    end;
  end loop;
exception
  when OTHERS then 
	RAISE;
end;
--
end;
/
set define on
--
set TERMOUT on
--
show errors
--
set TERMOUT &TERMOUT
--
create or replace public synonym YADAMU_TEST for YADAMU_TEST
/
spool &LOGDIR/install/COMPILE_ALL.log APPEND
--
desc YADAMU_TEST
--
spool off
--
exit