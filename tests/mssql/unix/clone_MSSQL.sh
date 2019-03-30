export YADAMU_TARGET=MsSQL
export YADAMU_PARSER=CLARINET
. ../unix/initialize.sh $(readlink -f "$BASH_SOURCE")
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -dmaster -I -e -i$YADAMU_DB_ROOT/sql/JSON_IMPORT.sql > $YADAMU_LOG_PATH/install/JSON_IMPORT.log
export SCHEMAVER=1
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_NAME -I -e -vID=$SCHEMAVER -i$YADAMU_SCRIPT_ROOT/sql/RECREATE_MSSQL_ALL.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
. $YADAMU_SCRIPT_ROOT/unix/import_MSSQL.sh $YADAMU_INPUT_PATH $SCHEMAVER ""
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_NAME -I -e -vDATABASE=$DB_NAME -vID1="" -vID2=$SCHEMAVER -vMETHOD=$YADAMU_PARSER -i$YADAMU_SCRIPT_ROOT/sql/COMPARE_MSSQL_ALL.sql >>$YADAMU_LOG_PATH/COMPARE_SCHEMA.log
. $YADAMU_SCRIPT_ROOT/unix/export_MSSQL.sh $YADAMU_OUTPUT_PATH $SCHEMAVER $SCHEMAVER
export SCHEMAVER=2
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_NAME -I -e -vID=$SCHEMAVER -i$YADAMU_SCRIPT_ROOT/sql/RECREATE_MSSQL_ALL.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
. $YADAMU_SCRIPT_ROOT/unix/import_MSSQL.sh $YADAMU_OUTPUT_PATH $SCHEMAVER 1
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_NAME -I -e -vDATABASE=$DB_NAME -vID1=1 -vID2=$SCHEMAVER -vMETHOD=$YADAMU_PARSER -i$YADAMU_SCRIPT_ROOT/sql/COMPARE_MSSQL_ALL.sql >>$YADAMU_LOG_PATH/COMPARE_SCHEMA.log
. $YADAMU_SCRIPT_ROOT/unix/export_MSSQL.sh $YADAMU_OUTPUT_PATH $SCHEMAVER $SCHEMAVER
export FILENAME=AdventureWorksALL
export SCHEMA=ADVWRK
export SCHEMAVER=1
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_NAME -I -e -vSCHEMA=$SCHEMA$SCHEMAVER -i$YADAMU_SCRIPT_ROOT/sql/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
node $YADAMU_DB_ROOT/node/import --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$SCHEMA$SCHEMAVER file=$YADAMU_INPUT_PATH/$FILENAME.json toUser=\"dbo\" logFile=$IMPORTLOG
node $YADAMU_DB_ROOT/node/export --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$SCHEMA$SCHEMAVER file=$YADAMU_OUTPUT_PATH/$FILENAME$SCHEMAVER.json owner=\"dbo\" mode=$MODE logFile=$EXPORTLOG
export SCHEMAVER=2
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_NAME -I -e -vSCHEMA=$SCHEMA$SCHEMAVER -i$YADAMU_SCRIPT_ROOT/sql/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
node $YADAMU_DB_ROOT/node/import --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$SCHEMA$SCHEMAVER file=$YADAMU_OUTPUT_PATH/$FILENAME1.json toUser=\"dbo\" logFile=$IMPORTLOG
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_NAME -I -e -vDATABASE=$DB_NAME -vSCHEMA=$SCHEMA -vID1=1 -vID2=$SCHEMAVER -vMETHOD=$YADAMU_PARSER -i$YADAMU_SCRIPT_ROOT/sql/COMPARE_SCHEMA.sql >>$YADAMU_LOG_PATH/COMPARE_SCHEMA.log 
node $YADAMU_DB_ROOT/node/export --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$SCHEMA$SCHEMAVER file=$YADAMU_OUTPUT_PATH/$FILENAME$SCHEMAVER.json owner=\"dbo\" mode=$MODE logFile=$EXPORTLOG
node $YADAMU_HOME/utilities/node/compareFileSizes $YADAMU_LOG_PATH $YADAMU_INPUT_PATH $YADAMU_OUTPUT_PATH
node --max_old_space_size=4096 $YADAMU_HOME/utilities/node/compareArrayContent $YADAMU_LOG_PATH $YADAMU_INPUT_PATH $YADAMU_OUTPUT_PATH false