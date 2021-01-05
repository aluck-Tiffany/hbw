/* jshint esversion: 6 */
/* eslint func-names: ["error", "as-needed"] */
const AWS = require('aws-sdk'); // eslint-disable-line

const { iamRoleName, externalId, serviceAccountIds } = process.env;

const getCpmTag = (tags, accountId) => {
  const cpmTags = [
    `${accountId}_hourly:hourly`,
    `${accountId}_daily:daily`,
    `${accountId}_weekly:weekly`,
    `${accountId}_monthly:monthly`,
    `${accountId}_yearly:yearly`,
    'no-backup'];

  for (const tag of tags) { // eslint-disable-line
    if (tag.Key === 'aws:autoscaling:groupName') {
      return '';
    }
  }

  for (const tag of tags) { // eslint-disable-line
    if (tag.Key === 'cpm backup') {
      for (const cpmTag of cpmTags) { // eslint-disable-line
        if (tag.Value.indexOf(cpmTag) > -1) {
          return '';
        }
      }
    }
  }

  return `${accountId}_daily:daily`;
};

const applyCpmBackpTags = accountId => new Promise((resolve, reject) => {
  const sts = new AWS.STS();

  sts.assumeRole({
    DurationSeconds: 3600,
    ExternalId: externalId,
    RoleArn: `arn:aws:iam::${accountId}:role/${iamRoleName}`,
    RoleSessionName: `${accountId}-backupTagging`,
  }).promise().then((d) => {
    const ec2 = new AWS.EC2({
      accessKeyId: d.Credentials.AccessKeyId,
      secretAccessKey: d.Credentials.SecretAccessKey,
      sessionToken: d.Credentials.SessionToken,
    });

    ec2.describeInstances({}).promise()
      .then((data) => {
        const promises = [];
        data.Reservations.forEach((reservation) => {
          reservation.Instances.forEach((instance) => {
            const cpmTag = getCpmTag(instance.Tags, accountId);
            if (cpmTag) {
              promises.push(ec2.createTags({
                Resources: [
                  instance.InstanceId,
                ],
                Tags: [
                  {
                    Key: 'cpm backup',
                    Value: cpmTag,
                  },
                ],
              }).promise());
            }
          });
        });
        return Promise.all(promises);
      })
      .then(() => {
        resolve();
      })
      .catch((err) => {
        reject(err);
      });
  }).catch((err) => {
    reject(err);
  });
});

exports.handler = (event, context, callback) => {
  const promises = [];

  console.log(JSON.stringify(event)); // eslint-disable-line

  serviceAccountIds.replace(/\s/g, '').split(',').forEach((accountId) => {
    console.log(`Checking AWS account ${accountId} ...`); // eslint-disable-line
    promises.push(applyCpmBackpTags(accountId));
  });

  Promise.all(promises).then((data) => {
    callback(null, data);
  }).catch((err) => {
    callback(err);
  });
};
