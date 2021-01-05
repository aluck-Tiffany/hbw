const AWS = require('aws-sdk');  // eslint-disable-line import/no-extraneous-dependencies

const cloudformation = new AWS.CloudFormation();

const {
    bucket,
    version,
    vpcIdentifier,
} = process.env;

exports.handler = (event, context, callback) => {
  console.log(event);
  console.log(JSON.stringify(event));
  const {
        vpcPeeringConnection,
    } = event.detail.responseElements;
  cloudformation.createStack({
    StackName: `routes-peering${vpcIdentifier}-${vpcPeeringConnection.requesterVpcInfo.vpcId}`,
    Parameters: [
      {
        ParameterKey: 'VPCPeeringConnection',
        ParameterValue: vpcPeeringConnection.vpcPeeringConnectionId,
      },
      {
        ParameterKey: 'DestinationCidrBlock',
        ParameterValue: vpcPeeringConnection.requesterVpcInfo.cidrBlock,
      },
      {
        ParameterKey: 'VPCIdentifier',
        ParameterValue: vpcIdentifier,
      },
    ],
    TemplateURL: `https://s3-ap-southeast-2.amazonaws.com/${bucket}/aws-msp-projects/create-peering-routes/${version}/routes-peering.template.json`,
  }).promise()
        .then(() => {
          callback(null);
        })
        .catch((err) => {
          callback(err);
        });
};
