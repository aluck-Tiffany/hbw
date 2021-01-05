const AWS = require('aws-sdk'); // eslint-disable-line import/no-extraneous-dependencies

const sts = new AWS.STS();

const {
  hostedZoneId,
} = process.env;

exports.handler = (event, context, callback) => {
  const {
    vpcId,
    ownerId,
  } = event.detail.responseElements.vpcPeeringConnection.requesterVpcInfo;
  Promise.resolve()
    .then(() => {
      const route53 = new AWS.Route53();
      return route53.createVPCAssociationAuthorization({
        HostedZoneId: hostedZoneId,
        VPC: {
          VPCId: vpcId,
          VPCRegion: 'ap-southeast-2',
        },
      }).promise();
    })
    .then(() => sts.assumeRole({
      DurationSeconds: 3600,
      ExternalId: 'Datacom',
      RoleArn: `arn:aws:iam::${ownerId}:role/DatacomIntegration`,
      RoleSessionName: 'CreatedHostedZoneAssociation',
    }).promise())
    .then((data) => {
      const route53 = new AWS.Route53({
        accessKeyId: data.Credentials.AccessKeyId,
        secretAccessKey: data.Credentials.SecretAccessKey,
        sessionToÎken: data.Credentials.SessionToken,
      });
      return route53.associateVPCWithHostedZone({
        HostedZoneId: hostedZoneId,
        VPC: {
          VPCId: vpcId,
          VPCRegion: 'ap-southeast-2',
        },
      }).promise();
    })
    .then(() => {
      callback(null);
    })
    .catch((err) => {
      callback(err);
    });
};
