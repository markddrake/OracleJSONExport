export YADAMU_TARGET=MySQL/jTable
export YADAMU_PARSER=RDBMS
. ../unix/initialize.sh $(readlink -f "$BASH_SOURCE")
export YADAMU_INPUT_PATH=${YADAMU_INPUT_PATH:0:-7}
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -dmaster -I -e -i$YADAMU_DB_ROOT/sql/JSON_IMPORT.sql > $YADAMU_LOG_PATH/install/JSON_IMPORT.log
export FILENAME=sakila
export SCHEMA=SAKILA
export SCHEMAVER=1
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_NAME -I -e -vSCHEMA=$SCHEMA$SCHEMAVER -i$YADAMU_SCRIPT_ROOT/sql/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
node $YADAMU_DB_ROOT/node/jTableImport --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$SCHEMA$SCHEMAVER file=$YADAMU_INPUT_PATH/$FILENAME.json toUser=\"dbo\" mode=$MODE  logFile=$IMPORTLOG
node $YADAMU_DB_ROOT/node/export --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$SCHEMA$SCHEMAVER file=$YADAMU_OUTPUT_PATH/$FILENAME$SCHEMAVER.json owner=\"dbo\" mode=$MODE logFile=$EXPORTLOG
export SCHEMAVER=2
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_NAME -I -e -vSCHEMA=$SCHEMA$SCHEMAVER -i$YADAMU_SCRIPT_ROOT/sql/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
node $YADAMU_DB_ROOT/node/jTableImport --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$SCHEMA$SCHEMAVER file=$YADAMU_OUTPUT_PATH/$FILENAME1.json toUser=\"dbo\" mode=$MODE logFile=$IMPORTLOG
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_NAME -I -e -vDATABASE=$DB_NAME -vSCHEMA=$SCHEMA -vID1=1 -vID2=$SCHEMAVER -vMETHOD=$YADAMU_PARSER -i$YADAMU_SCRIPT_ROOT/sql/COMPARE_SCHEMA.sql >>$YADAMU_LOG_PATH/COMPARE_SCHEMA.log
node $YADAMU_DB_ROOT/node/export --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$SCHEMA$SCHEMAVER file=$YADAMU_OUTPUT_PATH/$FILENAME$SCHEMAVER.json owner=\"dbo\" mode=$MODE logFile=$EXPORTLOG
export FILENAME=jsonExample
export SCHEMA=JTEST
export SCHEMAVER=1
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_NAME -I -e -vSCHEMA=$SCHEMA$SCHEMAVER -i$YADAMU_SCRIPT_ROOT/sql/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
node $YADAMU_DB_ROOT/node/jTableImport --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$SCHEMA$SCHEMAVER file=$YADAMU_INPUT_PATH/$FILENAME.json toUser=\"dbo\" mode=$MODE  logFile=$IMPORTLOG
node $YADAMU_DB_ROOT/node/export --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$SCHEMA$SCHEMAVER file=$YADAMU_OUTPUT_PATH/$FILENAME$SCHEMAVER.json owner=\"dbo\" mode=$MODE logFile=$EXPORTLOG
export SCHEMAVER=2
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_NAME -I -e -vSCHEMA=$SCHEMA$SCHEMAVER -i$YADAMU_SCRIPT_ROOT/sql/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
node $YADAMU_DB_ROOT/node/jTableImport --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$SCHEMA$SCHEMAVER file=$YADAMU_OUTPUT_PATH/$FILENAME1.json toUser=\"dbo\" mode=$MODE logFile=$IMPORTLOG
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_NAME -I -e -vDATABASE=$DB_NAME -vSCHEMA=$SCHEMA -vID1=1 -vID2=$SCHEMAVER -vMETHOD=$YADAMU_PARSER -i$YADAMU_SCRIPT_ROOT/sql/COMPARE_SCHEMA.sql >>$YADAMU_LOG_PATH/COMPARE_SCHEMA.log
node $YADAMU_DB_ROOT/node/export --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$SCHEMA$SCHEMAVER file=$YADAMU_OUTPUT_PATH/$FILENAME$SCHEMAVER.json owner=\"dbo\" mode=$MODE logFile=$EXPORTLOG
node $YADAMU_HOME/utilities/node/compareFileSizes $YADAMU_LOG_PATH $YADAMU_INPUT_PATH $YADAMU_OUTPUT_PATH
node $YADAMU_HOME/utilities/node/compareArrayContent $YADAMU_LOG_PATH $YADAMU_INPUT_PATH $YADAMU_OUTPUT_PATH false