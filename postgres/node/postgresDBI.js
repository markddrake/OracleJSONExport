"use strict" 
const fs = require('fs');
const Readable = require('stream').Readable;

/* 
**
** Require Database Vendors API 
**
*/
const {Client} = require('pg')
const CopyFrom = require('pg-copy-streams').from;
const QueryStream = require('pg-query-stream')

const YadamuDBI = require('../../common/yadamuDBI.js');
const DBParser = require('./dbParser.js');
const TableWriter = require('./tableWriter.js');
const StatementGenerator = require('./statementGenerator.js');

const defaultParameters = {
  BATCHSIZE         : 10000
, COMMITSIZE        : 10000
, USERNAME          : 'postgres'
, PASSWORD          : null
, HOSTNAME          : 'localhost'
, DATABASE          : 'postgres'
, PORT              : 5432

}

const sqlGenerateQueries = `select EXPORT_JSON($1)`;

const sqlSystemInformation = `select current_database() database_name,current_user,session_user,current_setting('server_version_num') database_version`;					   

class PostgresDBI extends YadamuDBI {
    
  /*
  **
  ** Local methods 
  **
  */
   
  async getClient() {
    const pgClient = new Client(this.connectionProperties);
    await pgClient.connect();
    const yadamuLogger = this.yadamuLogger;

    pgClient.on('notice',function(n){ 
	                       const notice = JSON.parse(JSON.stringify(n));
                           switch (notice.code) {
                             case '42P07': // Table exists on Create Table if not exists
                               break;
                             case '00000': // Table not found on Drop Table if exists
		                       break;
                             default:
                               yadamuLogger.info([`${this.constructor.name}.onNotice()`],`${n}`);
                           }
    })
  
    pgClient.on('error',(err, p) => {
      this.yadamuLogger.logException([`${this.DATABASE_VENDOR}`,`Client.onError()`],err);
      throw err
    })
  
    const setTimezone = `set timezone to 'UTC'`
    if (this.status.sqlTrace) {
       this.status.sqlTrace.write(`${setTimezone};\n\--\n`)
    }
    await pgClient.query(setTimezone);
  
    const setFloatPrecision = `set extra_float_digits to 3`
    if (this.status.sqlTrace) {
       this.status.sqlTrace.write(`${setFloatPrecision};\n\--\n`)
    }
    await pgClient.query(setFloatPrecision);

    const setIntervalFormat =  `SET intervalstyle = 'iso_8601';`;
    if (this.status.sqlTrace) {
      this.status.sqlTrace.write(`${setIntervalFormat};\n\--\n`)
    }
    await pgClient.query(setIntervalFormat);

    return pgClient;
  }
  
  /*
  **
  ** Overridden Methods
  **
  */
  
  get DATABASE_VENDOR()    { return 'Postgres' };
  get SOFTWARE_VENDOR()    { return 'The PostgreSQL Global Development Group' };
  get SPATIAL_FORMAT()     { return 'WKT' };
  get DEFAULT_PARAMETERS() { return defaultParameters };

  constructor(yadamu) {
    super(yadamu,defaultParameters);
       
    this.pgClient = undefined;
    this.useBinaryJSON = false
    this.activeTransaction = false;
  }

  getConnectionProperties() {
    return {
      user      : this.parameters.USERNAME
     ,host      : this.parameters.HOSTNAME
     ,database  : this.parameters.DATABASE
     ,password  : this.parameters.PASSWORD
     ,port      : this.parameters.PORT
    }
  }

  /*  
  **
  **  Connect to the database. Set global setttings
  **
  */
  
  async initialize() {
    super.initialize();
    this.pgClient = await this.getClient()
  }

  /*
  **
  **  Gracefully close down the database connection.
  **
  */

  async finalize() {
     await this.pgClient.end();
  }

  /*
  **
  **  Abort the database connection.
  **
  */

  async abort() {
     if (this.pgClient !== undefined) {
       await this.pgClient.end();
     }
  }


  /*
  **
  ** Begin a transaction
  **
  */
  
  async beginTransaction() {

     const sqlStatement =  `begin transaction`

     if (this.activeTransaction === false) {
       if (this.status.sqlTrace) {
         this.status.sqlTrace.write(`${sqlStatement};\n\n`);
       }

       this.activeTransaction = true;
       await this.pgClient.query(sqlStatement);
     }
  }

  /*
  **
  ** Commit the current transaction
  **
  */
  
  async commitTransaction() {
     const sqlStatement =  `commit transaction`


     if (this.activeTransaction === true) {
       if (this.status.sqlTrace) {
          this.status.sqlTrace.write(`${sqlStatement};\n\n`);
       }
       this.activeTransaction = false;
       await this.pgClient.query(sqlStatement);
       await this.beginTransaction();
     }
  }

  /*
  **
  ** Abort the current transaction
  **
  */
  
  async rollbackTransaction() {
     const sqlStatement =  `rollback transaction`

     if (this.activeTransaction === true) {
       if (this.status.sqlTrace) {
          this.status.sqlTrace.write(`${sqlStatement};\n\n`);
       }
       this.activeTransaction = false;
       await this.pgClient.query(sqlStatement);
       await this.beginTransaction();
     }
  }
  
  /*
  **
  ** The following methods are used by JSON_TABLE() style import operations  
  **
  */

  /*
  **
  **  Upload a JSON File to the server. Optionally return a handle that can be used to process the file
  **
  */

  async createStagingTable() {
  	let sqlStatement = `drop table if exists "YADAMU_STAGING"`;		
    if (this.status.sqlTrace) {
      this.status.sqlTrace.write(`${sqlStatement};\n\--\n`)
    }    
  	await this.pgClient.query(sqlStatement);
  	sqlStatement = `create temporary table if not exists "YADAMU_STAGING" (data ${this.useBinaryJSON === true ? 'jsonb' : 'json'}) on commit preserve rows`;					   
    if (this.status.sqlTrace) {
      status.sqlTrace.write(`${sqlStatement};\n\--\n`)
    }    
  	await this.pgClient.query(sqlStatement);
  }
  
  async loadStagingTable(importFilePath) {

    const copyStatement = `copy "YADAMU_STAGING" from STDIN csv quote e'\x01' delimiter e'\x02'`;
    if (this.status.sqlTrace) {
      status.sqlTrace.write(`${copyStatement};\n\--\n`)
    }    

    let inputStream = fs.createReadStream(importFilePath);
    const stream = this.pgClient.query(CopyFrom(copyStatement));
    const importProcess = new Promise(async function(resolve,reject) {  
      stream.on('end',function() {resolve()})
  	  stream.on('error',function(err){reject(err)});  	  
      inputStream.pipe(stream);
    })  
    
    const startTime = new Date().getTime();
    await importProcess;
    const elapsedTime = new Date().getTime() - startTime
    inputStream.close()
    return elapsedTime;
  }
  
  async uploadFile(importFilePath) {
    let elapsedTime;
    try {
      await this.createStagingTable();    
      elapsedTime = await this.loadStagingTable(importFilePath)
    }
    catch (e) {
      if (e.code && (e.code === '54000')) {
        this.yadamuLogger.log([`${this.constructor.name}.uploadFile()`],`Cannot process file using Binary JSON. Switching to textual JSON.`)
        this.useBinaryJSON = false;
        await this.createStagingTable();
        elapsedTime = await this.loadStagingTable(importFilePath);	
      }      
      else {
        throw e
      }
    }
  }
  
  /*
  **
  **  Process a JSON File that has been uploaded to the server. 
  **
  */

 async processStagingTable(schema) {  	
  	const sqlStatement = `select ${this.useBinaryJSON ? 'import_jsonb' : 'import_json'}(data,$1) from "YADAMU_STAGING"`;
    if (this.status.sqlTrace) {
      this.status.sqlTrace.write(`${sqlStatement};\n\--\n`)
    }    
  	var results = await this.pgClient.query(sqlStatement,[schema]);
    if (results.rows.length > 0) {
      if (this.useBinaryJSON  === true) {
	    return results.rows[0].import_jsonb;  
      }
      else {
	    return results.rows[0].import_json;  
      }
    }
    else {
      this.yadamuLogger.error([`${this.constructor.name}.processStagingTable()`],`Unexpected Error. No response from ${ this.useBinaryJSON === true ? 'CALL IMPORT_JSONB()' : 'CALL_IMPORT_JSON()'}. Please ensure file is valid JSON and NOT pretty printed.`);
      // Return value will be parsed....
      return [];
    }
  }

  async processFile(hndl) {
     return await this.processStagingTable(this.parameters.TOUSER)
  }
  
  /*
  **
  ** The following methods are used by the YADAMU DBReader class
  **
  */
  
  /*
  **
  **  Generate the SystemInformation object for an Export operation
  **
  */
  
  async getSystemInformation(EXPORT_VERSION) {     
  
    if (this.status.sqlTrace) {
      this.status.sqlTrace.write(`${sqlSystemInformation};\n\--\n`)
    }
   
	const results = await this.pgClient.query(sqlSystemInformation);
	const sysInfo = results.rows[0];
	
    return {
      date               : new Date().toISOString()
     ,timeZoneOffset     : new Date().getTimezoneOffset()                      
     ,sessionTimeZone    : sysInfo.SESSION_TIME_ZONE
     ,vendor             : this.DATABASE_VENDOR
     ,spatialFormat      : this.SPATIAL_FORMAT
     ,schema             : this.parameters.OWNER
     ,exportVersion      : EXPORT_VERSION
	 ,sessionUser        : sysInfo.session_user
     ,dbName             : sysInfo.database_name
     ,databaseVersion    : sysInfo.database_version
     ,softwareVendor     : this.SOFTWARE_VENDOR
     ,nodeClient         : {
        version          : process.version
       ,architecture     : process.arch
       ,platform         : process.platform
      }      
    }
  }

  /*
  **
  **  Generate a set of DDL operations from the metadata generated by an Export operation
  **
  */

  async getDDLOperations() {
    return undefined
  }
  
  async fetchMetadata(schema) {

    if (this.status.sqlTrace) {
      this.status.sqlTrace.write(`${sqlGenerateQueries};\n\--\n`)
    }  
    
    const results = await this.pgClient.query(sqlGenerateQueries,[schema]);
    this.metadata = results.rows[0].export_json;
  }
  
  generateTableInfo() {
      
    const tableInfo = Object.keys(this.metadata).map(function(value) {
      return {TABLE_NAME : value, SQL_STATEMENT : this.metadata[value].sqlStatemeent}
    },this)
    return tableInfo;    
    
  }
  
  async getSchemaInfo(schema) {
    await this.fetchMetadata(this.parameters[schema]);
    return this.generateTableInfo();
  }

  generateMetadata(tableInfo,server) {     
    return this.metadata;
  }
   
  generateSelectStatement(tableMetadata) {
     return tableMetadata;
  }   

  createParser(query,objectMode) {
    return new DBParser(query,objectMode,this.yadamuLogger);
  }  
  
  async getInputStream(query,parser) {
        
    if (this.status.sqlTrace) {
      this.status.sqlTrace.write(`${query.SQL_STATEMENT};\n\--\n`)
    }  
    
    const queryStream = new QueryStream(query.SQL_STATEMENT)
    return await this.pgClient.query(queryStream)   
  }      

  /*
  **
  ** The following methods are used by the YADAMU DBwriter class
  **
  */
  
  async initializeDataLoad() {
  }
  
  async createSchema(schema) {
    const createSchema = `create schema if not exists "${schema}"`;
    if (this.status.sqlTrace) {
      this.status.sqlTrace.write(`${createSchema};\n--\n`);
    }
    await this.pgClient.query(createSchema);   
  }
  
  async executeDDL(ddl) {
    await this.createSchema(this.parameters.TOUSER);
    await Promise.all(ddl.map(async function(ddlStatement) {
      try {
        ddlStatement = ddlStatement.replace(/%%SCHEMA%%/g,this.parameters.TOUSER);
        if (this.status.sqlTrace) {
          this.status.sqlTrace.write(`${ddlStatement};\n--\n`);
        }
        return await this.pgClient.query(ddlStatement);
      } catch (e) {
        this.yadamuLogger.logException([`${this.constructor.name}.executeDDL()`],e)
        this.yadamuLogger.writeDirect(`${ddlStatement}\n`)
      }
    },this))
  }
  
  async generateStatementCache(schema,executeDDL) {
    await super.generateStatementCache(StatementGenerator, schema, executeDDL)
  }

  getTableWriter(table) {
    const tableName = this.metadata[table].tableName
    return new TableWriter(this,tableName,this.statementCache[tableName],this.status,this.yadamuLogger);      
  }
  
  async insertBatch(sqlStatement,batch) {
    if (this.status.sqlTrace) {
      this.status.sqlTrace.write(`${sqlStatement};\n--\n`);
    }
    const result = await this.pgClient.query(sqlStatement,batch)
    return result;
  }
  
  async finalizeDataLoad() {
  }  

}

module.exports = PostgresDBI
