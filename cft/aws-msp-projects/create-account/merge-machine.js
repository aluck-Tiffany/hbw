const fs = require('fs');

const template = JSON.parse(fs.readFileSync(`create-account.template.json`));
template.Resources.StateMachine.Properties.DefinitionString['Fn::Sub'] = fs.readFileSync(`create-account.machine.json`, 'utf8').replace(/\"/g, "\"");;
fs.writeFileSync(`create-account.template.json`, JSON.stringify(template), 'utf8');
