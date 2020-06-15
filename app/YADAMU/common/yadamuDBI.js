"use strict" 
const fs = require('fs');
const path = require('path');
const Readable = require('stream').Readable;
const util = require('util')
const { performance } = require('perf_hooks');const async_hooks = require('async_hooks');

/* 
**
** Require Database Vendors API 
**
*/

const YadamuLibrary = require('./yadamuLibrary.js');
const {YadamuError, CommandLineError, ConfigurationFileError, ConnectionError, DatabaseError} = require('./yadamuError.js');
const DefaultParser = require('./defaultParser.js');

const DEFAULT_BATCH_SIZE   = 10000;
const DEFAULT_COMMIT_RATIO = 1;

/*
**
** YADAMU Database Inteface class 
**
**
*/

class YadamuDBI {
    
  get PASSWORD_KEY_NAME()   { return 'password' };
  get DATABASE_VENDOR()     { return undefined };
  get SOFTWARE_VENDOR()     { return undefined };
  get SPATIAL_FORMAT()      { return spatialFormat };
  get EXPORT_VERSION()      { return this.yadamu.EXPORT_VERSION }
  get DEFAULT_PARAMETERS()  { return this.yadamu.getYadamuDefaults().yadmuDBI }
  get STATEMENT_TERMINATOR() { return '' }
  
  traceSQL(msg) {
     // this.yadamuLogger.trace([this.DATABASE_VENDOR,'SQL'],msg)
     return(`${msg.trim()}${this.sqlTraceTag} ${this.sqlTerminator}`);
  }
  
  traceTiming(startTime,endTime) {      
    const sqlOperationTime = endTime - startTime;
    if (this.status.sqlTrace) {
      this.status.sqlTrace.write(`--\n--${this.sqlTraceTag} Elapsed Time: ${YadamuLibrary.stringifyDuration(sqlOperationTime)}s.\n--\n`);
    }
    this.sqlCumlativeTime = this.sqlCumlativeTime + sqlOperationTime
  }
 
  traceComment(comment) {
    return `/* ${comment} */\n`
  }
  
  doTimeout(milliseconds) {
    
	return new Promise((resolve,reject) => {
        this.yadamuLogger.info([`${this.constructor.name}.doTimeout()`],`Sleeping for ${YadamuLibrary.stringifyDuration(milliseconds)}ms.`);
        setTimeout(
          () => {
           this.yadamuLogger.info([`${this.constructor.name}.doTimeout()`],`Awake.`);
           resolve();
          },
          milliseconds
       )
     })  
  }
 
  decomposeDataType(targetDataType) {
    
    const results = {};
    let components = targetDataType.split('(');
    results.type = components[0].split(' ')[0];
    if (components.length > 1 ) {
      components = components[1].split(')');
      if (components.length > 1 ) {
        results.qualifier = components[1]
      }
      components = components[0].split(',');
      if (components.length > 1 ) {
        results.length = parseInt(components[0]);
        results.scale = parseInt(components[1]);
      }
      else {
        if (components[0] === 'max') {
          results.length = -1;
        }
        else {
          results.length = parseInt(components[0])
        }
      }
    }           
    return results;      
    
  } 
  
  decomposeDataTypes(targetDataTypes) {
     return targetDataTypes.map((targetDataType) => {
       return this.decomposeDataType(targetDataType)
     })
  }
  
