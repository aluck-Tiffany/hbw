/* jshint esversion: 6 */
const fs = require('fs');

const baseUrl = process.env.baseUrl;
const policyList = process.env.policyList;

// Create Trend Micro policy map
const policyMap = new Map();
policyList.split(',').forEach((item) => {
  const os = item.split(':')[0];
  const policyId = item.split(':')[1];
  policyMap.set(os, policyId);
});

// Parse OS from event query string parameters
const parseOS = (event) => {
  const {
        os,
        platform,
        version,
    } = event.queryStringParameters;
  return (platform && version)
        ? platform.toLowerCase() + version.toLowerCase()
        : os.toLowerCase();
};

const buildBootstrap = (event) => {
  const os = parseOS(event);
  const {
        patchGroup,
        av,
        cis,
    } = event.queryStringParameters;
  const body = [];
  if (os.indexOf('windows') > -1) {
        // M5 bug
    body.push('w32tm /resync /force');
    body.push(`$os = "${os}"`);
        // WSUS
    if (patchGroup) {
      body.push(`$wsusUrl = "wsus.${baseUrl}"`);
      body.push(`$targetGroup = "${patchGroup}"`);
      body.push(fs.readFileSync('wsus.ps1', 'utf8'));
    }
        // SSM
    body.push(`$ssmUrl = "ssm.${baseUrl}"`);
    if (cis === 'enforce') {
      body.push('$enforce = $True');
    } else {
      body.push('$enforce = $False');
    }
    body.push(fs.readFileSync('ssm.ps1', 'utf8'));
        // Puppet
    body.push(fs.readFileSync('puppet.ps1', 'utf8'));
        // Trend
    body.push(`$trendUrl = "trend.${baseUrl}"`);

    if (av) {
      body.push(`$policyId = "${av}"`);
    } else if (policyList) {
      body.push(`$policyId = "${policyMap.get(os)}"`);
    }

    body.push(fs.readFileSync('trend.ps1', 'utf8'));
  } else {
    // Linux
    body.push(`ssmUrl="ssm.${baseUrl}"`);
    body.push(`trendUrl="trend.${baseUrl}"`);
    if (cis === 'enforce') {
      body.push('enforce="true"');
    } else {
      body.push('enforce="false"');
    }

    body.push(fs.readFileSync('bootstrap.sh', 'utf8'));
  }
  console.log(`body${body}`); // eslint-disable-line 
  return body;
};

const helperBootstrap = (event) => {
  const {
        name,
    } = event.queryStringParameters;
  const body = [];
  if (name) {
    body.push(`$name = "${name}"`);
  }
  return body;
};

exports.handler = (event, context, callback) => {
  console.log(JSON.stringify(event)); // eslint-disable-line 
  let body = [];
  switch (event.path) {
    case '/helper':
      body = body.concat(helperBootstrap(event));
      break;
    case '/custom':
      body = body.concat(buildBootstrap(event));
      break;
    default: // /default
      body = body.concat(buildBootstrap(event));
  }
  callback(null, {
    statusCode: '200',
    headers: {
      'Content-Type': 'text/plain',
    },
    body: body.join('\n'),
  });
};
