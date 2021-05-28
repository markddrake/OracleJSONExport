@echo %YADAMU_TRACE%
call qa\cmdLine\bin\initialize.bat %1 %~dp0 mssql upload %YADAMU_TESTNAME%
set YADAMU_PARSER=SQL
set SCHEMA_VERSION=1
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\RECREATE_MSSQL_ALL.sql %YADAMU_LOG_PATH% %SCHEMA_VERSION% 
call %YADAMU_SCRIPT_PATH%\upload_operations_MsSQL.bat %YADAMU_IMPORT_MSSQL% %SCHEMA_VERSION% ""
call %YADAMU_SCRIPT_PATH%\export_operations_MsSQL.bat %YADAMU_OUTPUT_PATH% %SCHEMA_VERSION% %SCHEMA_VERSION%
set PRIOR_VERSION=%SCHEMA_VERSION%
set /a SCHEMA_VERSION+=1
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\RECREATE_MSSQL_ALL.sql %YADAMU_LOG_PATH% %SCHEMA_VERSION% 
call %YADAMU_SCRIPT_PATH%\upload_operations_MsSQL.bat %YADAMU_OUTPUT_PATH% %SCHEMA_VERSION% %PRIOR_VERSION%
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\COMPARE_MSSQL_ALL.sql %YADAMU_LOG_PATH% %PRIOR_VERSION% %SCHEMA_VERSION% %YADAMU_PARSER% %MODE%
call %YADAMU_SCRIPT_PATH%\export_operations_MsSQL.bat %YADAMU_OUTPUT_PATH% %SCHEMA_VERSION% %SCHEMA_VERSION%
set SCHEMA_VERSION=1
set SCHEMA=ADVWRK
set SCHEMA_VERSION=1
set FILENAME=AdventureWorksALL
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\RECREATE_SCHEMA.sql %YADAMU_LOG_PATH% %SCHEMA%%SCHEMA_VERSION% 
call %YADAMU_BIN%\upload.bat RDBMS=%YADAMU_VENDOR%  USERID=%DB_USER%/%DB_PWD%@%DB_CONNECTION%  FILE=%YADAMU_IMPORT_MSSQL%\%FILENAME%.json ENCRYPTION=false TO_USER=\"%SCHEMA%%SCHEMA_VERSION%\"  MODE=%MODE% LOG_FILE=%YADAMU_IMPORT_LOG% EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
call %YADAMU_BIN%\export.bat RDBMS=%YADAMU_VENDOR%  USERID=%DB_USER%/%DB_PWD%@%DB_CONNECTION%  FILE=%YADAMU_OUTPUT_PATH%\%FILENAME%%SCHEMA_VERSION%.json  ENCRYPTION=false FROM_USER=\"%SCHEMA%%SCHEMA_VERSION%\"  MODE=%MODE%  LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
set PRIOR_VERSION=%SCHEMA_VERSION%
set /a SCHEMA_VERSION+=1
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\RECREATE_SCHEMA.sql %YADAMU_LOG_PATH% %SCHEMA%%SCHEMA_VERSION% 
call %YADAMU_BIN%\upload.bat RDBMS=%YADAMU_VENDOR%  USERID=%DB_USER%/%DB_PWD%@%DB_CONNECTION%  FILE=%YADAMU_OUTPUT_PATH%\%FILENAME%%PRIOR_VERSION%.json ENCRYPTION=false TO_USER=\"%SCHEMA%%SCHEMA_VERSION%\"  MODE=%MODE% LOG_FILE=%YADAMU_IMPORT_LOG% EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_SQL_PATH%\COMPARE_SCHEMA.sql %YADAMU_LOG_PATH% %SCHEMA% %PRIOR_VERSION% %SCHEMA_VERSION% %YADAMU_PARSER% %MODE%
call %YADAMU_BIN%\export.bat RDBMS=%YADAMU_VENDOR%  USERID=%DB_USER%/%DB_PWD%@%DB_CONNECTION%  FILE=%YADAMU_OUTPUT_PATH%\%FILENAME%%SCHEMA_VERSION%.json  ENCRYPTION=false FROM_USER=\"%SCHEMA%%SCHEMA_VERSION%\"  MODE=%MODE%  LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
node %YADAMU_QA_JSPATH%\compareFileSizes %YADAMU_LOG_PATH% %YADAMU_IMPORT_MSSQL% %YADAMU_OUTPUT_PATH%
node --max_old_space_size=8192 %YADAMU_QA_JSPATH%\compareArrayContent %YADAMU_LOG_PATH% %YADAMU_IMPORT_MSSQL% %YADAMU_OUTPUT_PATH% false