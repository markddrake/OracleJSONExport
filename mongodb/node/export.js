"use strict"

const Yadamu = require('../../common/yadamu.js').Yadamu;
const DBInterface = require('./MongoDBI.js');

async function main() {

  const yadamu = new Yadamu('Export');
  const dbi = new DBInterface(yadamu);  
  await yadamu.doExport(dbi);
  
}

main()