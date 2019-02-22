"use strict";
const Readable = require('stream').Readable;
const Transform = require('stream').Transform;
const QueryStream = require('pg-query-stream')

const PostgresCore = require('./postgresCore');

const EXPORT_VERSION = 1.0;
const DATABASE_VENDOR = 'Postgres';
const SPATIAL_FORMAT = "WKT";

const sqlGetSystemInformation =
`select current_database() database_name,current_user,session_user,current_setting('server_version_num') database_version`;					   

class DBReader extends Readable {  

  constructor(pgClient,schema,outputStream,mode,status,logWriter,options) {

    super({objectMode: true });  
    const self = this;
  
    this.pgClient = pgClient
    this.schema = schema;
    this.outputStream = outputStream;
    this.mode = mode;
    this.status = status;
    this.logWriter = logWriter;
    this.logWriter.write(`${new Date().toISOString()}[DBReader ${DATABASE_VENDOR}]: Ready. Mode: ${this.mode}.\n`)
        
    this.tableInfo = [];
    
    this.nextPhase = 'systemInformation'
    this.serverGeneration = undefined;
    this.maxVarcharSize = undefined;
  
  }
 
  async getSystemInformation() {     
  
    if (this.status.sqlTrace) {
      this.status.sqlTrace.write(`${sqlGetSystemInformation}\n\/\n`)
    }
    

	const results = await this.pgClient.query(sqlGetSystemInformation);
	const sysInfo = results.rows[0];

	
    return {
      date               : new Date().toISOString()
     ,timeZoneOffset     : new Date().getTimezoneOffset()                      
     ,sessionTimeZone    : sysInfo.SESSION_TIME_ZONE
     ,vendor             : DATABASE_VENDOR
     ,spatialFormat      : SPATIAL_FORMAT
     ,schema             : this.schema
     ,exportVersion      : EXPORT_VERSION
	 ,sessionUser        : sysInfo.session_user
     ,dbName             : sysInfo.database_name
     ,databaseVersion    : sysInfo.database_version
    }
    
  }

  async getDDLOperations() {
    return []
  }
   
  async getMetadata() {
    
    const metadata = await PostgresCore.generateMetadata(this.pgClient,this.schema,this.status);      
    this.tableInfo = PostgresCore.getTableInfo(metadata);
    return metadata
  
  }
  
  async pipeTableData(sqlStatement,outputStream) {44

    function waitUntilEmpty(outputStream,outputStreamError,resolve) {
        
      const recordsRemaining = outputStream.writableLength;
      if (recordsRemaining === 0) {
        outputStream.removeListener('error',outputStreamError)
        // console.log(`${new Date().toISOString()}[${DATABASE_VENDOR}]: Writer Complete.`);
        resolve(counter);
      } 
      else  {
        // console.log(`${new Date().toISOString()}[${DATABASE_VENDOR}]: DBReader Records Reamaining ${recordsRemaining}.`);
        setTimeout(waitUntilEmpty, 10,outputStream,outputStreamError,resolve);
      }   
    }
   
    let counter = 0;
    const parser = new Transform({objectMode:true});
    parser._transform = function(data,encodoing,done) {
      counter++;
      if (!outputStream.objectMode()) {
        data.json = JSON.stringify(data.json);
      }
      this.push({data : data.json})
      done();
    }

    const queryStream = new QueryStream(sqlStatement)
    const stream = await this.pgClient.query(queryStream)   
  
    return new Promise(async function(resolve,reject) {
      const outputStreamError = function(err){reject(err)}        
      outputStream.on('error',outputStreamError);
      parser.on('finish',function() {waitUntilEmpty(outputStream,outputStreamError,resolve)})
      parser.on('error',function(err){reject(err)});
      stream.on('error',function(err){reject(err)});
      stream.pipe(parser).pipe(outputStream,{end: false })
    })
  }
    
  async getTableData(table) {
      
    if (this.status.sqlTrace) {
      this.status.sqlTrace.write(`${table.SQL_STATEMENT};\n--\n`);
    }
    
    const startTime = new Date().getTime()
    const rows = await this.pipeTableData(table.SQL_STATEMENT,this.outputStream) 
    const elapsedTime = new Date().getTime() - startTime
    this.logWriter.write(`${new Date().toISOString()}[DBReader "${table.TABLE_NAME}"]: Rows read: ${rows}. Elaspsed Time: ${elapsedTime}ms. Throughput: ${Math.round((rows/elapsedTime) * 1000)} rows/s.\n`)
    return rows;
  }
  
  async _read() {
      
    try {
      switch (this.nextPhase) {
         case 'systemInformation' :
           const sysInfo = await this.getSystemInformation();
           this.push({systemInformation : sysInfo});
           if (this.mode === 'DATA_ONLY') {
             this.nextPhase = 'metadata';
           }
           else {
             this.nextPhase = 'ddl';
           }
           break;
         case 'ddl' :
           const ddl = await this.getDDLOperations();
           this.push({ddl: ddl});
           if (this.mode === 'DDL_ONLY') {
             this.push(null);
           }
           else {
             this.nextPhase = 'metadata';
           }
           break;
         case 'metadata' :
           const metadata = await this.getMetadata();
           this.push({metadata: metadata});
           this.nextPhase = 'table';
           break;
         case 'table' :
           if (this.mode !== 'DDL_ONLY') {
             if (this.tableInfo.length > 0) {
               this.push({table : this.tableInfo[0].TABLE_NAME})
               this.nextPhase = 'data'
               break;
             }
           }
           this.push(null);
           break;
         case 'data' :
           const rows = await this.getTableData(this.tableInfo[0])
           this.push({rowCount:rows});
           this.tableInfo.splice(0,1)
           this.nextPhase = 'table';
           break;
         default:
      }
    } catch (e) {
      this.logWriter.write(`${new Date().toISOString()}[DBWriter._read()]} ${e}\n`);
      process.nextTick(() => this.emit('error',e));
    }
  }
}

module.exports = DBReader;    
 
  
