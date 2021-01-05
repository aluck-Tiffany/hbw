const AWS = require('aws-sdk'); // eslint-disable-line import/no-extraneous-dependencies
const querystring = require('querystring');
const https = require('https');

const dynamodb = new AWS.DynamoDB();

const editCredentials = (ccAccountId, accessKey, serviceAccountId) =>
    new Promise((resolve, reject) => {
      const parameters = querystring.stringify({
        access_key: accessKey,
        use_cc_account_id: ccAccountId,

      });
      const body = JSON.stringify({
        aws_role_arn: `arn:aws:iam::${serviceAccountId}:role/CloudCheckr`,
      });
      console.log(body);
      const options = {
        hostname: 'au.cloudcheckr.com',
        port: 443,
        path: `/api/account.json/edit_credential?${parameters}`,
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
      return editCredentials(event.cloudcheckr.cc_account_id, accessKey, event.accountId);
    })
    .then((data) => {
      console.log(data);
      callback(null);
    })
    .catch((err) => {
      callback(err);
    });
};
