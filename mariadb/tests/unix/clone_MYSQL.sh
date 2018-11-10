export DIR=JSON/MariaDB
export MDIR=../../JSON/MYSQL
export ID=1
export SCHEMA=sakila
export FILENAME=sakila
export ID=1
mkdir -p $DIR
. ./env/connection.sh
mysql -u$DB_USER -p$DB_PWD -h$DB_HOST -D$DB_DBNAME -P$DB_PORT -v -f <../sql/JSON_IMPORT.sql
mysql -u$DB_USER -p$DB_PWD -h$DB_HOST -D$DB_DBNAME -P$DB_PORT -v -f --init-command="SET @SCHEMA='$SCHEMA'; SET @ID=$ID" <sql/RECREATE_SCHEMA.sql
node ../node/import --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PORT=$DB_PORT --PASSWORD=$DB_PWD --DATABASE=$DB_DBNAME --File=$MDIR/$FILENAME.json toUser=\"$SCHEMA$ID\"
node ../node/export --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PORT=$DB_PORT --PASSWORD=$DB_PWD --DATABASE=$DB_DBNAME --File=$DIR/$FILENAME$ID.json owner=\"$SCHEMA$ID\"
export ID=2
mysql -u$DB_USER -p$DB_PWD -h$DB_HOST -D$DB_DBNAME -P$DB_PORT -v -f --init-command="SET @SCHEMA='$SCHEMA'; SET @ID=$ID" <sql/RECREATE_SCHEMA.sql
node ../node/import --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PORT=$DB_PORT --PASSWORD=$DB_PWD --DATABASE=$DB_DBNAME --File=$DIR/${FILENAME}1.json toUser=\"$SCHEMA$ID\"
node ../node/export --USERNAME=$DB_USER --HOSTNAME=$DB_HOST --PORT=$DB_PORT --PASSWORD=$DB_PWD --DATABASE=$DB_DBNAME --File=$DIR/$FILENAME$ID.json owner=\"$SCHEMA$ID\"
ls -l $DIR/*1.json
ls -l $DIR/*2.json
