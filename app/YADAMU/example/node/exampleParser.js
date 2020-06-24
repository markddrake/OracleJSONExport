"use strict" 

const YadamuParser = require('../../common/yadamuParser.js')

class ExampleParser extends YadamuParser {
  
  constructor(tableInfo,objectMode,yadamuLogger) {
    super(tableInfo,objectMode,yadamuLogger);      
  }
    
  async _transform (data,encoding,callback) {
    this.counter++;
    if (!this.objectMode) {
      data.json = JSON.stringify(data.json);
    }
    this.push({data:data.json})
    callback();
  }
}

module.exports = ExampleParser