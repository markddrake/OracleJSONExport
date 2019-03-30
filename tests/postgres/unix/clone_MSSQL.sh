export YADAMU_TARGET=MsSQL
export YADAMU_PARSER=CLARINET
. ../unix/initialize.sh $(readlink -f "$BASH_SOURCE")
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -a -f $YADAMU_DB_ROOT/sql/JSON_IMPORT.sql >> $YADAMU_LOG_PATH/install/JSON_IMPORT.log
export SCHEMAVER=1
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -a -vID=$SCHEMAVER -vMETHOD=$YADAMU_PARSER/ -f $YADAMU_SCRIPT_ROOT/sql/RECREATE_MSSQL_ALL.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
. $YADAMU_SCRIPT_ROOT/unix/import_MSSQL.sh $YADAMU_INPUT_PATH $SCHEMAVER ""
. $YADAMU_SCRIPT_ROOT/unix/export_MSSQL.sh $YADAMU_OUTPUT_PATH $SCHEMAVER $SCHEMAVER
export SCHEMAVER=2
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -a -vID=$SCHEMAVER -vMETHOD=$YADAMU_PARSER/ -f $YADAMU_SCRIPT_ROOT/sql/RECREATE_MSSQL_ALL.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
. $YADAMU_SCRIPT_ROOT/unix/import_MSSQL.sh $YADAMU_OUTPUT_PATH $SCHEMAVER 1
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -q -vID1=1 -vID2=$SCHEMAVER -vMETHOD=$YADAMU_PARSER/ -f $YADAMU_SCRIPT_ROOT/sql/COMPARE_MSSQL_ALL.sql >>$YADAMU_LOG_PATH/COMPARE_SCHEMA.log
. $YADAMU_SCRIPT_ROOT/unix/export_MSSQL.sh $YADAMU_OUTPUT_PATH $SCHEMAVER $SCHEMAVER
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -a -vSCHEMA=$SCHEMA -vID=$SCHEMAVER -vMETHOD=$YADAMU_PARSER/ -f $YADAMU_SCRIPT_ROOT/sql/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
export FILENAME=AdventureWorksALL
export SCHEMA=ADVWRK
export SCHEMAVER=1
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -a -vSCHEMA=$SCHEMA -vID=$SCHEMAVER -vMETHOD='JSON_TABLE' -f $YADAMU_SCRIPT_ROOT/sql/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
node $YADAMU_DB_ROOT/node/import --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD file=$YADAMU_INPUT_PATH/$FILENAME.json toUser=\"$SCHEMA$SCHEMAVER\" logFile=$IMPORTLOG
node $YADAMU_DB_ROOT/node/export --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD file=$YADAMU_OUTPUT_PATH/$FILENAME$SCHEMAVER.json owner=\"$SCHEMA$SCHEMAVER\" mode=$MODE logFile=$EXPORTLOG
export SCHEMAVER=2
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -a -vSCHEMA=$SCHEMA -vID=$SCHEMAVER -vMETHOD='JSON_TABLE' -f $YADAMU_SCRIPT_ROOT/sql/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
node $YADAMU_DB_ROOT/node/import --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD file=$YADAMU_OUTPUT_PATH/${FILENAME}1.json toUser=\"$SCHEMA$SCHEMAVER\" logFile=$IMPORTLOG
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -q -vSCHEMA=$SCHEMA -vID1=1 -vID2=$SCHEMAVER -vMETHOD=$YADAMU_PARSER/ -f $YADAMU_SCRIPT_ROOT/sql/COMPARE_SCHEMA.sql >>$YADAMU_LOG_PATH/COMPARE_SCHEMA.log
node $YADAMU_DB_ROOT/node/export --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD file=$YADAMU_OUTPUT_PATH/$FILENAME$SCHEMAVER.json owner=\"$SCHEMA$SCHEMAVER\" mode=$MODE logFile=$EXPORTLOG
node $YADAMU_HOME/utilities/node/compareFileSizes $YADAMU_LOG_PATH $YADAMU_INPUT_PATH $YADAMU_OUTPUT_PATH
node --max_old_space_size=4096 $YADAMU_HOME/utilities/node/compareArrayContent $YADAMU_LOG_PATH $YADAMU_INPUT_PATH $YADAMU_OUTPUT_PATH false