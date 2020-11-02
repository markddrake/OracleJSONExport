"use strict"

const {DatabaseError} = require('../../common/yadamuError.js')

class PostgresError extends DatabaseError {
  //  const err = new PostgresError(cause,stack,sql)
  constructor(cause,stack,sql) {
    super(cause,stack,sql);
	// Abbreviate Long Lists of Place Holders ...
	if ((typeof this.sql === 'string') && (this.sql.indexOf('),($')) > 0) {
	  const startElipises = this.sql.indexOf('),($') + 2 
	  const endElipises =  this.sql.lastIndexOf('),($') + 2
	  this.sql = this.sql.substring(0,startElipises) + '(...),' + this.sql.substring(endElipises);
	}
  }

  lostConnection() {
	const knownErrors = ['Connection terminated unexpectedly','Client has encountered a connection error and is not queryable']
	return ((this.cause.severity && (this.cause.severity === 'FATAL')) && (this.cause.code && (this.cause.code === '57P01')) || ((this.cause.name === 'Error') && (knownErrors.indexOf(this.cause.message) > -1)))
  }
  
  serverUnavailable() {
	const knownErrors = ['Connection terminated unexpectedly','Client has encountered a connection error and is not queryable']
    return (this.cause.message && (knownErrors.indexOf(this.cause.message) > -1))
  }

  missingTable() {
	return ((this.cause.severity && (this.cause.severity === 'ERROR')) && (this.cause.code && (this.cause.code === '42P01')))
  }

}

module.exports = PostgresError