@set YADAMU_TARGET=oracle18c\DATA_ONLY\jTable
@set YADAMU_PARSER=RDBMS
call ..\windows\initialize.bat %~dp0
@set YADAMU_INPUT_PATH=%YADAMU_INPUT_PATH:~0,-7%
mysql -u%DB_USER% -p%DB_PWD% -h%DB_HOST% -D%DB_DBNAME% -P%DB_PORT% -v -f <%YADAMU_DB_ROOT%\sql\JSON_IMPORT.sql >%YADAMU_LOG_PATH%\install\JSON_IMPORT.log
@set SCHEMAVER=1
mysql -u%DB_USER% -p%DB_PWD% -h%DB_HOST% -D%DB_DBNAME% -P%DB_PORT% -v -f --init-command="set @ID=%SCHEMAVER%; set @METHOD='%YADAMU_PARSER%';" <%YADAMU_SCRIPT_ROOT%\sql\RECREATE_ORACLE_ALL.sql >>%YADAMU_LOG_PATH%\RECREATE_SCHEMA.log
call %YADAMU_SCRIPT_ROOT%\windows\jTableImport_Oracle.bat %YADAMU_INPUT_PATH% %SCHEMAVER% ""
call %YADAMU_SCRIPT_ROOT%\windows\export_Oracle.bat %YADAMU_OUTPUT_PATH% %SCHEMAVER% %SCHEMAVER% %MODE%
@set SCHEMAVER=2
mysql -u%DB_USER% -p%DB_PWD% -h%DB_HOST% -D%DB_DBNAME% -P%DB_PORT% -v -f --init-command="set @ID=%SCHEMAVER%; set @METHOD='%YADAMU_PARSER%';" <%YADAMU_SCRIPT_ROOT%\sql\RECREATE_ORACLE_ALL.sql >>%YADAMU_LOG_PATH%\RECREATE_SCHEMA.log
call %YADAMU_SCRIPT_ROOT%\windows\jTableImport_Oracle.bat %YADAMU_OUTPUT_PATH% %SCHEMAVER% 1 
mysql -u%DB_USER% -p%DB_PWD% -h%DB_HOST% -D%DB_DBNAME% -P%DB_PORT% --init-command="set @ID1=1; set @ID2=%SCHEMAVER%; set @METHOD='%YADAMU_PARSER%'" --table <%YADAMU_SCRIPT_ROOT%\sql\COMPARE_ORACLE_ALL.sql >>%YADAMU_LOG_PATH%\COMPARE_SCHEMA.log
call %YADAMU_SCRIPT_ROOT%\windows\export_Oracle.bat %YADAMU_OUTPUT_PATH% %SCHEMAVER% %SCHEMAVER% %MODE% 
node %YADAMU_HOME%\utilities\node/compareFileSizes %YADAMU_LOG_PATH% %YADAMU_INPUT_PATH% %YADAMU_OUTPUT_PATH%
node %YADAMU_HOME%\utilities\node/compareArrayContent %YADAMU_LOG_PATH% %YADAMU_INPUT_PATH% %YADAMU_OUTPUT_PATH% false