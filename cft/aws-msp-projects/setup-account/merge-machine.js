const fs = require('fs');

const template = JSON.parse(fs.readFileSync(`setup-account.template.json`));
template.Resources.StateMachine.Properties.DefinitionString['Fn::Sub'][0] = fs.readFileSync(`setup-account.machine.json`, 'utf8').replace(/\"/g, "\"");;
fs.writeFileSync(`setup-account.template.json`, JSON.stringify(template), 'utf8');
