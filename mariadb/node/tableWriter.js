"use strict"

class TableWriter {

  constructor(dbi,tableName,tableInfo,status,logWriter) {
    this.dbi = dbi;
    this.tableName = tableName
    this.tableInfo = tableInfo;
    this.tableInfo.args =  '(' + Array(this.tableInfo.targetDataTypes.length).fill('?').join(',')  + '),';

    this.status = status;
    this.logWriter = logWriter;    

    this.batch = [];
    this.batchRowCount = 0;
    
    this.startTime = new Date().getTime();
    this.endTime = undefined;
    this.insertMode = 'Batch';

    this.skipTable = false;

    this.logDDLIssues   = (this.status.loglevel && (this.status.loglevel > 2));
    this.logDDLIssues   = true;
  }

  async initialize() {
  }

  batchComplete() {
    return (this.batch.length === this.tableInfo.batchSize)
  }
  
  commitWork(rowCount) {
    return (rowCount % this.tableInfo.commitSize) === 0;
  }

  async appendRow(row) {
    this.tableInfo.targetDataTypes.forEach(function(targetDataType,idx) {
      const dataType = this.dbi.decomposeDataType(targetDataType);
      if (row[idx] !== null) {
        switch (dataType.type) {
          case "tinyblob" :
            row[idx] = Buffer.from(row[idx],'hex');
            break;
          case "blob" :
            row[idx] = Buffer.from(row[idx],'hex');
            break;
          case "mediumblob" :
            row[idx] = Buffer.from(row[idx],'hex');
            break;
          case "longblob" :
            row[idx] = Buffer.from(row[idx],'hex');
            break;
          case "varbinary" :
            row[idx] = Buffer.from(row[idx],'hex');
            break;
          case "binary" :
            row[idx] = Buffer.from(row[idx],'hex');
            break;
          case "json" :
            row[idx] = JSON.stringify(row[idx]);
            break;
          case "date":
          case "time":
          case "datetime":
          case "timestamp":
            // If the the input is a string, assume 8601 Format with "T" seperating Date and Time and Timezone specified as 'Z' or +00:00
            // Neeed to convert it into a format that avoiods use of convert_tz and str_to_date, since using these operators prevents the use of Bulk Insert.
            // Session is already in UTC so we safely strip UTC markers from timestamps
            if (typeof row[idx] !== 'string') {
              row[idx] = row[idx].toISOString();
            }             
            row[idx] = row[idx].substring(0,10) + ' '  + (row[idx].endsWith('Z') ? row[idx].substring(11).slice(0,-1) : (row[idx].endsWith('+00:00') ? row[idx].substring(11).slice(0,-6) : row[idx].substring(11)))
            break;           
          default :
         }
      }
    },this)
    if (this.tableInfo.insertMode === 'Iterative') {
      this.batch.push(row);
    }
    else {
      this.batch.push(...row);
    }
    this.batchRowCount++
  }

  hasPendingRows() {
    return this.batch.length > 0;
  }
 
  async processWarnings(results) {
    if (results.warningCount >  0) {
      const warnings = await this.dbi.executeSQL('show warnings');
      warnings.forEach(function(warning,idx) {
        if (warning.Level === 'Warning') {
          this.status.warningRaised = true;
          this.logWriter.write(`${new Date().toISOString()}[TableWriter.writeBatch("${this.tableName}")][WARNING]: Warnings reported by bulk insert operation. Details: ${JSON.stringify(warning)}\n`)
          this.logWriter.write(`${this.batch[idx]}\n`)
        }
      },this)
    }
  }
  
  async writeBatch() {
    try {
      if (this.tableInfo.insertMode === 'Iterative') {
        for (const i in this.batch) {
          try {
            const results = await this.dbi.executeSQL(this.tableInfo.dml,this.batch[i]);
            await this.processWarnings(results);
          } catch(e) {
            if (e.errno && ((e.errno === 3616) || (e.errno === 3617))) {
              this.logWriter.write(`${new Date().toISOString()}[TableWriter.writeBatch("${this.tableName}")]: Batch size [${this.tableInfo.bulkOperation.rows.length}].  Skipping Row Reason: ${e.message}\n`)
              this.rowCount--;
            }
            else {
              throw e;
            }
          }    
        }
      }
      else {  
        // Slice removes the unwanted last comma from the replicated args list.
        const args = this.tableInfo.args.repeat(this.batchRowCount).slice(0,-1);
        const results = await this.dbi.executeSQL(this.tableInfo.dml.slice(0,-1) + args, this.batch);
        await this.processWarnings(results);
      }
      this.endTime = new Date().getTime();
      this.batch.length = 0;
      this.batchRowCount = 0;
    } catch (e) {
      this.skipTable = true;
      this.status.warningRaised = true;
      this.logWriter.write(`${new Date().toISOString()}[TableWriter.writeBatch("${this.tableName}")]: Skipping table. Batch size [${this.batch.length}]. Reason: ${e.message}\n`)
      if (this.logDDLIssues) {
        this.logWriter.write(`${this.tableInfo.dml}\n`);
        this.logWriter.write(`${this.batch[0]}\n...${this.batch[this.batch.length-1]}\n`)
      }      
      this.batch.length = 0;
    }
    return this.skipTable
  }

  async finalize() {
    if (this.hasPendingRows()) {
      this.skipTable = await this.writeBatch();   
    }
    await this.dbi.commitTransaction();
    return {
      startTime    : this.startTime
    , endTime      : this.endTime
    , insertMode   : this.tableInfo.insertMode
    , skipTable    : this.skipTable
    }    
  }

}

module.exports = TableWriter;