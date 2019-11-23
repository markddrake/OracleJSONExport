source qa/sh/initialize.sh $1 $BASH_SOURCE[0] oracle export
export YADAMU_OUTPUT_BASE=$YADAMU_HOME/JSON
if [ ! -e $YADAMU_OUTPUT_BASE]; then mkdir $YADAMU_OUTPUT_BASE; fi
export YADAMU_OUTPUT_BASE=$YADAMU_OUTPUT_BASE/$YADAMU_TARGET%
if [ ! -e $YADAMU_OUTPUT_BASE]; then mkdir $YADAMU_OUTPUT_BASE; fi
export MODE=DDL_ONLY
export  YADAMU_OUTPUT_PATH=$YADAMU_OUTPUT_BASE/$MODE
if [ ! -e $YADAMU_OUTPUT_PATH]; then mkdir $YADAMU_OUTPUT_PATH; fi
. $YADAMU_SCRIPT_PATH/export_operations_Oracle.sh $YADAMU_OUTPUT_PATH "" "" $MODE
export MODE=DATA_ONLY
export  YADAMU_OUTPUT_PATH=$YADAMU_OUTPUT_BASE/$MODE
if [ ! -e $YADAMU_OUTPUT_PATH]; then mkdir $YADAMU_OUTPUT_PATH; fi
source $YADAMU_SCRIPT_PATH/export_operations_Oracle.sh $YADAMU_OUTPUT_PATH "" "" $MODE
export MODE=DDL_AND_DATA
export  YADAMU_OUTPUT_PATH=$YADAMU_OUTPUT_BASE/$MODE
if [ ! -e $YADAMU_OUTPUT_PATH]; then mkdir $YADAMU_OUTPUT_PATH; fi
source $YADAMU_SCRIPT_PATH/export_operations_Oracle.sh $YADAMU_OUTPUT_PATH "" "" $MODE
