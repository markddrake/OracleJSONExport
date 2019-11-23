source qa/sh/initialize.sh $BASH_SOURCE[0] $BASH_SOURCE[0] mssql import
export YADAMU_PARSER="CLARINET"
export SCHEMAVER=1
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -a -vID=$SCHEMAVER -vMETHOD=$YADAMU_PARSER/ -f $YADAMU_SQL_PATH/RECREATE_MSSQL_ALL.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
source $YADAMU_SCRIPT_PATH/import_MSSQL.sh $YADAMU_INPUT_PATH $SCHEMAVER ""
source $YADAMU_SCRIPT_PATH/export_MSSQL.sh $YADAMU_OUTPUT_PATH $SCHEMAVER $SCHEMAVER
export SCHEMAVER=2
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -a -vID=$SCHEMAVER -vMETHOD=$YADAMU_PARSER/ -f $YADAMU_SQL_PATH/RECREATE_MSSQL_ALL.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
source $YADAMU_SCRIPT_PATH/import_MSSQL.sh $YADAMU_OUTPUT_PATH $SCHEMAVER 1
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -q -vID1=1 -vID2=$SCHEMAVER -vMETHOD=$YADAMU_PARSER/ -f $YADAMU_SQL_PATH/COMPARE_MSSQL_ALL.sql >>$YADAMU_LOG_PATH/COMPARE_SCHEMA.log
source $YADAMU_SCRIPT_PATH/export_MSSQL.sh $YADAMU_OUTPUT_PATH $SCHEMAVER $SCHEMAVER
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -a -vSCHEMA=$SCHEMA -vID=$SCHEMAVER -vMETHOD=$YADAMU_PARSER/ -f $YADAMU_SQL_PATH/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
export FILENAME=AdventureWorksALL
export SCHEMA=ADVWRK
export SCHEMAVER=1
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -a -vSCHEMA=$SCHEMA -vID=$SCHEMAVER -vMETHOD='JSON_TABLE' -f $YADAMU_SQL_PATH/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
node $YADAMU_BIN/import --rdbms=$YADAMU_DB --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$DB_DBNAME file=$YADAMU_INPUT_PATH/$FILENAME.json to_user=\"$SCHEMA$SCHEMAVER\" log_file=$YADAMU_IMPORT_LOG
node $YADAMU_BIN/export --rdbms=$YADAMU_DB --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$DB_DBNAME file=$YADAMU_OUTPUT_PATH/$FILENAME$SCHEMAVER.json owner=\"$SCHEMA$SCHEMAVER\" mode=$MODE log_file=$YADAMU_EXPORT_LOG
export SCHEMAVER=2
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -a -vSCHEMA=$SCHEMA -vID=$SCHEMAVER -vMETHOD='JSON_TABLE' -f $YADAMU_SQL_PATH/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
node $YADAMU_BIN/import --rdbms=$YADAMU_DB --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$DB_DBNAME file=$YADAMU_OUTPUT_PATH/${FILENAME}1.json to_user=\"$SCHEMA$SCHEMAVER\" log_file=$YADAMU_IMPORT_LOG
psql -U $DB_USER -d $DB_DBNAME -h $DB_HOST -q -vSCHEMA=$SCHEMA -vID1=1 -vID2=$SCHEMAVER -vMETHOD=$YADAMU_PARSER/ -f $YADAMU_SQL_PATH/COMPARE_SCHEMA.sql >>$YADAMU_LOG_PATH/COMPARE_SCHEMA.log
node $YADAMU_BIN/export --rdbms=$YADAMU_DB --username=$DB_USER --hostname=$DB_HOST --password=$DB_PWD --database=$DB_DBNAME file=$YADAMU_OUTPUT_PATH/$FILENAME$SCHEMAVER.json owner=\"$SCHEMA$SCHEMAVER\" mode=$MODE log_file=$YADAMU_EXPORT_LOG
node $YADAMU_QA_BIN/compareFileSizes $YADAMU_LOG_PATH $YADAMU_INPUT_PATH $YADAMU_OUTPUT_PATH
node --max_old_space_size=4096 $YADAMU_QA_BIN/compareArrayContent $YADAMU_LOG_PATH $YADAMU_INPUT_PATH $YADAMU_OUTPUT_PATH false