  processError(yadamuLogger,logEntry,summary,logDDL) {
	 
	let warning = true;
	  
    switch (logEntry.severity) {
      case 'CONTENT_TOO_LARGE' :
        yadamuLogger.error([`${this.DATABASE_VENDOR}`,`${logEntry.severity}`,`${logEntry.tableName ? logEntry.tableName : ''} `],`This database does not support VARCHAR2 values longer than ${this.maxStringSize} bytes.`)
        return;
      case 'SQL_TOO_LARGE':
        yadamuLogger.error([`${this.DATABASE_VENDOR}`,`${logEntry.severity}`,`${logEntry.tableName ? logEntry.tableName : ''} `],`This database is not configured for DLL statements longer than ${this.maxStringSize} bytes.`)
        return;
      case 'FATAL':
        summary.errors++
		const err =  new Error(logEntry.msg)
		err.SQL = logEntry.sqlStatement
		err.details = logEntry.details
		summary.exceptions.push(err)
        // yadamuLogger.error([`${this.DATABASE_VENDOR}`,`${logEntry.severity}`,`${logEntry.tableName ? logEntry.tableName : ''}`],`Details: ${logEntry.msg}\n${logEntry.details}\n${logEntry.sqlStatement}`)
        return
      case 'WARNING':
        summary.warnings++
        break;
      case 'IGNORE':
        summary.warnings++
        break;
      case 'DUPLICATE':
        summary.duplicates++
        break;
      case 'REFERENCE':
        summary.reference++
        break;
      case 'AQ RELATED':
        summary.aq++
        break;
      case 'RECOMPILATION':
        summary.recompilation++
        break;
      default:
	    warning = false
    }
    if (logDDL) { 
	  if (warning) {
        yadamuLogger.warning([`${this.DATABASE_VENDOR}`,`${logEntry.severity}`,`${logEntry.tableName ? logEntry.tableName : ''}`],`Details: ${logEntry.msg}\n${logEntry.details}${logEntry.sqlStatement}`)
	  }
	  else {
        yadamuLogger.ddl([`${this.DATABASE_VENDOR}`,`${logEntry.severity}`,`${logEntry.tableName ? logEntry.tableName : ''}`],`Details: ${logEntry.msg}\n${logEntry.details}${logEntry.sqlStatement}`)
	  }
	}
  }
          
  processLog(log, operation, status,yadamuLogger) {

    const logDML         = (status.loglevel && (status.loglevel > 0));
    const logDDL         = (status.loglevel && (status.loglevel > 1));
    const logDDLMsgs     = (status.loglevel && (status.loglevel > 2));
    const logTrace       = (status.loglevel && (status.loglevel > 3));

    if (status.dumpFileName) {
      fs.writeFileSync(status.dumpFileName,JSON.stringify(log));
    }
     
    const summary = {
       errors        : 0
      ,warnings      : 0
      ,ignoreable    : 0
      ,duplicates    : 0
      ,reference     : 0
      ,aq            : 0
      ,recompilation : 0
	  ,exceptions    : []
    };
      	  
	log.forEach((result) => { 
      const logEntryType = Object.keys(result)[0];
      const logEntry = result[logEntryType];
      switch (true) {
        case (logEntryType === "message") : 
          yadamuLogger.info([`${this.DATABASE_VENDOR}`],`${logEntry}.`)
          break;
        case (logEntryType === "dml") : 
          yadamuLogger.info([`${logEntry.tableName}`,`SQL`],`Rows ${logEntry.rowCount}. Elaspsed Time ${YadamuLibrary.stringifyDuration(Math.round(logEntry.elapsedTime))}s. Throughput ${Math.round((logEntry.rowCount/Math.round(logEntry.elapsedTime)) * 1000)} rows/s.`)
          break;
        case (logEntryType === "info") :
          yadamuLogger.info([`${this.DATABASE_VENDOR}`],`"${JSON.stringify(logEntry)}".`);
          break;
        case (logDML && (logEntryType === "dml")) :
          yadamuLogger.dml([`${this.DATABASE_VENDOR}`,`${logEntry.tableName}`,`${logEntry.tableName}`],`\n${logEntry.sqlStatement}.`)
          break;
        case (logDDL && (logEntryType === "ddl")) :
          yadamuLogger.ddl([`${this.DATABASE_VENDOR}`,`${logEntry.tableName}`],`\n${logEntry.sqlStatement}.`) 
          break;
        case (logTrace && (logEntryType === "trace")) :
          yadamuLogger.trace([`${this.DATABASE_VENDOR}`,`${logEntry.tableName ? logEntry.tableName : ''}`],`\n${logEntry.sqlStatement}.`)
          break;
        case (logEntryType === "error"):
		  this.processError(yadamuLogger,logEntry,summary,logDDLMsgs);
      } 
      if ((status.sqlTrace) && (logEntry.sqlStatement)) { 
        status.sqlTrace.write(this.traceSQL(logEntry.sqlStatement))
      }
    }) 
	
    if (summary.exceptions.length > 0) {
  	  const err = new Error(`${this.DATABASE_VENDOR} ${operation} failed.`);
	  err.causes = summary.exceptions
      throw err
    }
	return summary;
  }    

