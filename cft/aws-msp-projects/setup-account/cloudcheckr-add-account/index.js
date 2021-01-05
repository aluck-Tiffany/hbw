const AWS = require('aws-sdk'); // eslint-disable-line import/no-extraneous-dependencies
const querystring = require('querystring');
const https = require('https');

const dynamodb = new AWS.DynamoDB();

const addAccount = (accountName, accessKey, billingAccountId) => new Promise((resolve, reject) => {
  const parameters = querystring.stringify({
    access_key: accessKey,
    use_aws_account_id: billingAccountId,
  });
  const body = JSON.stringify({
    account_name: accountName,
  });
  const options = {
    hostname: 'au.cloudcheckr.com',
    port: 443,
    path: `/api/account.json/add_account_v3?${parameters}`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Length': body.length,
    },
  };
  console.log(options);
  const req = https.request(options, (res) => {
    const chunks = [];
    res.on('data', (d) => {
      chunks.push(d);
    });
    res.on('end', () => {
      resolve(JSON.parse(Buffer.concat(chunks).toString()));
    });
  });
  req.on('error', (e) => {
    reject(e);
  });
  req.write(body);
  req.end();
});

exports.handler = (event, context, callback) => {
  Promise.resolve()
    .then(() => {
      const params = {
        Key: {
          billingAccountId: {
            N: event.billingAccountId,
          },
        },
        TableName: 'cloudcheckr',
      };
      return dynamodb.getItem(params).promise();
    })
    .then((data) => {
      const accessKey = data.Item.accessKey.S;
      return addAccount(`${event.customer} ${event.environment}`, accessKey, event.billingAccountId);
    })
    .then((data) => {
      console.log(data);
      callback(null, data);
    })
    .catch((err) => {
      callback(err);
    });
};
