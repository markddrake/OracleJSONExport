--
/*
** De-serialize serialized data
*/
create or replace package JSON_IMPORT
AUTHID CURRENT_USER
as
  C_VERSION_NUMBER constant NUMBER(4,2) := 1.0;
--
  $IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
  C_RETURN_TYPE     CONSTANT VARCHAR2(32) := 'CLOB';
  C_MAX_OUTPUT_SIZE CONSTANT NUMBER       := DBMS_LOB.LOBMAXSIZE;
  $ELSIF JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED $THEN
  C_RETURN_TYPE     CONSTANT VARCHAR2(32):= 'VARCHAR2(32767)';
  C_MAX_OUTPUT_SIZE CONSTANT NUMBER      := 32767;
  $ELSE
  C_RETURN_TYPE     CONSTANT VARCHAR2(32):= 'VARCHAR2(4000)';
  C_MAX_OUTPUT_SIZE CONSTANT NUMBER      := 4000;
  $END
--
  TYPE T_RESULTS_CACHE is VARRAY(2147483647) of CLOB;
  RESULTS_CACHE        T_RESULTS_CACHE := T_RESULTS_CACHE();

  C_SUCCESS          CONSTANT VARCHAR2(32) := 'SUCCESS';
  C_FATAL_ERROR      CONSTANT VARCHAR2(32) := 'FATAL';
  C_WARNING          CONSTANT VARCHAR2(32) := 'WARNING';
  C_IGNOREABLE       CONSTANT VARCHAR2(32) := 'IGNORE';

  procedure DATA_ONLY_MODE(P_DATA_ONLY_MODE BOOLEAN);
  procedure DDL_ONLY_MODE(P_DDL_ONLY_MODE BOOLEAN);

  function IMPORT_VERSION return NUMBER deterministic;

  procedure IMPORT_JSON(P_JSON_DUMP_FILE IN OUT NOCOPY BLOB,P_TARGET_SCHEMA VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CURRENT_SCHEMA'));
  function IMPORT_JSON(P_JSON_DUMP_FILE IN OUT NOCOPY BLOB,P_TARGET_SCHEMA VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CURRENT_SCHEMA')) return CLOB;

  function MAP_FOREIGN_DATATYPE(P_DATA_TYPE VARCHAR2, P_DATA_TYPE_LENGTH NUMBER, P_DATA_TYPE_SCALE NUMBER) return VARCHAR2;
  function GET_MILLISECONDS(P_START_TIME TIMESTAMP, P_END_TIME TIMESTAMP) return NUMBER;
  function SERIALIZE_TABLE(P_TABLE T_VC4000_TABLE,P_DELIMITER VARCHAR2 DEFAULT ',')  return CLOB;

end;
/
show errors
--
create or replace package body JSON_IMPORT
as
--
  C_NEWLINE         CONSTANT CHAR(1) := CHR(10);
  C_SINGLE_QUOTE    CONSTANT CHAR(1) := CHR(39);

  G_INCLUDE_DATA    BOOLEAN := TRUE;
  G_INCLUDE_DDL     BOOLEAN := FALSE;
--
function GET_MILLISECONDS(P_START_TIME TIMESTAMP, P_END_TIME TIMESTAMP)
return NUMBER
as
  V_INTERVAL INTERVAL DAY TO SECOND := P_END_TIME - P_START_TIME;
begin
  return (((((((extract(DAY from V_INTERVAL) * 24)  + extract(HOUR from  V_INTERVAL)) * 60 ) + extract(MINUTE from V_INTERVAL)) * 60 ) + extract(SECOND from  V_INTERVAL)) * 1000);
end;
--
function SERIALIZE_TABLE(P_TABLE T_VC4000_TABLE,P_DELIMITER VARCHAR2 DEFAULT ',')
return CLOB
as
  V_LIST CLOB;
begin
  DBMS_LOB.CREATETEMPORARY(V_LIST,TRUE,DBMS_LOB.CALL);
  if ((P_TABLE is not NULL) and (P_TABLE.count > 0)) then
    for i in P_TABLE.first .. P_TABLE.last loop
      if (i > 1) then
        DBMS_LOB.WRITEAPPEND(V_LIST,length(P_DELIMITER),P_DELIMITER);
      end if;
      DBMS_LOB.WRITEAPPEND(V_LIST,length(P_TABLE(i)),P_TABLE(i));
    end loop;
  end if;
  return V_LIST;
end;
--
function DESERIALIZE_TABLE(P_LIST CLOB)
return T_VC4000_TABLE
as
  V_TABLE T_VC4000_TABLE;
begin
  select cast(collect(x.COLUMN_VALUE.getStringVal()) as T_VC4000_TABLE) IMPORT_COLUMN_LIST
   into V_TABLE
   from XMLTABLE(P_LIST) x;
   return V_TABLE;
end;
--
procedure DATA_ONLY_MODE(P_DATA_ONLY_MODE BOOLEAN)
as
begin
  if (P_DATA_ONLY_MODE) then
    G_INCLUDE_DDL := false;
  else
    G_INCLUDE_DDL := true;
  end if;
end;
--
procedure DDL_ONLY_MODE(P_DDL_ONLY_MODE BOOLEAN)
as
begin
  if (P_DDL_ONLY_MODE) then
    G_INCLUDE_DATA := false;
  else
    G_INCLUDE_DATA := true;
  end if;
end;
--
function IMPORT_VERSION return NUMBER deterministic
as
begin
  return C_VERSION_NUMBER;
end;
--
procedure LOG_DDL_OPERATION(P_TABLE_NAME VARCHAR2, P_DDL_OPERATION CLOB)
as
begin
  RESULTS_CACHE.extend;
  select JSON_OBJECT('ddl' value JSON_OBJECT('tableName' value P_TABLE_NAME, 'sqlStatement' value P_DDL_OPERATION
                     $IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
                     returning CLOB) returning CLOB)
                     $ELSIF JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED $THEN
                     returning  VARCHAR2(32767)) returning  VARCHAR2(32767))
                     $ELSE
                     returning  VARCHAR2(4000)) returning  VARCHAR2(4000))
                     $END
    into RESULTS_CACHE(RESULTS_CACHE.count)
    from DUAL;
