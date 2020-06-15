"use strict"

const {DatabaseError} = require('../../common/yadamuError.js')

class MongoError extends DatabaseError {
  //  const err = new MongodbError(cause,sql)
  constructor(cause,sql) {
    super(cause,null,sql)
  }
  
  cloneStack(stack) {
	// Use the stack generated by the new Error() operation.
	return this.stack;
  }
  
  lostConnection() {
	const knownErrors = [11600]
    const knownMessages = ["Cannot use a session that has ended"]
    return ((this.cause.code && (knownErrors.indexOf(this.cause.code) > -1)) || (this.knownMessages.indexOf(this.message) > -1))
  }

  serverUnavailable() {
	const knownErrors = [11600]
	const knownMessages = ["pool is draining, new operations prohibited"]
    return ((this.cause.code && (knownErrors.indexOf(this.cause.code) > -1)) || (this.knownMessages.indexOf(this.message) > -1))
  }
    	   
}

module.exports = MongoError
