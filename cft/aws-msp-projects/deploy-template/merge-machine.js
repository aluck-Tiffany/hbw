const fs = require('fs');

const template = JSON.parse(fs.readFileSync(`deploy-template.template.json`));
template.Resources.StateMachine.Properties.DefinitionString['Fn::Sub'] = fs.readFileSync(`deploy-template.machine.json`, 'utf8').replace(/\"/g, "\"");;
fs.writeFileSync(`deploy-template.template.json`, JSON.stringify(template), 'utf8');