end;
--
procedure LOG_DML_OPERATION(P_TABLE_NAME VARCHAR2, P_DML_OPERATION CLOB, P_ROW_COUNT NUMBER, P_ELAPSED_TIME NUMBER)
as
begin
  RESULTS_CACHE.extend;
  select JSON_OBJECT('dml' value JSON_OBJECT('tableName' value P_TABLE_NAME, 'sqlStatement' value P_DML_OPERATION, 'rowCount' value P_ROW_COUNT, 'elapsedTime' value P_ELAPSED_TIME
               $IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
               returning CLOB) returning CLOB)
               $ELSIF JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED $THEN
               returning  VARCHAR2(32767)) returning  VARCHAR2(32767))
               $ELSE
               returning  VARCHAR2(4000)) returning  VARCHAR2(4000))
               $END
          into RESULTS_CACHE(RESULTS_CACHE.count) from DUAL;
end;
--
procedure LOG_ERROR(P_SEVERITY VARCHAR2, P_TABLE_NAME VARCHAR2,P_SQL_STATEMENT CLOB,P_SQLCODE NUMBER, P_SQLERRM VARCHAR2, P_STACK CLOB)
as
begin
  RESULTS_CACHE.extend;
  select JSON_OBJECT('error' value JSON_OBJECT('severity' value P_SEVERITY, 'tableName' value P_TABLE_NAME, 'sqlStatement' value P_SQL_STATEMENT, 'code' value P_SQLCODE, 'msg' value P_SQLERRM, 'stack' value P_STACK
                     $IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
                     returning CLOB) returning CLOB)
                     $ELSIF JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED $THEN
                     returning  VARCHAR2(32767)) returning  VARCHAR2(32767))
                     $ELSE
                     returning  VARCHAR2(4000)) returning  VARCHAR2(4000))
                     $END
     into RESULTS_CACHE(RESULTS_CACHE.count)
     from DUAL;
end;
--
procedure LOG_INFO(P_PAYLOAD CLOB)
as
begin
  RESULTS_CACHE.extend;
  $IF JSON_FEATURE_DETECTION.TREAT_AS_JSON_SUPPORTED $THEN
  select JSON_OBJECT('info' value TREAT(P_PAYLOAD as JSON) returning CLOB)
  $ELSIF JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED $THEN
  select JSON_OBJECT('info' value JSON_QUERY(P_PAYLOAD,'$' returning VARCHAR2(32767)) returning VARCHAR2(32767))
  $ELSE
  select JSON_OBJECT('info' value JSON_QUERY(P_PAYLOAD,'$' returning VARCHAR2(4000)) returning VARCHAR2(4000))
  $END
     into RESULTS_CACHE(RESULTS_CACHE.count)
     from DUAL;
end;
--
function MAP_FOREIGN_DATATYPE(P_DATA_TYPE VARCHAR2, P_DATA_TYPE_LENGTH NUMBER, P_DATA_TYPE_SCALE NUMBER)
return VARCHAR2
as
begin
  case
    when P_DATA_TYPE = 'varchar'
      then return 'VARCHAR2';
    when P_DATA_TYPE = 'decimal'
      then return 'NUMBER';
    else
      return P_DATA_TYPE;
  end case;
end;
--
procedure APPEND_DESERIALIZATION_FUNCTIONS(P_OWNER VARCHAR2,P_TABLE_NAME VARCHAR2,P_REQUIRED_FUNCTIONS VARCHAR2, P_SQL_STATEMENT IN OUT CLOB)
as
  V_CURRENT_OFFSET            PLS_INTEGER := 1;
  V_NEXT_SEPERATOR            PLS_INTEGER;
  V_FUNCTION_NAME             VARCHAR2(130);
begin
  if (P_REQUIRED_FUNCTIONS = '"OBJECTS"') then
    OBJECT_SERIALIZATION.DESERIALIZE_TABLE_TYPES(P_OWNER,P_TABLE_NAME,P_SQL_STATEMENT);
  else
    loop
      V_NEXT_SEPERATOR:= instr(P_REQUIRED_FUNCTIONS,',',V_CURRENT_OFFSET);
      exit when (V_NEXT_SEPERATOR < 1);
      V_FUNCTION_NAME  := substr(P_REQUIRED_FUNCTIONS,V_NEXT_SEPERATOR - V_CURRENT_OFFSET,V_CURRENT_OFFSET);
      if (V_FUNCTION_NAME = '"CHAR2BFILE"') then
        DBMS_LOB.APPEND(P_SQL_STATEMENT,TO_CLOB(OBJECT_SERIALIZATION.CODE_CHAR2BFILE));
        CONTINUE;
      end if;
      if  (V_FUNCTION_NAME = '"HEXBINARY2BLOB"') then
        DBMS_LOB.APPEND(P_SQL_STATEMENT,TO_CLOB(OBJECT_SERIALIZATION.CODE_HEXBINARY2BLOB));
        CONTINUE;
      end if;
      V_CURRENT_OFFSET := V_NEXT_SEPERATOR + 1;
    end loop;
  end if;
