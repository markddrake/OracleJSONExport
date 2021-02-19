set TGT=%~1
set FILEVER=%~2
set SCHEMA_VERSION=%~3
call %YADAMU_BIN%\export.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=Northwind%SCHEMA_VERSION%         FROM_USER=dbo             FILE=%TGT%\Northwind%FILEVER%.json         MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
call %YADAMU_BIN%\export.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=AdventureWorks%SCHEMA_VERSION%    FROM_USER=Sales           FILE=%TGT%\Sales%FILEVER%.json             MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
call %YADAMU_BIN%\export.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=AdventureWorks%SCHEMA_VERSION%    FROM_USER=Person          FILE=%TGT%\Person%FILEVER%.json            MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
call %YADAMU_BIN%\export.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=AdventureWorks%SCHEMA_VERSION%    FROM_USER=Production      FILE=%TGT%\Production%FILEVER%.json        MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
call %YADAMU_BIN%\export.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=AdventureWorks%SCHEMA_VERSION%    FROM_USER=Purchasing      FILE=%TGT%\Purchasing%FILEVER%.json        MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
call %YADAMU_BIN%\export.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=AdventureWorks%SCHEMA_VERSION%    FROM_USER=HumanResources  FILE=%TGT%\HumanResources%FILEVER%.json    MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
call %YADAMU_BIN%\export.bat --RDBMS=%YADAMU_VENDOR% --USERNAME=%DB_USER% --HOSTNAME=%DB_HOST% --PASSWORD=%DB_PWD% --DATABASE=AdventureWorksDW%SCHEMA_VERSION%  FROM_USER=dbo             FILE=%TGT%\AdventureWorksDW%FILEVER%.json  MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%