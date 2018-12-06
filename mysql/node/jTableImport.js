"use strict";
const fs = require('fs');
const mysql = require('mysql');
const path = require('path');


const Yadamu = require('../../common/yadamuCore.js');
const MySQLCore = require('./mysqlCore.js');
	 
async function createStagingTable(conn,status) {    	
	const sqlStatement = `CREATE TEMPORARY TABLE IF NOT EXISTS "JSON_STAGING"("DATA" JSON)`;					   
	const results = await MySQLCore.query(conn,status,sqlStatement);
	return results;
}

async function loadStagingTable(conn,status,dumpfilePath) { 
    const localFilePath = dumpfilePath.replace(/\\/g, "\\\\");
	const sqlStatement = `LOAD DATA LOCAL INFILE '${localFilePath}' INTO TABLE "JSON_STAGING" FIELDS ESCAPED BY ''`;					   
	const results = await MySQLCore.query(conn,status,sqlStatement);
	return results;
}

async function verifyDataLoad(conn,status) {    	
	const sqlStatement = `SELECT COUNT(*) FROM "JSON_STAGING"`;				
	const results = await MySQLCore.query(conn,status,sqlStatement);
	return results;
}

async function processStagingTable(conn,status,schema) {    	
	const sqlStatement = `SET @RESULTS = ''; CALL IMPORT_JSON(?,@RESULTS); SELECT @RESULTS "logRecords";`;					   
	const results = await MySQLCore.query(conn,status,sqlStatement,schema);
	return results;
}

async function main(){
	
  let conn;
  let parameters;
  let logWriter = process.stdout;    
  let status;

  try {

    parameters = MySQLCore.processArguments(process.argv);
    status = Yadamu.getStatus(parameters,'Import');
  
	if (parameters.LOGFILE) {
	  logWriter = fs.createWriteStream(parameters.LOGFILE,{flags : "a"});
    }

    const connectionDetails = {
            host      : parameters.HOSTNAME
           ,user      : parameters.USERNAME
           ,password  : parameters.PASSWORD
		   ,database  : parameters.DATABASE
		   ,multipleStatements: true
    }

    conn = await MySQLCore.getConnection(parameters,status,logWriter);

    await MySQLCore.query(conn,status,`SET GLOBAL local_infile = 'ON'`);
    
    const importFilePath = path.resolve(parameters.FILE);
    
	const stats = fs.statSync(importFilePath)
    const fileSizeInBytes = stats.size
	
	let results = null;
    const schema = parameters.TOUSER;
	results = await MySQLCore.createTargetDatabase(conn,status,schema);
	results = await createStagingTable(conn,status);
	const startTime = new Date().getTime();
	results = await loadStagingTable(conn,status,importFilePath);
	const elapsedTime = new Date().getTime() - startTime;
    logWriter.write(`${new Date().toISOString()}[JSON_TABLE()]: Processing Import Data file "${importFilePath}". Size ${fileSizeInBytes}. File Upload elapsed time ${elapsedTime}ms.  Throughput ${Math.round((fileSizeInBytes/elapsedTime) * 1000)} bytes/s.\n`)

	results = await processStagingTable(conn,status,schema);
    results = results.pop();
	results = JSON.parse(results[0].logRecords)
    Yadamu.processLog(results, status, logWriter)    
	await conn.end();
    Yadamu.reportStatus(status,logWriter)    
  } catch (e) {
    if (logWriter !== process.stdout) {
	  console.log(`Import operation failed: See "${parameters.LOGFILE}" for details.`);
  	  logWriter.write('Import operation failed.\n');
	  logWriter.write(e.stack);
    }
	else {
    	console.log('Import operation Failed.');
        console.log(e);
	}
    if (conn !== undefined) {
	  await conn.end();
	}
  }
  
  if (logWriter !== process.stdout) {
	logWriter.close();
  }
  
  if (status.sqlTrace) {
    status.sqlTrace.close();
  }
}

main()