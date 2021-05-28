set TGT=%~1
set VER=%~2
set SCHEMA_VERSION=%~3
call %YADAMU_BIN%\export.bat RDBMS=%YADAMU_VENDOR%  USERID=%DB_USER%/%DB_PWD%@%DB_CONNECTION%  ENCRYPTION=false FROM_USER=\"Northwind%SCHEMA_VERSION%\"         FILE=%TGT%\Northwind%VER%.json         MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
call %YADAMU_BIN%\export.bat RDBMS=%YADAMU_VENDOR%  USERID=%DB_USER%/%DB_PWD%@%DB_CONNECTION%  ENCRYPTION=false FROM_USER=\"Sales%SCHEMA_VERSION%\"             FILE=%TGT%\Sales%VER%.json             MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
call %YADAMU_BIN%\export.bat RDBMS=%YADAMU_VENDOR%  USERID=%DB_USER%/%DB_PWD%@%DB_CONNECTION%  ENCRYPTION=false FROM_USER=\"Person%SCHEMA_VERSION%\"            FILE=%TGT%\Person%VER%.json            MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
call %YADAMU_BIN%\export.bat RDBMS=%YADAMU_VENDOR%  USERID=%DB_USER%/%DB_PWD%@%DB_CONNECTION%  ENCRYPTION=false FROM_USER=\"Production%SCHEMA_VERSION%\"        FILE=%TGT%\Production%VER%.json        MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
call %YADAMU_BIN%\export.bat RDBMS=%YADAMU_VENDOR%  USERID=%DB_USER%/%DB_PWD%@%DB_CONNECTION%  ENCRYPTION=false FROM_USER=\"Purchasing%SCHEMA_VERSION%\"        FILE=%TGT%\Purchasing%VER%.json        MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
call %YADAMU_BIN%\export.bat RDBMS=%YADAMU_VENDOR%  USERID=%DB_USER%/%DB_PWD%@%DB_CONNECTION%  ENCRYPTION=false FROM_USER=\"HumanResources%SCHEMA_VERSION%\"    FILE=%TGT%\HumanResources%VER%.json    MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
call %YADAMU_BIN%\export.bat RDBMS=%YADAMU_VENDOR%  USERID=%DB_USER%/%DB_PWD%@%DB_CONNECTION%  ENCRYPTION=false FROM_USER=\"AdventureWorksDW%SCHEMA_VERSION%\"  FILE=%TGT%\AdventureWorksDW%VER%.json  MODE=%MODE% LOG_FILE=%YADAMU_EXPORT_LOG%  EXCEPTION_FOLDER=%YADAMU_LOG_PATH%
