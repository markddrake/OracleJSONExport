"use strict"

const {DatabaseError} = require('../../common/yadamuException.js')

class ExampleError extends DatabaseError {
  
  constructor(cause,stack,sql) {
    super(cause,stack,sql);
  }

}

module.exports = ExampleError