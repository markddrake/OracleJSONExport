export SRC=$1
export SCHEMA_VERSION=$2
export VER=$3
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=Northwind$SCHEMA_VERSION         FILE=$SRC/Northwind$VER.json        ENCRYPTION=false TO_USER=dbo            MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=AdventureWorks$SCHEMA_VERSION    FILE=$SRC/Sales$VER.json            ENCRYPTION=false TO_USER=Sales          MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=AdventureWorks$SCHEMA_VERSION    FILE=$SRC/Person$VER.json           ENCRYPTION=false TO_USER=Person         MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=AdventureWorks$SCHEMA_VERSION    FILE=$SRC/Production$VER.json       ENCRYPTION=false TO_USER=Production     MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=AdventureWorks$SCHEMA_VERSION    FILE=$SRC/Purchasing$VER.json       ENCRYPTION=false TO_USER=Purchasing     MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=AdventureWorks$SCHEMA_VERSION    FILE=$SRC/HumanResources$VER.json   ENCRYPTION=false TO_USER=HumanResources MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH
source $YADAMU_BIN/upload.sh --RDBMS=$YADAMU_VENDOR --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PASSWORD=$DB_PWD --DATABASE=AdventureWorksDW$SCHEMA_VERSION  FILE=$SRC/AdventureWorksDW$VER.json ENCRYPTION=false TO_USER=dbo            MODE=$MODE LOG_FILE=$YADAMU_IMPORT_LOG  EXCEPTION_FOLDER=$YADAMU_LOG_PATH