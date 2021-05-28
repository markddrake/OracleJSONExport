export SRC=$1
export SCHEMA_VERSION=$2
export FILEVER=$3
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=HR$SCHEMA_VERSION FILE=$SRC/HR$FILEVER.json ENCRYPTION=false TO_USER=\"dbo\" MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=SH$SCHEMA_VERSION FILE=$SRC/SH$FILEVER.json ENCRYPTION=false TO_USER=\"dbo\" MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=OE$SCHEMA_VERSION FILE=$SRC/OE$FILEVER.json ENCRYPTION=false TO_USER=\"dbo\" MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=PM$SCHEMA_VERSION FILE=$SRC/PM$FILEVER.json ENCRYPTION=false TO_USER=\"dbo\" MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=IX$SCHEMA_VERSION FILE=$SRC/IX$FILEVER.json ENCRYPTION=false TO_USER=\"dbo\" MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=BI$SCHEMA_VERSION FILE=$SRC/BI$FILEVER.json ENCRYPTION=false TO_USER=\"dbo\" MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH

