export SRC=$1
export SCHEMA_VERSION=$2
export VER=$3
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=$DB_DBNAME FILE=$SRC/HR$VER.json ENCRYPTION=false TO_USER=\"HR$SCHEMA_VERSION\" MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=$DB_DBNAME FILE=$SRC/SH$VER.json ENCRYPTION=false TO_USER=\"SH$SCHEMA_VERSION\" MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=$DB_DBNAME FILE=$SRC/OE$VER.json ENCRYPTION=false TO_USER=\"OE$SCHEMA_VERSION\" MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=$DB_DBNAME FILE=$SRC/PM$VER.json ENCRYPTION=false TO_USER=\"PM$SCHEMA_VERSION\" MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=$DB_DBNAME FILE=$SRC/IX$VER.json ENCRYPTION=false TO_USER=\"IX$SCHEMA_VERSION\" MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=$DB_DBNAME FILE=$SRC/BI$VER.json ENCRYPTION=false TO_USER=\"BI$SCHEMA_VERSION\" MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH

