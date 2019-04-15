"use strict" 
const fs = require('fs');
const Readable = require('stream').Readable;

/* 
**
** Require Database Vendors API 
**
*/

const Yadamu = require('./yadamu.js');
const DBParser = require('./dbParser.js');

/*
**
** YADAMU Database Inteface class 
**
*/

class YadamuDBI {
    
  get DATABASE_VENDOR() { return undefined };
  get SOFTWARE_VENDOR() { return undefined };
  get SPATIAL_FORMAT()  { return undefined };
  
  setConnectionProperties(connectionProperties) {
    this.connectionProperties = connectionProperties
  }

  getConnectionProperties() {
    this.connectionProperties = {}
  }
  
  isValidDDL() {
    return (this.systemInformation.vendor === this.DATABASE_VENDOR)
  }
  
  isDatabase() {
    return true;
  }
  
  objectMode() {
    return true;
  }
  
  setSystemInformation(systemInformation) {
    this.systemInformation = systemInformation
  }
  
  setMetadata(metadata) {
    this.metadata = metadata
  }
  
  async executeDDL(schema, ddl) {
    await Promise.all(ddl.map(async function(ddlStatement) {
      try {
        ddlStatement = ddlStatement.replace(/%%SCHEMA%%/g,schema);
        if (this.status.sqlTrace) {
          this.status.sqlTrace.write(`${ddlStatement};\n--\n`);
        }
        this.executeSQL(ddlStatement,{});
      } catch (e) {
        this.logWriter.write(`${e}\n${tableInfo.ddl}\n`)
      } 
    },this))
  }
    
  constructor(yadamu,defaultParameters) {
    this.yadamu = yadamu;
    this.parameters = yadamu.mergeParameters(defaultParameters);
    this.status = yadamu.getStatus()
    this.logWriter = yadamu.getLogWriter();
    
    this.systemInformation = undefined;
    this.metadata = undefined;

    this.connectionProperties = this.getConnectionProperties()   
    this.connection = undefined;

    this.statementCache = undefined;
 
    this.tableName  = undefined;
    this.tableInfo  = undefined;
    this.insertMode = 'Empty';
    this.skipTable = true;
  }
  
  /*  
  **
  **  Connect to the database. Set global setttings
  **
  */
  
  async initialize(schema) {
    if (this.status.sqlTrace) {
       if (this.status.sqlTrace._writableState.ended === true) {
         this.status.sqlTrace = fs.createWriteStream(this.status.sqlTrace.path,{"flags":"a"})
       }
    }
  }

  /*
  **
  **  Gracefully close down the database connection.
  **
  */

  async finalize() {
    throw new Error('Unimplemented Method')
  }

  /*
  **
  **  Abort the database connection.
  **
  */

  async abort() {
    throw new Error('Unimplemented Method')
  }

  /*
  **
  ** Commit the current transaction
  **
  */
  
  async commitTransaction() {
    throw new Error('Unimplemented Method')
  }

  /*
  **
  ** Abort the current transaction
  **
  */
  
  async rollbackTransaction() {
    throw new Error('Unimplemented Method')
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
  
  async uploadFile(importFilePath) {
    throw new Error('Unimplemented Method')
  }
  
  /*
  **
  **  Process a JSON File that has been uploaded to the server. 
  **
  */

  async processFile(mode,schema,hndl) {
    throw new Error('Unimplemented Method')
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
  
  async getSystemInformation(schema,EXPORT_VERSION) {     
    throw new Error('Unimplemented Method')
  }

  /*
  **
  **  Generate a set of DDL operations from the metadata generated by an Export operation
  **
  */

  async getDDLOperations(schema) {
    return undefined
  }
  
  async getSchemaInfo(schema) {
    return []
  }

  generateMetadata(tableInfo,server) {    
    return {}
  }
   
  generateSelectStatement(tableMetadata) {
     return tableMetadata;
  }   

  createParser(query,objectMode) {
    return new DBParser(query,objectMode,this.logWriter);      
  }
  
  async getInputStream(query,parser) {
    throw new Error('Unimplemented Method')
  }      

  /*
  **
  ** The following methods are used by the YADAMU DBwriter class
  **
  */
  
  async initializeDataLoad(schema) {
    throw new Error('Unimplemented Method')
  }
  
  async generateStatementCache(StatementGenerator,schema,executeDDL) {
    const statementGenerator = new StatementGenerator(this,this.parameters.BATCHSIZE,this.parameters.COMMITSIZE);
    this.statementCache = await statementGenerator.generateStatementCache(schema, this.metadata, executeDDL,this.systemInformation.vendor)
  }

  getTableWriter(TableWriter,schema,table) {
    const tableName = this.metadata[table].tableName  
    return new TableWriter(this,schema,tableName,this.statementCache[tableName],this.status,this.logWriter);      
  }
 
  async finalizeDataLoad() {
    throw new Error('Unimplemented Method')
  }  

}

module.exports = YadamuDBI