  logConnectionProperties() {    
    if (this.status.sqlTrace) {
      const pwRedacted = Object.assign({},this.connectionProperties)
      delete pwRedacted.password
      this.status.sqlTrace.write(this.traceComment(`Connection Properies: ${JSON.stringify(pwRedacted)}`))
    }
  }
     
  setConnectionProperties(connectionProperties) {
    if (Object.getOwnPropertyNames(connectionProperties).length > 0) {    
      this.connectionProperties = connectionProperties 
    }
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
  
  setCounters(counters) {
	// Share counteres with the Writer so adjustments can be made if the connection is lost.
    this.counters = counters
  }
  
  trackLostConnection() {
   
    /*
    **
    ** Invoked by the DBI when the connection is lost. Assume a rollback took place. Any rows written but not committed are lost. 
    **
    */

  	if ((this.counters !== undefined) && (this.counters.lost  !== undefined) && (this.counters.written  !== undefined)) {
      this.counters.lost += this.counters.written;
	  this.counters.written = 0;
	}
  }	  
  
  setSystemInformation(systemInformation) {
    this.systemInformation = systemInformation
  }
  
  setMetadata(rawMetadata) {

    /*
	**
	** Apply current tableMappings to the metadata
    ** Check the result does not required further transformation	
	** Apply additional transformations as required
	**
	*/

    const patchedMetadata = this.tableMappings ? this.applyTableMappings(rawMetadata,this.tableMappings) : rawMetadata
	const generatedMappings = this.validateIdentifiers(patchedMetadata)
    // ### TODO Improve logic for merging generatedMappings with existing tableMappings - Make sure column mappings are merged correctly
    this.setTableMappings((this.tableMappings || generatedMappings) ? Object.assign({},this.tableMappings,generatedMappings) : undefined)
	this.metadata = this.tableMappings ? this.applyTableMappings(patchedMetadata,this.tableMappings) : patchedMetadata
	
  }
  
  setParameters(parameters) {
     Object.assign(this.parameters, parameters ? parameters : {})
     this.attemptReconnection = this.setReconnectionState()
  }
  
  /*
  **
  ** ### TABLE MAPPINGS ###
  **
  ** Some databases have restrictions on the length of names or the characters that can appear in names
  ** Table Mappings provide a mechanism to map non-compliant names to compliant names. Mappings apply to both table names and column names.
  **
  ** The application of Table Mappings is bi-directional. When importing data the DBI should apply Table Mappings to table names and columns names
  ** before attempting to insert data into a database. When exporting data the DBI should apply TableMappings to a the content of the metadata and 
  ** data objects generated by the export process.
  ** 
  ** Table Mappings are not applied when generating DDL statements as part of an export operation or when processing DDL statements during an import operation
  **
  ** Most YADAMU interfaces will generate conforming names from unconformrnt names by truncation. Truncation is a very crude solution
  ** as it can lead to clashes, and meaningless names. The preferred solution is to provide a mappings that contains the desired mappings.
  **
  ** function setTableMappings() sets the TableMappings object to be used by the DBI
  **
  ** function loadMappingsFile() loads the TableMappings object from a file disk. The file is specified using the TABLE_MAPPINGS parameter.
  ** 
  ** function validateIdentifiers() is a placeholder that the DBI can override if it needs to validate identifiers and generate a TableMappings object
  ** The default function returns undefined indicating that no mappings are required.
  ** 
  ** function getTableMappings() returns the current TableMappings object
  **
  ** function reverseTableMappings() generates the inverse mappings for a given TableMappings object. Mappings supplied to the DBI are treated as inbound. 
  ** E.g. they map names generated by external sources to names that compliant with the target database. 
  **
  ** function transformMetadata() uses a reversed TableMappings object to modify the contents of metadata objects emitted by the DBI during an export operation.
  **
  ** function transformTableName() uses a reversed TableMappings object to modify the contes of talbe objects emitted by the DBI during an export operations
  **
  */

  setTableMappings(tableMappings) {
    this.tableMappings = tableMappings
	this.inverseTableMappings = this.reverseTableMappings(tableMappings)
  }
  
  loadTableMappings(mappingFile) {
    this.setTableMappings(require(path.resolve(mappingFile)))
  }

  validateIdentifiers(metadata) {
	this.setTableMappings(undefined)
  }
  
  getTableMappings() {
	return this.tableMappings
  }

  getInverseTableMappings() {
	return this.inverseTableMappings
  }

  reverseTableMappings(tableMappings) {

    if (tableMappings) {
      const reverseMappings = {}
      Object.keys(tableMappings).forEach((table) => {
        const newKey = tableMappings[table].tableName
        reverseMappings[newKey] = { "tableName" : table};
        if (tableMappings[table].columns) {
          const columns = {};
          Object.keys(tableMappings[table].columns).forEach((column) => {
            const newKey = tableMappings[table].columns[column]
            columns[newKey] = column;
          });
          reverseMappings[newKey].columns = columns
        }
      })
      return reverseMappings;
    }
    return tableMappings;
  }
    
  applyTableMappings(metadata,mappings) {
	  
	// This function does not change the names of the keys in the metadata object.
	// It only changes the value of the tableName property associated with a mapped tables.
	  
    const tables = Object.keys(metadata).map((key) => {
      return metadata[key].tableName
	})
    tables.forEach((table) => {
      const tableMappings = mappings[table]
      if (tableMappings) {
        this.yadamuLogger.info([this.DATABASE_VENDOR,metadata[table].tableName],`Mapped to "${tableMappings.tableName}".`)
        metadata[table].tableName = tableMappings.tableName
		if (tableMappings.columns) {
          const columns = JSON.parse('[' + metadata[table].columns + ']');
          Object.keys(tableMappings.columns).forEach((columnName) => {
            const idx = columns.indexOf(columnName);
            if (idx > -1) {
              this.yadamuLogger.info([this.DATABASE_VENDOR,metadata[table].tableName,columnName],`Mapped to "${ tableMappings.columns[columnName]}".`)
              columns[idx] = tableMappings.columns[columnName]                
            }
          });
          metadata[table].columns = '"' + columns.join('","') + '"';
        }
      }   
    });
    return metadata	
  }
  
  transformTableName(tableName,mappings) {
	return (mappings && mappings.hasOwnProperty(tableName)) ? mappings[tableName].tableName : tableName
  }
  
  transformMetadata(metadata,mappings) {
    if (mappings) {
      const mappedMetadata = this.applyTableMappings(metadata,mappings)
	  const outboundMetadata = {}
	  Object.keys(mappedMetadata).forEach((tableName) => { outboundMetadata[this.transformTableName(tableName,mappings)] = mappedMetadata[tableName] })
	  return outboundMetadata
	  console.log(ouboundMetadata)
	}
	else {
      return metadata
	}
  }
	  
  async executeDDLImpl(ddl) {
    await Promise.all(ddl.map(async (ddlStatement) => {
      try {
        ddlStatement = ddlStatement.replace(/%%SCHEMA%%/g,this.parameters.TO_USER);
        if (this.status.sqlTrace) {
          this.status.sqlTrace.write(this.traceSQL(ddlStatement));
        }
        this.executeSQL(ddlStatement,{});
      } catch (e) {
        this.yadamuLogger.logException([`${this.constructor.name}.executeDDL()`],e)
        this.yadamuLogger.writeDirect(`${ddlStatement}\n`)
      } 
    }))
  }
  
  async executeDDL(ddl) {
	if (ddl.length > 0) {
      const startTime = performance.now();
      await this.executeDDLImpl(ddl);
      this.yadamuLogger.ddl([`${this.DATABASE_VENDOR}`],`Executed ${ddl.length} DDL statements. Elapsed time: ${YadamuLibrary.stringifyDuration(performance.now() - startTime)}s.`);
	}
  }
  
  setOption(name,value) {
    this.options[name] = value;
  }
    
  initializeParameters(parameters) {
    
    // In production mode the Databae default parameters are merged with the command Line Parameters loaded by YADAMU.

    this.parameters = this.yadamu.cloneDefaultParameters();
    
    // Merge parameters from configuration files
    Object.assign(this.parameters, parameters ? parameters : {})

    // Merge Command line arguments
    Object.assign(this.parameters, this.yadamu.getCommandLineParameters());
    
  }
  
  constructor(yadamu,parameters) {
    
    this.options = {
      recreateTargetSchema : false
    }
    
    this.spatialFormat = this.SPATIAL_FORMAT 
    this.yadamu = yadamu;
    this.sqlTraceTag = '';
    this.status = yadamu.getStatus()
    this.yadamuLogger = yadamu.getYadamuLogger();
    this.initializeParameters(parameters);
    this.systemInformation = undefined;
    this.metadata = undefined;
    this.attemptReconnection = this.setReconnectionState()
    this.connectionProperties = this.getConnectionProperties()   
    this.connection = undefined;

    this.statementCache = undefined;
	
	// Track Transaction and Savepoint state.
	// Needed to restore transacation state when reconnecting.
	
	this.transactionInProgress = false;
	this.savePointSet = false;
 
    this.tableName  = undefined;
    this.tableInfo  = undefined;
    this.insertMode = 'Empty';
    this.skipTable = true;

    this.setTableMappings(undefined);
    if (this.parameters.MAPPINGS) {
      this.loadTableMappings(this.parameters.MAPPINGS);
    }   
 
    this.sqlTraceTag = `/* Primary */`;	
    this.sqlCumlativeTime = 0
    this.sqlTerminator = `\n${this.STATEMENT_TERMINATOR}\n`
  }

  enablePerformanceTrace() { 
    const self = this;
    this.asyncHook = async_hooks.createHook({
      init(asyncId, type, triggerAsyncId, resource) {self.reportAsyncOperation(asyncId, type, triggerAsyncId, resource)}
    }).enable();
  }

  reportAsyncOperation(...args) {
     fs.writeFileSync(this.parameters.PERFORMANCE_TRACE, `${util.format(...args)}\n`, { flag: 'a' });
  }
  
  async getDatabaseConnectionImpl() {
    try {
      await this.createConnectionPool();
      this.connection = await this.getConnectionFromPool();
      await this.configureConnection();
    } catch (e) {
      const err = new ConnectionError(e,this.connectionProperties);
      throw err
    }

  }  

  waitForRestart(delayms) {
    return new Promise((resolve, reject) => {
        setTimeout(resolve, delayms);
    });
  }
  
  setReconnectionState() {
     
    switch (this.parameters.ON_ERROR) {
	  case undefined:
	  case 'ABORT':
		return false;
	  case 'SKIP':
	  case 'FLUSH':
	    return true;
	  default:
	    return false;
	}
  }
  
  abortOnError() {
	return !this.attemptReconnection
  }
    
  async reconnectImpl() {
    throw new Error(`Database Reconnection Not Implimented for ${this.DATABASE_VENDOR}`)
	
	// Default code for databases that support reconnection
    this.connection = this.isPrimary() ? await this.getConnectionFromPool() : await this.connectionProvider.getConnectionFromPool()

  }
  
  async reconnect(cause,operation) {

    let retryCount = 0;
    let connectionUnavailable 
    
    const transactionInProgress = this.transactionInProgress 
    const savePointSet = this.savePointSet
	
	this.attemptReconnection = false
    this.reconnectInProgress = true;
	this.yadamuLogger.handleException([`${this.DATABASE_VENDOR}`,`${operation}`],cause)
	
	/*
	**
	** If a connection is lost while performing batched insert operatons using a table writer, adjust the table writers running total of records written but not committed. 
	** When a connection is lost records that have written but not committed will be lost (rolled back by the database) when cleaning up after the lost connection.
	** Table Writers invoke trackCounters and pass a counter object to the database interface before consuming rows in order for this to work correctly.
	** To avoid the possibility of lost batches set COMMIT_RATIO to 1, so each batch is committed as soon as it is written.
	**
	*/
	
    this.trackLostConnection();
	
    while (retryCount < 10) {
		
      /*
      **
      ** Attempt to close the connection. Handle but do not throw any errors...
      **
      */	
	
	  try {
        await this.closeConnection()
      } catch (e) {
	    if (!e.invalidConnection()) {
          this.yadamuLogger.info([`${this.DATABASE_VENDOR}`,`RECONNECT`],`Error closing existing connection.`);
		  this.yadamuLogger.handleException([`${this.DATABASE_VENDOR}`,`RECONNECT`],e)
	    }
	  }	 
		 
	  try {
        this.yadamuLogger.info([`${this.DATABASE_VENDOR}`,`RECONNECT`],`Attemping reconnection.`);
        await this.reconnectImpl()
	    await this.configureConnection();
		if (transactionInProgress) {
		  await this.beginTransaction()
		}
		if (savePointSet) {
		  await this.createSavePoint()
		}
        this.reconnectInProgress = false;
        this.yadamuLogger.info([`${this.DATABASE_VENDOR}`,`RECONNECT`],`New connection available.`);
        this.attemptReconnection = this.setReconnectionState()
		return;
      } catch (connectionFailure) {
		if ((typeof connectionFailure.serverUnavailable == 'function') && connectionFailure.serverUnavailable()) {
		  connectionUnavailable = connectionFailure;
          this.yadamuLogger.info([`${this.DATABASE_VENDOR}`,`RECONNECT`],`Waiting for restart.`)
          await this.waitForRestart(5000);
          retryCount++;
        }
        else {
   	      this.reconnectInProgress = false;
          this.yadamuLogger.handleException([`${this.DATABASE_VENDOR}`,`RECONNECT`],connectionFailure);
          this.attemptReconnection = this.setReconnectionState()
          throw connectionFailure;
        }
      }
    }
    // this.yadamuLogger.trace([`${this.constructor.name}.reconnectImpl()`],`Unable to re-establish connection.`)
    this.reconnectInProgress = false;
    this.attemptReconnection = this.setReconnectionState()
    throw connectionUnavailable 	
  }
  
  async getDatabaseConnection(requirePassword) {
                
    let interactiveCredentials = (requirePassword && ((this.connectionProperties[this.PASSWORD_KEY_NAME] === undefined) || (this.connectionProperties[this.PASSWORD_KEY_NAME].length === 0))) 
    let retryCount = interactiveCredentials ? 3 : 1;
    
    let prompt = `Enter password for ${this.DATABASE_VENDOR} connection: `
    while (retryCount > 0) {
      retryCount--
      if (interactiveCredentials)  {
        const pwQuery = this.yadamu.createQuestion(prompt);
        const password = await pwQuery;
        this.connectionProperties[this.PASSWORD_KEY_NAME] = password;
      }
      try {
        await this.getDatabaseConnectionImpl()  
        return;
      } catch (e) {     
        switch (retryCount) {
          case 0: 
            if (interactiveCredentials) {
              throw new CommandLineError(`Unable to establish connection to ${this.DATABASE_VENDOR} after 3 attempts. Operation aborted.`);
              break;
            }
            else {
              throw (e)
            }
            break;
          case 1:
            console.log(`Connection Error: ${e.message}`)
            break;
          case 2:           
            prompt = `Unable to establish connection. Re-${prompt}`;
            console.log(`Database Error: ${e.message}`)
            break;
          default:
            throw e
        }
      } 
    }
  }
    
  /*  
  **
  **  Connect to the database. Set global setttings
  **
  */

  async initialize(requirePassword) {

    if (this.status.sqlTrace) {
       if (this.status.sqlTrace._writableState.ended === true) {
         this.status.sqlTrace = fs.createWriteStream(this.status.sqlTrace.path,{"flags":"a"})
       }
    }
    
    /*
    **
    ** Calculate CommitSize
    **
    */
    
    let batchSize = this.parameters.BATCH_SIZE ? Number(this.parameters.BATCH_SIZE) : DEFAULT_BATCH_SIZE
    batchSize = isNaN(batchSize) ? DEFAULT_BATCH_SIZE : batchSize
    batchSize = batchSize < 0 ? DEFAULT_BATCH_SIZE : batchSize
    batchSize = !Number.isInteger(batchSize) ? DEFAULT_BATCH_SIZE : batchSize
    this.batchSize = batchSize
    
    let commitCount = this.parameters.COMMIT_RATIO ? Number(this.parameters.COMMIT_RATIO) : DEFAULT_COMMIT_RATIO
    commitCount = isNaN(commitCount) ? DEFAULT_COMMIT_RATIO : commitCount
    commitCount = commitCount < 0 ? DEFAULT_COMMIT_RATIO : commitCount
    commitCount = !Number.isInteger(commitCount) ? DEFAULT_COMMIT_RATIO : commitCount
    this.commitSize = this.batchSize * commitCount
    
    if (this.parameters.PARAMETER_TRACE === true) {
      this.yadamuLogger.writeDirect(`${util.inspect(this.parameters,{colors:true})}\n`);
    }
    
    if (this.parameters.PERFORMANCE_TRACE) {
      this.enablePerformanceTrace();
    }
    
    if (this.isDatabase()) {
      await this.getDatabaseConnection(requirePassword);
    }
  }

  /*
  **
  **  Gracefully close down the database connection and pool.
  **
  */

  async releaseWorkerConnection() {
	await this.closeConnection()
  }

  async releasePrimaryConnection() {
	// Defer until finalize()
	// await this.closeConnection()
  }
  
  async finalize(poolOptions) {
	await this.closeConnection()
    await this.closePool(poolOptions);
  }

  /*
  **
  **  Abort the database connection and pool
  **
  */

  async abort(poolOptions) {
	
	// Abort must not throw otherwise underlying cause of the abort will be lost.
	
    try {
      await this.closeConnection();
	} catch (e) {
	  if ((e instanceof DatabaseError) && !e.invalidConnection()) {
        this.yadamuLogger.handleException([`${this.DATABASE_VENDOR}`,'ABORT','Connection'],e);
	  }
	}
	
    try {
	  // Force Termnination of All Current Connections.
	  await this.closePool(poolOptions);
	} catch (e) {
	  if ((e instanceof DatabaseError) && !e.invalidPool()) {
        this.yadamuLogger.handleException([`${this.DATABASE_VENDOR}`,'ABORT','Pool'],e);
	  }
	}
	
  }
  
  checkConnectionState(cause) {
	 
	// Throw cause if cause is a lost connection. Used by drivers to prevent attempting rollback or restore save point operations when the connection is lost.
	  
  	if (cause && (typeof cause.lostConnection === 'function') && cause.lostConnection()) {
	  throw cause;
	}
  }

  checkCause(cause,newError) {
	 
	 // Used by Rollback and Restore save point to log errors encountered while performing the required operation and throw the original cause.

	  if (cause instanceof Error) {
        this.yadamuLogger.handleException([`${this.constructor.name}.rollbackTransaction()`],newError)
	    throw cause
	  }
	  throw newError
  }

  /*
  **
  ** Begin the current transaction
  **
  */
  
  beginTransaction() {
    this.transactionInProgress = true;  
	this.savePointSet = false;
  }

  /*
  **
  ** Commit the current transaction
  **
  */
    
  commitTransaction() {
	this.transactionInProgress = false;  
	this.savePointSet = false;
  }

  /*
  **
  ** Abort the current transaction
  **
  */
  
  rollbackTransaction(cause) {
	this.transactionInProgress = false;  
	this.savePointSet = false;
  }
  
  /*
  **
  ** Set a Save Point
  **
  */
    
  createSavePoint() {
	this.savePointSet = true;
  }

  /*
  **
  ** Revert to a Save Point
  **
  */

  restoreSavePoint(cause) {
	this.savePointSet = false;
  }

  releaseSavePoint(cause) {
	this.savePointSet = false;
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

  async processFile(hndl) {
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
  
  async getSystemInformation() {     
    throw new Error('Unimplemented Method')
  }

  /*
  **
  **  Generate a set of DDL operations from the metadata generated by an Export operation
  **
  */

  async getDDLOperations() {
    // Undefined means database does not provide mechanism to obtain DDL statements. Different to returning an empty Array.
    return undefined
  }
  
  async getSchemaInfo() {
    return []
  }

  generateMetadata(tableInfo,server) {    
    return {}
  }
   
  generateSelectStatement(tableMetadata) {
     return tableMetadata;
  }   

  createParser(query,objectMode) {
    return new DefaultParser(query,objectMode,this.yadamuLogger);      
  }
  
  forceEndOnInputStreamError(error) {
	return false;
  }
  
  streamingError(e,stack,tableInfo) {
    return new DatabaseError(e,stack,tableInfo.SQL_STATEMENT)
  }
  
  async getInputStream(tableInfo,parser) {
    throw new Error('Unimplemented Method')
  }      

  freeInputStream(inputStream){
  }

  /*
  **
  ** The following methods are used by the YADAMU DBwriter class
  **
  */
  
  async initializeExport() {
  }
  
  async finalizeExport() {
  }
  
  /*
  **
  ** The following methods are used by the YADAMU DBWriter class
  **
  */
  
  async initializeImport() {
  }
  
  async initializeData() {
  }
  
  async finalizeData() {
  }

  async finalizeImport() {
  }
    
  async generateStatementCache(StatementGenerator,schema,executeDDL) {
	const statementGenerator = new StatementGenerator(this,schema,this.metadata,this.systemInformation.spatialFormat,this.batchSize, this.commitSize, this.status, this.yadamuLogger);
    this.statementCache = await statementGenerator.generateStatementCache(executeDDL,this.systemInformation.vendor)
  }

  async finalizeRead(tableInfo) {
  }

  getTableWriter(TableWriter,table) {
    return new TableWriter(this,this.statementCache[tableName],this.status,this.yadamuLogger);
  }
  
  getTableInfo(tableName) {
	  
	 // Statement Cache is keyed by actual table name so we need the mapped name if there is a mapping.
	 
	 let mappedTableName = this.transformTableName(tableName,this.tableMappings)
	 // console.log(tableName,mappedTableName,this.tableMappings)
     const tableInfo = this.statementCache[mappedTableName]
	 tableInfo.tableName = mappedTableName
	 return tableInfo
  }
  
  getOutputStream(TableWriter,primary) {
    return new TableWriter(this,primary,this.status,this.yadamuLogger)
  }
  
  keepAlive(rowCount) {
  }

  configureTest(recreateSchema) {
    if (this.parameters.MAPPINGS) {
      this.loadTableMappings(this.parameters.MAPPINGS);
    }  
    if (this.parameters.SQL_TRACE) {
      this.status.sqlTrace = fs.createWriteStream(this.parameters.SQL_TRACE,{flags : "a"});
    }
    if (recreateSchema === true) {
      this.setOption('recreateSchema',true);
    }
  }
  
  async clonePrimary(dbi) {
	// dbi.master = this
	dbi.metadata = this.metadata
    dbi.schemaCache = this.schemaCache
    dbi.spatialFormat = this.spatialFormat
    dbi.statementCache = this.statementCache
    dbi.systemInformation = this.systemInformation
	dbi.setTableMappings(this.tableMappings)
    dbi.sqlTraceTag = ` /* Worker [${this.getWorkerNumber()}] */`;
  }   

  async setWorkerConnection() {
    // DBI implementations that do not use a pool / connection mechansim need to overide this function. eg MSSQLSERVER
	this.connection = await this.connectionProvider.getConnectionFromPool()	
  }

  isPrimary() {

    return (this.workerNumber === undefined)
   
  }

  getWorkerNumber() {

    return this.isPrimary() ? 'Primary' : this.workerNumber

  }
  
  async workerDBI(workerNumber,dbi) {
      
    // Invoked on the DBI that is being cloned. Parameter dbi is the cloned interface.
      
    dbi.workerNumber = workerNumber
	dbi.connectionProvider = this
	await dbi.setWorkerConnection()
    dbi.setParameters(this.parameters);
	this.clonePrimary(dbi);
    await dbi.configureConnection();
	return dbi
  }
  
  testLostConnection() {
	const supportedModes = ['DATA_ONLY','DDL_AND_DATA']
    return (
	         (supportedModes.indexOf(this.parameters.MODE) > -1)
	         && 
			 (
			   ((this.parameters.PARALLEL === undefined) || (this.parameters.PARALLEL < 1))
			   ||
			   ((this.parameters.PARALLEL > 1) && (this.workerNumber !== undefined) && (this.workerNumber === this.parameters.KILL_WORKER_NUMBER))
			 )
			 && 
			 (
		       (this.parameters.FROM_USER && this.parameters.KILL_READER_AFTER && (this.parameters.KILL_READER_AFTER > 0)) 
		       || 
			   (this.parameters.TO_USER && this.parameters.KILL_WRITER_AFTER && (this.parameters.KILL_WRITER_AFTER > 0))
		     )
		   ) === true
  }

  
  async getConnectionID() {
	// ### Get a Unique ID for the connection
    throw new Error('Unimplemented Method')
  }
  
  
}

module.exports = YadamuDBI
