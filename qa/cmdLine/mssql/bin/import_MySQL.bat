@echo %YADAMU_TRACE%
call qa\cmdLine\bin\initialize.bat %1 %~dp0 mysql import %YADAMU_TESTNAME%
set YADAMU_PARSER=CLARINET
set FILENAME=sakila
set SCHEMA=sakila
set SCHEMA_VERSION=1
sqlcmd -U%DB_USER% -P%DB_PWD% -S%DB_HOST% -d%DB_DBNAME% -I -e -vMSSQL_SCHEMA=%SCHEMA%%SCHEMA_VERSION% -i%YADAMU_SQL_PATH%\RECREATE_SCHEMA.sql >>%YADAMU_LOG_PATH%\RECREATE_SCHEMA.log
call %YADAMU_BIN%\import.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=%SCHEMA%%SCHEMA_VERSION%  FILE=%YADAMU_IMPORT_MYSQL%\%FILENAME%.json ENCRYPTION=false TO_USER=\"dbo\"  MODE=%MODE%  LOG_FILE=%YADAMU_IMPORT_LOG% EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
call %YADAMU_BIN%\export.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=%SCHEMA%%SCHEMA_VERSION%  FILE=%YADAMU_OUTPUT_PATH%\%FILENAME%%SCHEMA_VERSION%.json  ENCRYPTION=false FROM_USER=\"dbo\"  MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
set PRIOR_VERSION=%SCHEMA_VERSION%
set /a SCHEMA_VERSION+=1
sqlcmd -U%DB_USER% -P%DB_PWD% -S%DB_HOST% -d%DB_DBNAME% -I -e -vMSSQL_SCHEMA=%SCHEMA%%SCHEMA_VERSION% -i%YADAMU_SQL_PATH%\RECREATE_SCHEMA.sql >>%YADAMU_LOG_PATH%\RECREATE_SCHEMA.log
call %YADAMU_BIN%\import.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=%SCHEMA%%SCHEMA_VERSION%  FILE=%YADAMU_OUTPUT_PATH%\%FILENAME%%PRIOR_VERSION%.json ENCRYPTION=false TO_USER=\"dbo\"  MODE=%MODE% LOG_FILE=%YADAMU_IMPORT_LOG% EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
sqlcmd -U%DB_USER% -P%DB_PWD% -S%DB_HOST% -d%DB_DBNAME% -I -e -vDATABASE=%DB_DBNAME% -vSCHEMA=%SCHEMA% -vID1=%PRIOR_VERSION% -vID2=%SCHEMA_VERSION% -vMETHOD=%YADAMU_PARSER% -vDATETIME_PRECISION=9 -vSPATIAL_PRECISION=18 -i%YADAMU_SQL_PATH%\COMPARE_SCHEMA.sql >>%YADAMU_LOG_PATH%\COMPARE_SCHEMA.log
call %YADAMU_BIN%\export.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=%SCHEMA%%SCHEMA_VERSION%  FILE=%YADAMU_OUTPUT_PATH%\%FILENAME%%SCHEMA_VERSION%.json  ENCRYPTION=false FROM_USER=\"dbo\"  MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
set FILENAME=jsonExample
set SCHEMA=jtest
set SCHEMA_VERSION=1
sqlcmd -U%DB_USER% -P%DB_PWD% -S%DB_HOST% -d%DB_DBNAME% -I -e -vMSSQL_SCHEMA=%SCHEMA%%SCHEMA_VERSION% -i%YADAMU_SQL_PATH%\RECREATE_SCHEMA.sql >>%YADAMU_LOG_PATH%\RECREATE_SCHEMA.log
call %YADAMU_BIN%\import.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=%SCHEMA%%SCHEMA_VERSION%  FILE=%YADAMU_IMPORT_MYSQL%\%FILENAME%.json ENCRYPTION=false TO_USER=\"dbo\"  MODE=%MODE%  LOG_FILE=%YADAMU_IMPORT_LOG% EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
call %YADAMU_BIN%\export.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=%SCHEMA%%SCHEMA_VERSION%  FILE=%YADAMU_OUTPUT_PATH%\%FILENAME%%SCHEMA_VERSION%.json  ENCRYPTION=false FROM_USER=\"dbo\"  MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
set PRIOR_VERSION=%SCHEMA_VERSION%
set /a SCHEMA_VERSION+=1
sqlcmd -U%DB_USER% -P%DB_PWD% -S%DB_HOST% -d%DB_DBNAME% -I -e -vMSSQL_SCHEMA=%SCHEMA%%SCHEMA_VERSION% -i%YADAMU_SQL_PATH%\RECREATE_SCHEMA.sql >>%YADAMU_LOG_PATH%\RECREATE_SCHEMA.log
call %YADAMU_BIN%\import.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=%SCHEMA%%SCHEMA_VERSION%  FILE=%YADAMU_OUTPUT_PATH%\%FILENAME%%PRIOR_VERSION%.json ENCRYPTION=false TO_USER=\"dbo\"  MODE=%MODE% LOG_FILE=%YADAMU_IMPORT_LOG% EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
sqlcmd -U%DB_USER% -P%DB_PWD% -S%DB_HOST% -d%DB_DBNAME% -I -e -vDATABASE=%DB_DBNAME% -vSCHEMA=%SCHEMA% -vID1=%PRIOR_VERSION% -vID2=%SCHEMA_VERSION% -vMETHOD=%YADAMU_PARSER% -vDATETIME_PRECISION=9 -vSPATIAL_PRECISION=18 -i%YADAMU_SQL_PATH%\COMPARE_SCHEMA.sql >>%YADAMU_LOG_PATH%\COMPARE_SCHEMA.log
call %YADAMU_BIN%\export.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=%SCHEMA%%SCHEMA_VERSION%  FILE=%YADAMU_OUTPUT_PATH%\%FILENAME%%SCHEMA_VERSION%.json  ENCRYPTION=false FROM_USER=\"dbo\"  MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
node %YADAMU_QA_JSPATH%\compareFileSizes %YADAMU_LOG_PATH% %YADAMU_IMPORT_MYSQL% %YADAMU_OUTPUT_PATH%
node %YADAMU_QA_JSPATH%\compareArrayContent %YADAMU_LOG_PATH% %YADAMU_IMPORT_MYSQL% %YADAMU_OUTPUT_PATH% false