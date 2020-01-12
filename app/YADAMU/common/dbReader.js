"use strict";
const Readable = require('stream').Readable;
const Yadamu = require('./yadamu.js')
const YadamuLibrary = require('./yadamuLibrary.js')
const { performance } = require('perf_hooks');

class DBReader extends Readable {  

  constructor(dbi,mode,status,yadamuLogger,options) {

    super({objectMode: true });  
    const self = this;
 
    this.dbi = dbi;
    this.mode = mode;
    this.status = status;
    this.yadamuLogger = yadamuLogger;
    this.yadamuLogger.log([`${this.constructor.name}`,`${dbi.DATABASE_VENDOR}`],`Ready. Mode: ${this.mode}.`)
       
    this.schemaInfo = [];
    
    this.nextPhase = 'systemInformation'
    this.ddlCompleted = false;
    this.outputStream = undefined;

  }
  
  pipe(target,options) {
    this.outputStream = super.pipe(target,options);
	return this.outputStream;
  } 
  
  async initialize() {
	await this.dbi.initializeExport() 
  }
  
  async getSystemInformation(version) {
    return this.dbi.getSystemInformation(version)
  }
  
  async getDDLOperations() {
	const startTime = performance.now();
    const ddl = await this.dbi.getDDLOperations()
	if (ddl !== undefined) {
      this.yadamuLogger.info([`${this.dbi.constructor.name}.getDDLOperations()`],`Generated ${ddl.length} DDL statements. Elapsed time: ${YadamuLibrary.stringifyDuration(performance.now() - startTime)}s.`);
	}
	return ddl
  }
  
  async getMetadata() {
      
     this.schemaInfo = await this.dbi.getSchemaInfo('FROM_USER')
     return this.dbi.generateMetadata(this.schemaInfo)
  }
      
  async copyContent(tableMetadata,outputStream) {
    
    const tableInfo = this.dbi.generateSelectStatement(tableMetadata)
    const parser = this.dbi.createParser(tableInfo,outputStream.objectMode())
    const inputStream = await this.dbi.getInputStream(tableInfo,parser)

    const self = this
    const copyOperation = new Promise(function(resolve,reject) {  
	
      const outputStreamError = function(err){
        // Named OnError Listener
		self.yadamuLogger.logException([`${self.constructor.name}.copyContent()`,`${tableMetadata.TABLE_NAME}`,`${this.constructor.name}.onError()`],err)
		reject(err)
	  }       
    
	  outputStream.on('error',
	    outputStreamError
	  );

      parser.on('end',
	    function(){
		  outputStream.removeListener('error',outputStreamError)
		  resolve(parser.getCounter())
	    }
	  )

	  parser.on('error',
	    function(err) {
		  reject(err)
        }
	  );

      const stack = new Error().stack;
	  inputStream.on('error',
	    function(err) { 
		  if (err.yadamuHandled === true) {
	        self.yadamuLogger.info([`${self.constructor.name}.copyOperation()`,`${tableMetadata.TABLE_NAME}`],`Rows read: ${parser.getCounter()}. Read Pipe Closed`)
	      } 
		  reject(self.dbi.processStreamingError(err,stack))
		}
      );
	  
	  try {
        inputStream.pipe(parser).pipe(outputStream,{end: false })
	  } catch (e) {
		this.yadamuLogger.logException([`${this.constructor.name}.copyContent()`,`${tableMetadata.TABLE_NAME}`,`PIPE`],e)
		throw e
	  }
    })
    
    const startTime = performance.now()
	try {
      const rows = await copyOperation;
      const elapsedTime = performance.now() - startTime
      this.yadamuLogger.info([`${this.constructor.name}`,`${tableMetadata.TABLE_NAME}`],`Rows read: ${rows}. Elaspsed Time: ${YadamuLibrary.stringifyDuration(elapsedTime)}s. Throughput: ${Math.round((rows/elapsedTime) * 1000)} rows/s.`)
      return rows;
	} catch(e) {
      this.yadamuLogger.logException([`${this.constructor.name}.copyContent()`,`${tableMetadata.TABLE_NAME}`,`COPY`],e);
	  throw e;
    }
      
  }
  
  async generateStatementCache(metadata) {
    if (Object.keys(metadata).length > 0) {   
      // ### if the import already processed a DDL object do not execute DDL when generating statements.
      Object.keys(metadata).forEach(function(table) {
         metadata[table].vendor = this.dbi.systemInformation.vendor;
      },this)
    }
    this.dbi.setMetadata(metadata)      
    await this.dbi.generateStatementCache('%%SCHEMA%%',false)
  }
  
  getInputStream() {
    if (this.dbi.isDatabase()) {
      // dbReader.js provides the ordered event stream for random (database based) readers.
      return this
    }
    else {
      // For File based readers the event stream is generated by the order of elements in the document beging parsed
      return this.dbi.getInputStream()
    }
  }
  
  async _read() {
    // Error().stack(new Date().toISOString(),`${this.constructor.name}.read`,this.nextPhase); 
    try {
       switch (this.nextPhase) {
         case 'systemInformation' :
           const systemInformation = await this.getSystemInformation(Yadamu.EXPORT_VERSION);
           // Needed in case we have to generate DDL from the system information and metadata.
           this.dbi.setSystemInformation(systemInformation);
           this.push({systemInformation : systemInformation});
           if (this.mode === 'DATA_ONLY') {
             this.nextPhase = 'metadata';
           }
           else { 
             this.nextPhase = 'ddl';
           }
           break;
         case 'ddl' :
           let ddl = await this.getDDLOperations();
           if (ddl === undefined) {
             // Database does not provide mechansim to retrieve DDL statements used to create a schema (eg Oracle's DBMS_METADATA package)
             // Reverse Engineer DDL from metadata.
             const metadata = await this.getMetadata();
             await this.generateStatementCache(metadata)
             ddl = Object.keys(this.dbi.statementCache).map(function(table) {
               return this.dbi.statementCache[table].ddl
             },this)
           } 
           this.push({ddl: ddl});
		   this.nextPhase = this.mode === 'DDL_ONLY' ? 'finished' : 'metadata';
           break;
         case 'metadata' :
           const metadata = await this.getMetadata();
           this.push({metadata: metadata});
		   this.nextPhase = this.schemaInfo.length === 0 ? 'finished' : 'data';
           break;   
         case 'data' :
		   const task = this.schemaInfo.shift();
		   // Only push once when finished
		   this.outputStream.write({table: task.TABLE_NAME})
           const rows = await this.copyContent(task,this.outputStream)
           this.push({eod: task.TABLE_NAME})
	       this.nextPhase = this.schemaInfo.length === 0 ? 'finished' : 'data';
		   break;
		 case 'finished':
           await this.dbi.finalizeExport();
		   this.push(null);
           break;
         default:
      }
    } catch (e) {
      this.yadamuLogger.logException([`${this.constructor.name}._read()`],e);
      this.destroy(e);
    }
  }
}

module.exports = DBReader;