"use strict" 

const path = require('path')
const mime = require('mime-types');

const LoaderDBI = require('../node/loaderDBI.js');
const YadamuLibrary = require('../../../YADAMU/common/yadamuLibrary.js');

/*
**
** YADAMU Database Inteface class skeleton
**
*/

class CloudDBI extends LoaderDBI {
 
  /*
  **
  ** Extends LoaderDBI enabling operations on Cloud Services. This is an Abstract Class that provides methods that 
  ** will be used by implimenting classes
  **
  */

  get DATABASE_VENDOR()     { return 'ABSTRACT_VENDOR_NAME' };
  
  get STORAGE_ID()          { return 'ABSTACT_STORAGE_ID' }
  
  get ROOT_FOLDER()              { 
    return this._ROOT_FOLDER || (() => { 
      const rootFolder = this.parameters.ROOT_FOLDER || this.connectionProperties.rootFolder || '' 
	  this._ROOT_FOLDER = YadamuLibrary.macroSubstitions(rootFolder, this.yadamu.MACROS).split(path.sep).join(path.posix.sep)
	  return this._ROOT_FOLDER
    })() 
  }
  
  constructor(yadamu) {
    // Export File Path is a Directory for in Load/Unload Mode
    super(yadamu)
	this.cloudProperties = {}
  }    
  
  async createConnectionPool() {
	// this.yadamuLogger.trace([this.constructor.name],`new AWS.S3()`)
	this.s3 = await new AWS.S3(this.connectionProperties)
	this.cloudService = new S3IO(this.s3,{},this.yadamuLogger)
  }
  
  async loadMetadataFiles() {
    // this.yadamuLogger.trace([this.constructor.name,this.EXPORT_PATH],`loadMetadataFiles()`)
  	const metadata = {}
    if (this.controlFile) {
      const metdataRecords = await Promise.all(Object.keys(this.controlFile.metadata).map((tableName) => {
		return this.cloudService.getObject(this.controlFile.metadata[tableName].file)
      }))
	  metdataRecords.forEach((content) =>  {
        const json = this.parseContents(content)
        metadata[json.tableName] = json;
      })
    }
    return metadata;      
  }
  
  /*
  **
  ** Remember: Import is Writing data to an S3 Object Store - unload.
  **
  */

  getMetadataPath(tableName) {
     return `${path.join(this.metadataFolderPath,tableName)}.json`.split(path.sep).join(path.posix.sep)
  }
  
  getDatafilePath(filename) {
	  return filename.split(path.sep).join(path.posix.sep)
  }

  writeFile(filename,metadata) {
	const res = this.cloudService.putObject(filename,metadata)
    this.cloudService.writeOperations.add(res)
	res.then(() => { this.cloudService.writeOperations.delete(res)})
    return res;
  }
  
  setFolderPaths(rootFolder,schema) {
      
	this.controlFilePath = `${path.join(rootFolder,schema)}.json`.split(path.sep).join(path.posix.sep) 
    this.metadataFolderPath = path.join(rootFolder,'metadata').split(path.sep).join(path.posix.sep) 
    this.dataFolderPath = path.join(rootFolder,'data').split(path.sep).join(path.posix.sep) 
  }      
  
  async initializeImport() {
	 
    // this.yadamuLogger.trace([this.constructor.name],`initializeImport()`)
      	
	await this.cloudService.verifyBucketContainer()	

    // Calculate the base directory for the unload operation. The Base Directory is dervied from the target schema name specified by the TO_USER parameter


    this.setFolderPaths(this.IMPORT_FOLDER,this.parameters.TO_USER)
	this.yadamuLogger.info(['Import',this.DATABASE_VENDOR],`Created target directory  "${this.IMPORT_FOLDER}"`);
    
    const dataFileList = {}
    const metadataFileList = {}
    this.createControlFile(metadataFileList,dataFileList)
    
  }
  
  getFileOutputStream(tableName) {
    // this.yadamuLogger.trace([this.constructor.name,this.DATABASE_VENDOR,tableName],`Creating readable stream on getFileOutputStream(${this.controlFile.data[tableName].file})`)
	const file = this.controlFile.data[tableName].file
	const extension = path.extname(file);
	const contentType = mime.lookup(extension) || 'application/octet-stream'
	return this.cloudService.createWriteStream(file,contentType)
  }  
  
  /*
  **
  ** Remember: Export is Reading data from an S3 Object Store - load.
  **
  */

  async initializeExport() {
      
	// this.yadamuLogger.trace([this.constructor.name],`initializeExport()`)
    
    this.setFolderPaths(this.EXPORT_FOLDER,this.parameters.FROM_USER)

	this.yadamuLogger.info(['Export',this.DATABASE_VENDOR],`Using control file "${this.STORAGE_ID}/${this.controlFilePath}"`);
    const fileContents = await this.cloudService.getObject(this.controlFilePath)
	this.controlFile = this.parseContents(fileContents)
  }

  async getInputStream(tableInfo) {
    // this.yadamuLogger.trace([this.constructor.name,this.DATABASE_VENDOR,tableInfo.TABLE_NAME],`Creating readable stream on ${this.controlFile.data[tableInfo.TABLE_NAME].file}`)
    const stream = await this.cloudService.createReadStream(this.controlFile.data[tableInfo.TABLE_NAME].file)
	return stream
  }
  
  async setWorkerConnection() {
    // DBI implementations that do not use a pool / connection mechansim need to overide this function. eg MSSQLSERVER
	this.cloudConnection = this.manager.cloudConnection
	this.cloudService = this.manager.cloudService
  }
  
  classFactory(yadamu) {
	return new S3DBI(yadamu)
  }
    
}

module.exports = CloudDBI
