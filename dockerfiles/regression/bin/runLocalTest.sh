# Run from YADAMU_HOME
export YADAMU_TASK=$1
unset YADAMU_LOG_PATH
export YADAMU_LOG_ROOT=$YADAMU_HOME/log
source $YADAMU_QA_HOME/bin/initializeLogging.sh $YADAMU_TEST
if [ -z ${NODE_NO_WARNINGS+x} ]; then export NODE_NO_WARNINGS=1; fi
if [ -e $YADAMU_HOME/log/$YADAMU_TASK.log ]; then rm $YADAMU_HOME/log/$YADAMU_TASK.log; fi
touch  $YADAMU_LOG_PATH/$YADAMU_TASK.log
ln -s $YADAMU_LOG_PATH/$YADAMU_TASK.log $YADAMU_HOME/log/$YADAMU_TASK.log
node $YADAMU_HOME/src/YADAMU_QA/common/node/test.js CONFIG=$YADAMU_HOME/local/$YADAMU_TASK.json EXCEPTION_FOLDER=$YADAMU_LOG_PATH 2>&1 | tee $YADAMU_LOG_PATH/$YADAMU_TASK.log 