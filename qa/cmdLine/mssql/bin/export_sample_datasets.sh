#1/bin/bash
START_TIME=`date +%s`
source qa/cmdLine/bin/initialize.sh  $1 $BASH_SOURCE[0] mssql export $YADAMU_TESTNAME
rm -rf $YADAMU_EXPORT_PATH
mkdir -p $YADAMU_EXPORT_PATH
export MODE=DATA_ONLY
source $YADAMU_SCRIPT_PATH/export_operations_MsSQL.sh $YADAMU_EXPORT_PATH "" "" $MODE
export FILENAME=AdventureWorksALL
export SCHEMA=ADVWRK
export MSSQL_SCHEMA=$SCHEMA
sqlcmd -U$DB_USER -P$DB_PWD -S$DB_HOST -d$DB_DBNAME -I -e -i$YADAMU_SQL_PATH/RECREATE_SCHEMA.sql >>$YADAMU_LOG_PATH/RECREATE_SCHEMA.log
source $YADAMU_SCRIPT_PATH/import_operations_ADVWRK.sh $YADAMU_EXPORT_PATH "" "" 
source $YADAMU_BIN/export.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=$SCHEMA FILE=$YADAMU_EXPORT_PATH/$FILENAME.json overwrite=true ENCRYPTION=false FROM_USER=\"dbo\" MODE=$MODE LOG_FILE=$YADAMU_EXPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
END_TIME=`date +%s`
TOTAL_TIME=$((END_TIME-START_TIME))
ELAPSED_TIME=`date -d@$TOTAL_TIME -u +%H:%M:%S`
echo "Export ${YADAMU_DATABASE}. Elapsed time: ${ELAPSED_TIME}. Log Files written to ${YADAMU_LOG_PATH}."