end;
--
procedure GENERATE_STATEMENTS(P_TARGET_SCHEMA VARCHAR2, P_TABLE_OWNER VARCHAR2, P_TABLE_NAME VARCHAR2, P_COLUMN_LIST CLOB, P_DATA_TYPE_LIST CLOB, P_DATA_SIZE_LIST CLOB, P_DESERIALIZATION_FUNCTIONS VARCHAR2, P_DDL_STATEMENT IN OUT NOCOPY CLOB, P_DML_STATEMENT  IN OUT NOCOPY CLOB)
as
  CURSOR generateStatementComponents
  is
  with "SOURCE_TABLE_DEFINITION" as (
          select c."KEY" "INDEX"
                ,c."VALUE" "COLUMN_NAME"
                ,t."VALUE" "DATA_TYPE"
                ,case
                   when s.VALUE = ''
                     then NULL
                   when INSTR(s."VALUE",',') > 0
                     then SUBSTR(s."VALUE",1,INSTR(s."VALUE",',')-1)
                   else
                     s."VALUE"
                 end "DATA_TYPE_LENGTH"
                ,case
                   when INSTR(s."VALUE",',') > 0
                     then SUBSTR(s."VALUE", INSTR(s."VALUE",',')+1)
                   else
                     NULL
                 end "DATA_TYPE_SCALE"
            from JSON_TABLE('[' || P_COLUMN_LIST || ']','$[*]' COLUMNS "KEY" FOR ORDINALITY, "VALUE" PATH '$') c
                ,JSON_TABLE('[' || REPLACE(P_DATA_TYPE_LIST,'"."','\".\"') || ']','$[*]' COLUMNS "KEY" FOR ORDINALITY, "VALUE" PATH '$') t
                ,JSON_TABLE('[' || P_DATA_SIZE_LIST || ']','$[*]' COLUMNS "KEY" FOR ORDINALITY, "VALUE" PATH '$') s
           where (c."KEY" = t."KEY") and (c."KEY" = s."KEY")
  ),
  "TARGET_TABLE_DEFINITION" as (
    select "INDEX", MAP_FOREIGN_DATATYPE("DATA_TYPE","DATA_TYPE_LENGTH","DATA_TYPE_SCALE") TARGET_DATA_TYPE
      from "SOURCE_TABLE_DEFINITION"
  )
--
  $IF JSON_FEATURE_DETECTION.TREAT_AS_JSON_SUPPORTED $THEN
--
  select SERIALIZE_TABLE(
           cast(collect(
                        '"' || COLUMN_NAME || '" ' ||
                        case
                          when (INSTR(DATA_TYPE,'"."') > 0)
                            then case
                                   when SUBSTR(DATA_TYPE,1,INSTR(DATA_TYPE,'"."')-1) = P_TABLE_OWNER
                                     then '"' || P_TARGET_SCHEMA || '"."' || SUBSTR(DATA_TYPE,INSTR(DATA_TYPE,'"."')+3) || '"'
                                     else '"' || DATA_TYPE || '"'
                                 end
                          when DATA_TYPE in ('DATE','DATETIME','CLOB','NCLOB','BLOB','XMLTYPE','ROWID','UROWID') or (DATA_TYPE LIKE 'INTERVAL%')
                            then TARGET_DATA_TYPE
                          when DATA_TYPE_SCALE is not NULL
                            then TARGET_DATA_TYPE  || '(' || DATA_TYPE_LENGTH || ',' || DATA_TYPE_SCALE || ')'
                          when DATA_TYPE_LENGTH  is not NULL
                            then TARGET_DATA_TYPE  || '(' || DATA_TYPE_LENGTH|| ')'
                          else
                            TARGET_DATA_TYPE
                        end || C_NEWLINE
                        order by st."INDEX"
                )
                as T_VC4000_TABLE
           )
         ) COLUMNS_CLAUSE
        ,SERIALIZE_TABLE(
           cast(collect(
                        /* Cast JSON representation back into SQL data type where implicit coversion does happen or results in incorrect results */
                        case
                          when DATA_TYPE = 'BFILE'
                            then 'case when "' || COLUMN_NAME || '" is NULL then NULL else OBJECT_SERIALIZATION.CHAR2BFILE("' || COLUMN_NAME || '") end'
                          when (DATA_TYPE = 'XMLTYPE') or (SUBSTR("DATA_TYPE",INSTR("DATA_TYPE",'"."')+3) = 'XMLTYPE')
                            then 'case when "' || COLUMN_NAME || '" is NULL then NULL else XMLTYPE("' || COLUMN_NAME || '") end'
                          when (DATA_TYPE = 'ANYDATA') or (SUBSTR("DATA_TYPE",INSTR("DATA_TYPE",'"."')+3) = 'ANYDATA')
                            -- ### TODO - Better deserialization of ANYDATA.
                            then 'case when "' || COLUMN_NAME || '" is NULL then NULL else ANYDATA.convertVARCHAR2("' || COLUMN_NAME || '") end'
                          when INSTR(DATA_TYPE,'"."') > 0
                            then '"#' || SUBSTR(DATA_TYPE,INSTR(DATA_TYPE,'"."')+3) || '"("' || COLUMN_NAME || '")'
                          when DATA_TYPE = 'BLOB'
                            $IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
                            then 'case when "' || COLUMN_NAME || '" is NULL then NULL else OBJECT_SERIALIZATION.HEXBINARY2BLOB("' || COLUMN_NAME || '") end'
                            $ELSE
                            then 'case when "' || COLUMN_NAME || '" is NULL then NULL when substr("' || COLUMN_NAME || '",1,15) = ''BLOB2HEXBINARY:'' then NULL else HEXTORAW("' || COLUMN_NAME || '") end'
                            $END
                          else
                            '"' || COLUMN_NAME || '"'
                        end
                        order by st."INDEX"
               )
               as T_VC4000_TABLE
           )
         ) INSERT_SELECT_LIST
        ,SERIALIZE_TABLE(
           cast(collect(
                        '"' || COLUMN_NAME || '" ' ||
                        case
                          when DATA_TYPE in ('CHAR','NCHAR','NVARCHAR2','RAW','BFILE','ROWID','UROWID') or (DATA_TYPE like 'INTERVAL%')
                            then 'VARCHAR2'
                          when DATA_TYPE in ('XMLTYPE','CLOB','NCLOB','BLOB','LONG','LONG RAW') or (INSTR(DATA_TYPE,'"."') > 0)
                            then C_RETURN_TYPE
                          when "DATA_TYPE" in ('DATE','DATETIME')
                            then "TARGET_DATA_TYPE"
                          when DATA_TYPE like 'TIMESTAMP%WITH LOCAL TIME ZONE'
                            then 'TIMESTAMP WITH TIME ZONE'
                          when "DATA_TYPE_SCALE" is not NULL
                            then "TARGET_DATA_TYPE"  || '(' || "DATA_TYPE_LENGTH" || ',' || "DATA_TYPE_SCALE" || ')'
                          when "DATA_TYPE_LENGTH"  is not NULL
                            then "TARGET_DATA_TYPE"  || '(' || "DATA_TYPE_LENGTH" || ')'
                          else
                            "TARGET_DATA_TYPE"
                        end
                        || ' PATH ''$[' || (st."INDEX" - 1) || ']''' || C_NEWLINE
                        order by st."INDEX"
                )
                as T_VC4000_TABLE
           )
         ) COLUMN_PATTERNS
    from "SOURCE_TABLE_DEFINITION" st, "TARGET_TABLE_DEFINITION" tt
   where st."INDEX" = tt."INDEX";
