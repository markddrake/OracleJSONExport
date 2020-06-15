"use strict" 

const OracleDBI = require('../../../YADAMU/oracle/node/oracleDBI.js');
const {OracleError} = require('../../../YADAMU/common/yadamuError.js')

const sqlSuccess =
`select SOURCE_SCHEMA, TARGET_SCHEMA, TABLE_NAME, 'SUCCESSFUL' "RESULTS", TARGET_ROW_COUNT
  from SCHEMA_COMPARE_RESULTS 
 where SOURCE_ROW_COUNT = TARGET_ROW_COUNT
   and MISSING_ROWS = 0
   and EXTRA_ROWS = 0
   and SQLERRM is NULL
order by TABLE_NAME`;

const sqlFailed = 
`select SOURCE_SCHEMA, TARGET_SCHEMA, TABLE_NAME, 'FAILED' "RESULTS", SOURCE_ROW_COUNT, TARGET_ROW_COUNT, MISSING_ROWS, EXTRA_ROWS, SQLERRM "NOTES"
  from SCHEMA_COMPARE_RESULTS 
 where SOURCE_ROW_COUNT <> TARGET_ROW_COUNT
    or MISSING_ROWS <> 0
    or EXTRA_ROWS <> 0
    or SQLERRM is NOT NULL
 order by TABLE_NAME`;

const sqlGatherSchemaStats = `begin dbms_stats.gather_schema_stats(ownname => :target); end;`;

// LEFT Join works in 11.x databases where 'EXTERNAL' column does not exist in ALL_TABLES

const sqlSchemaTableRows = `select att.TABLE_NAME, NUM_ROWS 
                              from ALL_TABLES att 
							  LEFT JOIN ALL_EXTERNAL_TABlES axt 
							         on att.OWNER = axt.OWNER and att.TABLE_NAME = axt.TABLE_NAME 
					    where att.OWNER = :target 
						  and axt.OWNER is NULL 
						  and att.SECONDARY = 'N' 
						  and att.DROPPED = 'NO'
                          and att.TEMPORARY = 'N'
                          and att.NESTED = 'NO'
						  and (att.IOT_TYPE is NULL or att.IOT_TYPE = 'IOT')`;
						  

const sqlCompareSchemas = `begin YADAMU_TEST.COMPARE_SCHEMAS(:source,:target,:maxTimestampPrecision,:xslTransformation,:useOrderedJSON,:excludeMaterialzedViews); end;`;


class OracleQA extends OracleDBI {
    
	async scheduleTermination(pid) {
      const killOperation = this.parameters.KILL_READER_AFTER ? 'Reader'  : 'Writer'
	  const killDelay = this.parameters.KILL_READER_AFTER ? this.parameters.KILL_READER_AFTER  : this.parameters.KILL_WRITER_AFTER
	  const timer = setTimeout(async (pid) => {
		   if ((this.pool instanceof this.oracledb.Pool) && (this.pool.status === this.oracledb.POOL_STATUS_OPEN)) {
		     this.yadamuLogger.qa(['KILL',this.DATABASE_VENDOR,killOperation,killDelay,pid.sid,pid.serial,this.getWorkerNumber()],`Killing connection.`);
			 const conn = await this.getConnectionFromPool();
			 const sqlStatement = `ALTER SYSTEM KILL SESSION '${pid.sid}, ${pid.serial}'`
			 let stack
			 try {
			   stack = new Error().stack
	           const res = await conn.execute(sqlStatement);
 		       await conn.close()
			 } catch (e) {
			   if ((e.errorNum && ((e.errorNum === 27) || (e.errorNum === 31))) || (e.message.startsWith('DPI-1010'))) {
				 // The Slave has finished and it's SID and SERIAL# appears to have been assigned to the connection being used to issue the KILLL SESSION and you can't kill yourthis (Error 27)
			     this.yadamuLogger.qa(['KILL',this.DATABASE_VENDOR,killOperation,killDelay,pid.sid,pid.serial,this.getWorkerNumber()],`Slave finished prior to termination.`)
 			   }
			   else {
				 const cause = new OracleError(e,stack,sqlStatement)
			     this.yadamuLogger.handleException(['KILL',this.DATABASE_VENDOR,killOperation,killDelay,pid.sid,pid.serial,this.getWorkerNumber()],cause)
			   }
			 }
		   }
		   else {
		     this.yadamuLogger.qa(['KILL',this.DATABASE_VENDOR,killOperation,killDelay,pid.sid,pid.serial],`Unable to Kill Connection: Connection Pool no longer available.`);
		   }
		},
		killDelay,
	    pid
      )
	  timer.unref()
	}
	
 	async recreateSchema() {
        
      try {
        const dropUser = `drop user "${this.parameters.TO_USER}" cascade`;
        await this.executeSQL(dropUser,{});      
      } catch (e) {
        if ((e.cause) && (e.cause.errorNum && (e.cause.errorNum === 1918))) {
        }
        else {
          throw e;
        }
      }
      const createUser = `grant connect, resource, unlimited tablespace to "${this.parameters.TO_USER}" identified by ${this.connectionProperties.password}`;
      await this.executeSQL(createUser,{});      
    }  

    constructor(yadamu) {
       super(yadamu)
    }

	async initialize() {
	  await super.initialize();
	  if (this.options.recreateSchema === true) {
		await this.recreateSchema();
	  }
	  if (this.testLostConnection()) {
		const dbiID = await this.getConnectionID();
		this.scheduleTermination(dbiID);
	  }
	}
	
	async compareSchemas(source,target) {

      const report = {
        successful : []
       ,failed     : []
      }
      const args = {source:source.schema,target:target.schema,maxTimestampPrecision:this.parameters.TIMESTAMP_PRECISION,xslTransformation:this.parameters.XSL_TRANSFORMATION,useOrderedJSON:this.parameters.ORDERED_JSON.toString().toUpperCase(),excludeMaterialzedViews:Boolean(this.parameters.MODE === 'DATA_ONLY').toString().toUpperCase()}
      await this.executeSQL(sqlCompareSchemas,args)      

      const successful = await this.executeSQL(sqlSuccess,{})
            
      report.successful = successful.rows.map((row,idx) => {          
        return [row[0],row[1],row[2],row[4]]
      })
        
      const failed = await this.executeSQL(sqlFailed,{})
      
      report.failed = failed.rows.map((row,idx) => {
        return [row[0],row[1],row[2],row[4],row[5],row[6],row[7],row[8]]
      })
      
      return report
    }
      
    async getRowCounts(target) {
        
      let args = {target:`"${target.schema}"`}
      await this.executeSQL(sqlGatherSchemaStats,args)
      
      args = {target:target.schema}
      const results = await this.executeSQL(sqlSchemaTableRows,args)
      
      return results.rows.map((row,idx) => {          
        return [target.schema,row[0],row[1]]
      })
      
    }

  async workerDBI(idx)  {
	const workerDBI = await super.workerDBI(idx);
	if (workerDBI.testLostConnection()) {
	  const dbiID = await workerDBI.getConnectionID();
	  this.scheduleTermination(dbiID);
    }
	return workerDBI
  }

}
	

module.exports = OracleQA