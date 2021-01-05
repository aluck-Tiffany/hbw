const fs = require('fs');

const template = JSON.parse(fs.readFileSync(`deploy-templates.template.json`));
template.Resources.StateMachine.Properties.DefinitionString['Fn::Sub'] = fs.readFileSync(`deploy-templates.machine.json`, 'utf8').replace(/\"/g, "\"");;
fs.writeFileSync(`deploy-templates.template.json`, JSON.stringify(template), 'utf8');