--
  $ELSE
--
  -- cast(collect(...) causes ORA-22814: attribute or element value is larger than specified in type in 12.2
  select '"' || COLUMN_NAME || '" ' ||
         case
           when (INSTR(DATA_TYPE,'"."') > 0)
             then case
                    when SUBSTR(DATA_TYPE,1,INSTR(DATA_TYPE,'"."')-1) = P_TABLE_OWNER
                      then '"' || P_TARGET_SCHEMA || '"."' || SUBSTR(DATA_TYPE,INSTR(DATA_TYPE,'"."')+3) || '"'
                      else '"' || DATA_TYPE || '"'
                  end
           when DATA_TYPE in ('DATE','DATETIME','CLOB','NCLOB','BLOB','XMLTYPE','ROWID','UROWID') or (DATA_TYPE LIKE 'INTERVAL%')
             then TARGET_DATA_TYPE
           when DATA_TYPE_SCALE is not NULL
             then TARGET_DATA_TYPE  || '(' || DATA_TYPE_LENGTH || ',' || DATA_TYPE_SCALE || ')'
           when DATA_TYPE_LENGTH  is not NULL
             then TARGET_DATA_TYPE  || '(' || DATA_TYPE_LENGTH|| ')'
           else
             TARGET_DATA_TYPE
         end || C_NEWLINE COLUMNS_CLAUSE
         /* Cast JSON representation back into SQL data type where implicit coversion does happen or results in incorrect results */
        ,case
           when DATA_TYPE = 'BFILE'
             then 'case when "' || COLUMN_NAME || '" is NULL then NULL else OBJECT_SERIALIZATION.CHAR2BFILE("' || COLUMN_NAME || '") end'
           when (DATA_TYPE = 'XMLTYPE') or (SUBSTR("DATA_TYPE",INSTR("DATA_TYPE",'"."')+3) = 'XMLTYPE')
             then 'case when "' || COLUMN_NAME || '" is NULL then NULL else XMLTYPE("' || COLUMN_NAME || '") end'
           when (DATA_TYPE = 'ANYDATA') or (SUBSTR("DATA_TYPE",INSTR("DATA_TYPE",'"."')+3) = 'ANYDATA')
             -- ### TODO - Better deserialization of ANYDATA.
             then 'case when "' || COLUMN_NAME || '" is NULL then NULL else ANYDATA.convertVARCHAR2("' || COLUMN_NAME || '") end'
           when DATA_TYPE like 'TIMESTAMP%WITH LOCAL TIME ZONE'
             -- Problems with ORA-1881
             then 'TO_TIMESTAMP_TZ("' || COLUMN_NAME || '",''YYYY-MM-DD"T"HH24:MI:SS.FFTZHTZM'')'
           when INSTR(DATA_TYPE,'"."') > 0
             then '"#' || SUBSTR(DATA_TYPE,INSTR(DATA_TYPE,'"."')+3) || '"("' || COLUMN_NAME || '")'
           when DATA_TYPE = 'BLOB'
             $IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
             then 'case when "' || COLUMN_NAME || '" is NULL then NULL else OBJECT_SERIALIZATION.HEXBINARY2BLOB("' || COLUMN_NAME || '") end'
             $ELSE
             then 'case when "' || COLUMN_NAME || '" is NULL then NULL when substr("' || COLUMN_NAME || '",1,15) = ''BLOB2HEXBINARY:'' then NULL else HEXTORAW("' || COLUMN_NAME || '") end'
             $END
           else
             '"' || COLUMN_NAME || '"'
         end INSERT_SELECT_LIST
        ,'"' || COLUMN_NAME || '" ' ||
         case
           when DATA_TYPE in ('CHAR','NCHAR','NVARCHAR2','RAW','BFILE','ROWID','UROWID') or (DATA_TYPE like 'INTERVAL%')
             then 'VARCHAR2'
           when DATA_TYPE in ('XMLTYPE','CLOB','NCLOB','BLOB','LONG','LONG RAW') or (INSTR(DATA_TYPE,'"."') > 0)
             then C_RETURN_TYPE
           when "DATA_TYPE" in ('DATE','DATETIME')
             then "TARGET_DATA_TYPE"
           when DATA_TYPE like 'TIMESTAMP%WITH LOCAL TIME ZONE'
             -- Problems with ORA-1881
			 -- then 'TIMESTAMP WITH TIME ZONE'
             then 'VARCHAR2'
            when "DATA_TYPE_SCALE" is not NULL
             then "TARGET_DATA_TYPE"  || '(' || "DATA_TYPE_LENGTH" || ',' || "DATA_TYPE_SCALE" || ')'
           when "DATA_TYPE_LENGTH"  is not NULL
             then "TARGET_DATA_TYPE"  || '(' || "DATA_TYPE_LENGTH" || ')'
           else
             "TARGET_DATA_TYPE"
         end
         || ' PATH ''$[' || (st."INDEX" - 1) || ']''' || C_NEWLINE COLUMN_PATTERNS
    from "SOURCE_TABLE_DEFINITION" st, "TARGET_TABLE_DEFINITION" tt
   where st."INDEX" = tt."INDEX"
   order by st."INDEX";

   V_COLUMNS_CLAUSE_TABLE      T_VC4000_TABLE;
   V_INSERT_SELECT_TABLE       T_VC4000_TABLE;
   V_COLUMN_PATTERNS_TABLE     T_VC4000_TABLE;
   $END
--
   V_COLUMNS_CLAUSE            CLOB;
   V_INSERT_SELECT_LIST        CLOB;
   V_COLUMN_PATTERNS           CLOB;

   V_SQL_FRAGMENT VARCHAR2(32767);
   V_INSERT_HINT  VARCHAR2(128) := '';

   C_CREATE_TABLE_BLOCK1 CONSTANT VARCHAR2(2048) :=
'declare
  TABLE_EXISTS EXCEPTION;
  PRAGMA EXCEPTION_INIT( TABLE_EXISTS , -00955 );
  V_STATEMENT CLOB := ''create table "';

   C_CREATE_TABLE_BLOCK2 CONSTANT VARCHAR2(2048) :=
')'';
begin
  execute immediate V_STATEMENT;
exception
  when TABLE_EXISTS then
    null;
end;';
begin
  DBMS_LOB.CREATETEMPORARY(P_DDL_STATEMENT,TRUE,DBMS_LOB.SESSION);
  DBMS_LOB.CREATETEMPORARY(P_DML_STATEMENT,TRUE,DBMS_LOB.SESSION);

   if (P_DESERIALIZATION_FUNCTIONS is not NULL) then
     V_INSERT_HINT := ' /*+ WITH_PLSQL */';
   end if;
--
  $IF JSON_FEATURE_DETECTION.TREAT_AS_JSON_SUPPORTED $THEN
--
   -- Cursor only generates one row (Aggregration Operation),
   for o in generateStatementComponents loop
     V_COLUMNS_CLAUSE := o.COLUMNS_CLAUSE;
     V_INSERT_SELECT_LIST := o.INSERT_SELECT_LIST;
     V_COLUMN_PATTERNS := o.COLUMN_PATTERNS;
   end loop;
--
   $ELSE
--
   open generateStatementComponents;
   fetch generateStatementComponents
         bulk collect into V_COLUMNS_CLAUSE_TABLE, V_INSERT_SELECT_TABLE, V_COLUMN_PATTERNS_TABLE;

   V_COLUMNS_CLAUSE := SERIALIZE_TABLE(V_COLUMNS_CLAUSE_TABLE);
   V_INSERT_SELECT_LIST := SERIALIZE_TABLE(V_INSERT_SELECT_TABLE);
   V_COLUMN_PATTERNS := SERIALIZE_TABLE(V_COLUMN_PATTERNS_TABLE);
--
   $END
--
   V_SQL_FRAGMENT := C_CREATE_TABLE_BLOCK1 || P_TARGET_SCHEMA || '"."' || P_TABLE_NAME || '" (';
   DBMS_LOB.WRITEAPPEND(P_DDL_STATEMENT,LENGTH(V_SQL_FRAGMENT),V_SQL_FRAGMENT);
   DBMS_LOB.APPEND(P_DDL_STATEMENT,V_COLUMNS_CLAUSE);
   V_SQL_FRAGMENT := C_NEWLINE || C_CREATE_TABLE_BLOCK2;
   DBMS_LOB.WRITEAPPEND(P_DDL_STATEMENT,LENGTH(V_SQL_FRAGMENT),V_SQL_FRAGMENT);

   V_SQL_FRAGMENT := 'insert' || V_INSERT_HINT || ' into "' || P_TARGET_SCHEMA || '"."' || P_TABLE_NAME || '" (';
   DBMS_LOB.WRITEAPPEND(P_DML_STATEMENT,LENGTH(V_SQL_FRAGMENT),V_SQL_FRAGMENT);
   DBMS_LOB.APPEND(P_DML_STATEMENT,P_COLUMN_LIST);
   V_SQL_FRAGMENT :=  ')' || C_NEWLINE;
   DBMS_LOB.WRITEAPPEND(P_DML_STATEMENT,LENGTH(V_SQL_FRAGMENT),V_SQL_FRAGMENT);

   if (P_DESERIALIZATION_FUNCTIONS is not NULL) then
     V_SQL_FRAGMENT :=  'WITH' || C_NEWLINE;
     DBMS_LOB.WRITEAPPEND(P_DML_STATEMENT,LENGTH(V_SQL_FRAGMENT),V_SQL_FRAGMENT);
     APPEND_DESERIALIZATION_FUNCTIONS(P_TARGET_SCHEMA,P_TABLE_NAME,P_DESERIALIZATION_FUNCTIONS,P_DML_STATEMENT);
   end if;
   V_SQL_FRAGMENT := 'select ';
   DBMS_LOB.WRITEAPPEND(P_DML_STATEMENT,LENGTH(V_SQL_FRAGMENT),V_SQL_FRAGMENT);
   DBMS_LOB.APPEND(P_DML_STATEMENT,V_INSERT_SELECT_LIST );
   V_SQL_FRAGMENT := C_NEWLINE || '  from JSON_TABLE(:JSON,''$.data."' || P_TABLE_NAME || '"[*]''' || C_NEWLINE || '         COLUMNS(' || C_NEWLINE || ' ';
   DBMS_LOB.WRITEAPPEND(P_DML_STATEMENT,LENGTH(V_SQL_FRAGMENT),V_SQL_FRAGMENT);
   DBMS_LOB.APPEND(P_DML_STATEMENT,V_COLUMN_PATTERNS);
   DBMS_LOB.WRITEAPPEND(P_DML_STATEMENT,2,'))');
end;
--
procedure SET_CURRENT_SCHEMA(P_TARGET_SCHEMA VARCHAR2)
as
  USER_NOT_FOUND EXCEPTION ; PRAGMA EXCEPTION_INIT( USER_NOT_FOUND , -01435 );
  V_SQL_STATEMENT CONSTANT VARCHAR2(4000) := 'ALTER SESSION SET CURRENT_SCHEMA = ' || P_TARGET_SCHEMA;
begin
  if (SYS_CONTEXT('USERENV','CURRENT_SCHEMA') <> P_TARGET_SCHEMA) then
    execute immediate V_SQL_STATEMENT;
  end if;
end;
--
procedure DISABLE_CONSTRAINTS(P_TARGET_SCHEMA VARCHAR2)
as
  cursor getConstraints
  is
  select TABLE_NAME
        ,'ALTER TABLE "' || P_TARGET_SCHEMA || '"."' || TABLE_NAME  || '" DISABLE CONSTRAINT "' || CONSTRAINT_NAME || '"' DDL_OPERATION
    from ALL_CONSTRAINTS
   where OWNER = P_TARGET_SCHEMA
     AND constraint_type = 'R';
begin
  for c in getConstraints loop
    begin
      execute immediate c.DDL_OPERATION;
      LOG_DDL_OPERATION(c.TABLE_NAME,c.DDL_OPERATION);
    exception
      when others then
        LOG_ERROR(C_WARNING,c.TABLE_NAME,c.DDL_OPERATION,SQLCODE,SQLERRM,DBMS_UTILITY.FORMAT_ERROR_STACK());
    end;
  end loop;
end;
--
procedure ENABLE_CONSTRAINTS(P_TARGET_SCHEMA VARCHAR2)
as
  cursor getConstraints
  is
  select TABLE_NAME
        ,'ALTER TABLE "' || P_TARGET_SCHEMA || '"."' || TABLE_NAME  || '" ENABLE CONSTRAINT "' || CONSTRAINT_NAME || '"' DDL_OPERATION
    from ALL_CONSTRAINTS
   where OWNER = P_TARGET_SCHEMA
     AND constraint_type = 'R';
begin
  for c in getConstraints loop
    begin
      execute immediate c.DDL_OPERATION;
      LOG_DDL_OPERATION(c.TABLE_NAME,c.DDL_OPERATION);
    exception
      when others then
        LOG_ERROR(C_WARNING,c.TABLE_NAME,c.DDL_OPERATION,SQLCODE,SQLERRM,DBMS_UTILITY.FORMAT_ERROR_STACK());
    end;
  end loop;
end;
--
procedure MANAGE_MUTATING_TABLE(P_TABLE_NAME VARCHAR2, P_DML_STATEMENT IN OUT NOCOPY CLOB)
as
  V_SQL_STATEMENT         CLOB;
  V_SQL_FRAGMENT          VARCHAR2(1024);
  V_JSON_TABLE_OFFSET     NUMBER;

  V_START_TIME   TIMESTAMP(6);
  V_END_TIME     TIMESTAMP(6);
  V_ROW_COUNT    NUMBER;
begin
   V_SQL_FRAGMENT := 'declare' || C_NEWLINE
                  || '  cursor JSON_TO_RELATIONAL' || C_NEWLINE
                  || '  is' || C_NEWLINE
                  || '  select *' || C_NEWLINE
                  || '    from ';

   DBMS_LOB.CREATETEMPORARY(V_SQL_STATEMENT,TRUE,DBMS_LOB.CALL);
   DBMS_LOB.WRITEAPPEND(V_SQL_STATEMENT,LENGTH(V_SQL_FRAGMENT),V_SQL_FRAGMENT);
   V_JSON_TABLE_OFFSET := DBMS_LOB.INSTR(P_DML_STATEMENT,' JSON_TABLE(');
   DBMS_LOB.COPY(V_SQL_STATEMENT,P_DML_STATEMENT,((DBMS_LOB.GETLENGTH(P_DML_STATEMENT)-V_JSON_TABLE_OFFSET)+1),DBMS_LOB.GETLENGTH(V_SQL_STATEMENT)+1,V_JSON_TABLE_OFFSET);

   V_SQL_FRAGMENT := ';' || C_NEWLINE
                  || '  type T_JSON_TABLE_ROW_TAB is TABLE of JSON_TO_RELATIONAL%ROWTYPE index by PLS_INTEGER;' || C_NEWLINE
                  || '  V_ROW_BUFFER T_JSON_TABLE_ROW_TAB;' || C_NEWLINE
                  || '  V_ROW_COUNT PLS_INTEGER := 0;' || C_NEWLINE
                  || 'begin' || C_NEWLINE
                  || '  open JSON_TO_RELATIONAL;' || C_NEWLINE
                  || '  loop' || C_NEWLINE
                  || '    fetch JSON_TO_RELATIONAL' || C_NEWLINE
                  || '    bulk collect into V_ROW_BUFFER LIMIT 25000;' || C_NEWLINE
                  || '    exit when V_ROW_BUFFER.count = 0;' || C_NEWLINE
                  || '    V_ROW_COUNT := V_ROW_COUNT + V_ROW_BUFFER.count;' || C_NEWLINE
                  -- || '    forall i in 1 .. V_ROW_BUFFER.count' || C_NEWLINE
                  || '    for i in 1 .. V_ROW_BUFFER.count loop' || C_NEWLINE
                  || '      insert into "' || P_TABLE_NAME || '"' || C_NEWLINE
                  || '      values V_ROW_BUFFER(i);'|| C_NEWLINE
                  || '    end loop;'|| C_NEWLINE
                  || '    commit;' || C_NEWLINE
                  || '  end loop;' || C_NEWLINE
                  || '  :2 := V_ROW_COUNT;' || C_NEWLINE
                  || 'end;';

   DBMS_LOB.WRITEAPPEND(V_SQL_STATEMENT,LENGTH(V_SQL_FRAGMENT),V_SQL_FRAGMENT);
   P_DML_STATEMENT := V_SQL_STATEMENT;
end;
--
procedure REFRESH_MATERIALIZED_VIEWS(P_TARGET_SCHEMA VARCHAR2)
as
  V_MVIEW_COUNT NUMBER;
  V_MVIEW_LIST  VARCHAR2(32767);
begin
  select COUNT(*), LISTAGG('"' || MVIEW_NAME || '"',',') WITHIN GROUP (order by MVIEW_NAME)
    into V_MVIEW_COUNT, V_MVIEW_LIST
    from ALL_MVIEWS
   where OWNER = P_TARGET_SCHEMA;

  if (V_MVIEW_COUNT > 0) then
    DBMS_MVIEW.REFRESH(V_MVIEW_LIST);
  end if;
end;
--
procedure IMPORT_JSON(P_JSON_DUMP_FILE IN OUT NOCOPY BLOB,P_TARGET_SCHEMA VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CURRENT_SCHEMA'))
as
  MUTATING_TABLE EXCEPTION ; PRAGMA EXCEPTION_INIT( MUTATING_TABLE , -04091 );

  V_CURRENT_SCHEMA           CONSTANT VARCHAR2(128) := SYS_CONTEXT('USERENV','CURRENT_SCHEMA');

  V_START_TIME TIMESTAMP(6);
  V_END_TIME   TIMESTAMP(6);
  V_ROWCOUNT   NUMBER;

  V_DDL_STATEMENT CLOB;
  V_DML_STATEMENT CLOB;

  CURSOR operationsList
  is
  select OWNER
        ,TABLE_NAME
        ,COLUMN_LIST
        ,DATA_TYPE_LIST
        ,SIZE_CONSTRAINTS
        ,DESERIALIZATION_FUNCTIONS
    from JSON_TABLE(
           P_JSON_DUMP_FILE,
           '$.metadata.*'
           COLUMNS (
             OWNER                        VARCHAR2(128) PATH '$.owner'
           , TABLE_NAME                   VARCHAR2(128) PATH '$.tableName'
           $IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
           ,  COLUMN_LIST                          CLOB PATH '$.columns'
           ,  DATA_TYPE_LIST                       CLOB PATH '$.dataTypes'
           ,  SIZE_CONSTRAINTS                     CLOB PATH '$.dataTypeSizing'
           ,  INSERT_COLUMN_LIST                   CLOB PATH '$.insertSelectList'
           ,  COLUMN_PATTERNS                      CLOB PATH '$.columnPatterns'
           $ELSIF JSON_FEATURE_DETECTION.EXTENDED_STRING_SUPPORTED $THEN
           ,  COLUMN_LIST               VARCHAR2(32767) PATH '$.columns'
           ,  DATA_TYPE_LIST            VARCHAR2(32767) PATH '$.dataTypes'
           ,  SIZE_CONSTRAINTS          VARCHAR2(32767) PATH '$.dataTypeSizing'
           ,  INSERT_COLUMN_LIST        VARCHAR2(32767) PATH '$.insertSelectList'
           ,  COLUMN_PATTERNS           VARCHAR2(32767) PATH '$.columnPatterns'
           $ELSE
           ,  COLUMN_LIST                VARCHAR2(4000) PATH '$.columns'
           ,  DATA_TYPE_LIST             VARCHAR2(4000) PATH '$.dataTypes'
           ,  SIZE_CONSTRAINTS           VARCHAR2(4000) PATH '$.dataTypeSizing'
           ,  INSERT_COLUMN_LIST         VARCHAR2(4000) PATH '$.insertSelectList'
           ,  COLUMN_PATTERNS            VARCHAR2(4000) PATH '$.columnPatterns'
           $END
           ,  DESERIALIZATION_FUNCTIONS  VARCHAR2(4000) PATH '$.deserializationFunctions'
           )
         );
begin
  -- LOG_INFO(JSON_OBJECT('startTime' value SYSTIMESTAMP, 'includeData' value G_INCLUDE_DATA, 'includeDDL' value G_INCLUDE_DDL));

  SET_CURRENT_SCHEMA(P_TARGET_SCHEMA);

  if (G_INCLUDE_DDL) then
    JSON_EXPORT_DDL.APPLY_DDL_STATEMENTS(P_JSON_DUMP_FILE,P_TARGET_SCHEMA);
  end if;


  if (G_INCLUDE_DATA) then

  DISABLE_CONSTRAINTS(P_TARGET_SCHEMA) ;

    for o in operationsList loop
      GENERATE_STATEMENTS(P_TARGET_SCHEMA, o.OWNER, o.TABLE_NAME, o.COLUMN_LIST, o.DATA_TYPE_LIST, o.SIZE_CONSTRAINTS, o.DESERIALIZATION_FUNCTIONS, V_DDL_STATEMENT, V_DML_STATEMENT);
      begin
        execute immediate V_DDL_STATEMENT;
        LOG_DDL_OPERATION(o.TABLE_NAME,V_DDL_STATEMENT);
      exception
        when others then
          LOG_ERROR(C_FATAL_ERROR,o.TABLE_NAME,V_DDL_STATEMENT,SQLCODE,SQLERRM,DBMS_UTILITY.FORMAT_ERROR_STACK());
      end;
      begin
        V_START_TIME := SYSTIMESTAMP;
        execute immediate V_DML_STATEMENT using P_JSON_DUMP_FILE;
        V_ROWCOUNT := SQL%ROWCOUNT;
        V_END_TIME := SYSTIMESTAMP;
        commit;
        LOG_DML_OPERATION(o.TABLE_NAME,V_DML_STATEMENT,V_ROWCOUNT,GET_MILLISECONDS(V_START_TIME,V_END_TIME));
      exception
        when MUTATING_TABLE then
          begin
            LOG_ERROR(C_WARNING,o.TABLE_NAME,V_DML_STATEMENT,SQLCODE,SQLERRM,DBMS_UTILITY.FORMAT_ERROR_STACK());
            MANAGE_MUTATING_TABLE(o.TABLE_NAME,V_DML_STATEMENT);
            V_START_TIME := SYSTIMESTAMP;
            execute immediate V_DML_STATEMENT using P_JSON_DUMP_FILE, out V_ROWCOUNT;
            V_END_TIME := SYSTIMESTAMP;
            commit;
            LOG_DML_OPERATION(o.TABLE_NAME,V_DML_STATEMENT,V_ROWCOUNT,GET_MILLISECONDS(V_START_TIME,V_END_TIME));
          exception
            when others then
              LOG_ERROR(C_FATAL_ERROR,o.TABLE_NAME,V_DML_STATEMENT,SQLCODE,SQLERRM,DBMS_UTILITY.FORMAT_ERROR_STACK());
           end;
        when others then
          LOG_ERROR(C_FATAL_ERROR,o.TABLE_NAME,V_DML_STATEMENT,SQLCODE,SQLERRM,DBMS_UTILITY.FORMAT_ERROR_STACK());
      end;
    end loop;

    ENABLE_CONSTRAINTS(P_TARGET_SCHEMA);
    REFRESH_MATERIALIZED_VIEWS(P_TARGET_SCHEMA);

    end if;
  SET_CURRENT_SCHEMA(V_CURRENT_SCHEMA);
exception
  when OTHERS then
    SET_CURRENT_SCHEMA(V_CURRENT_SCHEMA);
    RAISE;
end;
--
$IF JSON_FEATURE_DETECTION.CLOB_SUPPORTED $THEN
--
function GENERATE_IMPORT_LOG
return CLOB
as
   V_IMPORT_LOG CLOB;
begin
  select JSON_ARRAYAGG(TREAT (LOGENTRY as JSON) returning CLOB)
    into V_IMPORT_LOG
    from (
           select COLUMN_VALUE LOGENTRY
             from table(JSON_EXPORT_DDL.RESULTS_CACHE)
            union all
           select COLUMN_VALUE LOGENTRY
             from table(RESULTS_CACHE)
         );
  return V_IMPORT_LOG;
end;
--
$ELSE
--
function GENERATE_IMPORT_LOG
return CLOB
as
  V_IMPORT_LOG CLOB;
  V_FIRST_ITEM    BOOLEAN := TRUE;

  cursor getLogRecords
  is
  select COLUMN_VALUE LOGENTRY
    from table(JSON_EXPORT_DDL.RESULTS_CACHE)
   union all
  select COLUMN_VALUE LOGENTRY
        from table(RESULTS_CACHE);

begin
  DBMS_LOB.CREATETEMPORARY(V_IMPORT_LOG,TRUE,DBMS_LOB.CALL);

  DBMS_LOB.WRITEAPPEND(V_IMPORT_LOG,1,'[');

  for i in getLogRecords loop
    if (not V_FIRST_ITEM) then
      DBMS_LOB.WRITEAPPEND(V_IMPORT_LOG,1,',');
    end if;
    V_FIRST_ITEM := FALSE;
    DBMS_LOB.APPEND(V_IMPORT_LOG,i.LOGENTRY);
  end loop;

  DBMS_LOB.WRITEAPPEND(V_IMPORT_LOG,1,']');
  return V_IMPORT_LOG;
end;
--
$END
--
function IMPORT_JSON(P_JSON_DUMP_FILE IN OUT BLOB,P_TARGET_SCHEMA VARCHAR2 DEFAULT SYS_CONTEXT('USERENV','CURRENT_SCHEMA'))
return CLOB
as
begin
  IMPORT_JSON(P_JSON_DUMP_FILE, P_TARGET_SCHEMA);
  return GENERATE_IMPORT_LOG();
end;
--
end;
/
show errors
--