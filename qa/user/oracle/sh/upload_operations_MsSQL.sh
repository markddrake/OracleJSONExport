export SRC=$1
export SCHEMAVER=$2
export VER=$3
node $YADAMU_BIN/upload --rdbms=$YADAMU_DB  userid=$DB_USER/$DB_PWD@$DB_CONNECTION file=$SRC/Northwind$VER.json        to_user=\"Northwind$SCHEMAVER\"        mode=$MODE log_file=$YADAMU_IMPORT_LOG 
node $YADAMU_BIN/upload --rdbms=$YADAMU_DB  userid=$DB_USER/$DB_PWD@$DB_CONNECTION file=$SRC/Sales$VER.json            to_user=\"Sales$SCHEMAVER\"            mode=$MODE log_file=$YADAMU_IMPORT_LOG
node $YADAMU_BIN/upload --rdbms=$YADAMU_DB  userid=$DB_USER/$DB_PWD@$DB_CONNECTION file=$SRC/Person$VER.json           to_user=\"Person$SCHEMAVER\"           mode=$MODE log_file=$YADAMU_IMPORT_LOG
node $YADAMU_BIN/upload --rdbms=$YADAMU_DB  userid=$DB_USER/$DB_PWD@$DB_CONNECTION file=$SRC/Production$VER.json       to_user=\"Production$SCHEMAVER\"       mode=$MODE log_file=$YADAMU_IMPORT_LOG
node $YADAMU_BIN/upload --rdbms=$YADAMU_DB  userid=$DB_USER/$DB_PWD@$DB_CONNECTION file=$SRC/Purchasing$VER.json       to_user=\"Purchasing$SCHEMAVER\"       mode=$MODE log_file=$YADAMU_IMPORT_LOG
node $YADAMU_BIN/upload --rdbms=$YADAMU_DB  userid=$DB_USER/$DB_PWD@$DB_CONNECTION file=$SRC/HumanResources$VER.json   to_user=\"HumanResources$SCHEMAVER\"   mode=$MODE log_file=$YADAMU_IMPORT_LOG
node $YADAMU_BIN/upload --rdbms=$YADAMU_DB  userid=$DB_USER/$DB_PWD@$DB_CONNECTION file=$SRC/AdventureWorksDW$VER.json to_user=\"AdventureWorksDW$SCHEMAVER\" mode=$MODE log_file=$YADAMU_IMPORT_LOG
