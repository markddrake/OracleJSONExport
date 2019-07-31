set SCHEMAID=%1
call %YADAMU_HOME%\tests\oracle19c\env\dbConnection.bat
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_HOME%\tests\oracle\sql\RECREATE_ORACLE_ALL.sql %YADAMU_LOG_PATH%  %SCHEMAID%
call %YADAMU_HOME%\tests\oracle18c\env\dbConnection.bat
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_HOME%\tests\oracle\sql\RECREATE_ORACLE_ALL.sql %YADAMU_LOG_PATH%  %SCHEMAID%
call %YADAMU_HOME%\tests\oracle12c\env\dbConnection.bat
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_HOME%\tests\oracle\sql\RECREATE_ORACLE_ALL.sql %YADAMU_LOG_PATH%  %SCHEMAID%
call %YADAMU_HOME%\tests\oracle11g\env\dbConnection.bat
sqlplus %DB_USER%/%DB_PWD%@%DB_CONNECTION% @%YADAMU_HOME%\tests\oracle\sql\RECREATE_ORACLE_ALL.sql %YADAMU_LOG_PATH%  %SCHEMAID%
call %YADAMU_HOME%\tests\mssql\env\dbConnection.bat
sqlcmd -U%DB_USER% -P%DB_PWD% -S%DB_HOST% -d%DB_DBNAME% -I -e -vID=%SCHEMAID% -i%YADAMU_HOME%\tests\mssql\sql\RECREATE_MSSQL_ALL.sql >%YADAMU_LOG_PATH%\MSSQL_RECREATE_SCHEMA.log
call %YADAMU_HOME%\tests\mysql\env\dbConnection.bat
mysql.exe -u%DB_USER% -p%DB_PWD% -h%DB_HOST% -D%DB_DBNAME% -P%DB_PORT% -v -f --init-command="set @SCHEMA='jtest%SCHEMAID%'" <%YADAMU_HOME%\tests\mariadb\sql\RECREATE_SCHEMA.sql >>%YADAMU_LOG_PATH%\MYSQL_RECREATE_SCHEMA.log
mysql.exe -u%DB_USER% -p%DB_PWD% -h%DB_HOST% -D%DB_DBNAME% -P%DB_PORT% -v -f --init-command="set @SCHEMA='sakila%SCHEMAID%'" <%YADAMU_HOME%\tests\mariadb\sql\RECREATE_SCHEMA.sql >>%YADAMU_LOG_PATH%\MYSQL_RECREATE_SCHEMA.log
exit /b