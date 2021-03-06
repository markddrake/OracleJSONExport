"use strict";
const sql = require('mssql');
const Writable = require('stream').Writable
const { StringDecoder } = require('string_decoder');

class DBFileLoader extends Writable {
     
  constructor(dbi) {
    super({})
    this.dbi = dbi;
	this._decoder = new StringDecoder('UTF-8')
  }
     
  async _write(chunk, encoding, callback) {
    try {
      if (encoding === 'buffer') {
        chunk = this._decoder.write(chunk);
      }
      const data = chunk
      const results = await this.dbi.executeCachedStatement({C0: data})
      callback(null,results);
    } catch (e) {
      (e);
    }   
  } 
  
  async  _final(callback) {
    const data = this._decoder.end();
	let results = undefined
	if (data.length > 0) {
      results = await this.dbi.executeCachedStatement({C0: data})
    }
    callback(null,results);
  }
}   
 
module.exports = DBFileLoader
