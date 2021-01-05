const AWS = require('aws-sdk'); // eslint-disable-line import/no-extraneous-dependencies

const iam = new AWS.IAM();
const cloudformation = new AWS.CloudFormation();
const {
    accountId,
    customer,
    environment,
} = process.env;

function lowerCaseFirstLetter(string) {
  return string.charAt(0).toLowerCase() + string.slice(1);
}
exports.handler = (event, context, callback) => {
  const record = {};
  Promise.resolve()
        .then(() => iam.createRole({
          AssumeRolePolicyDocument: JSON.stringify({
            Version: '2012-10-17',
            Statement: [
              {
                Effect: 'Allow',
                Principal: {
                  AWS: 'arn:aws:iam::848194084705:root',
                },
                Action: 'sts:AssumeRole',
                Condition: {
                  StringEquals: {
                    'sts:ExternalId': 'ecruteak',
                  },
                },
              },
            ],
          }),
          RoleName: 'DatacomCICD',
        }).promise())
        .then(() => iam.attachRolePolicy({
          PolicyArn: 'arn:aws:iam::aws:policy/AdministratorAccess',
          RoleName: 'DatacomCICD',
        }).promise())
        .then(() => {
          record.accountId = accountId;
          record.accountType = 'service';
          record.customer = customer;
          record.environment = environment;
        })
        .then(() => cloudformation.describeStacks({
          StackName: 'roles-management',
        }).promise())
        .then((data) => {
          data.Stacks[0].Parameters.filter(parameter => [
            'CloudCheckrAccountId',
            'CloudCheckrExternalId',
          ].includes(parameter.ParameterKey)).forEach((parameter) => {
            record[lowerCaseFirstLetter(parameter.ParameterKey)] = parameter.ParameterValue;
          });
          return Promise.resolve();
        })
        .then(() => cloudformation.describeStacks({
          StackName: 'alerts',
        }).promise())
        .then((data) => {
          data.Stacks[0].Parameters.filter(parameter => [
            'EnableWarnings',
          ].includes(parameter.ParameterKey)).forEach((parameter) => {
            record.controlled = parameter.ParameterValue;
          });
          return Promise.resolve();
        })
        .then(() => cloudformation.describeStacks({
          StackName: 'vpc',
        }).promise())
        .then((data) => {
          data.Stacks[0].Outputs.filter(output => [
            'VPCCidrBlock',
          ].includes(output.OutputKey)).forEach((output) => {
            record.vpcCidrBlock = output.OutputValue;
          });
          record.sizeMask = '7';
          console.log(JSON.stringify(record));
          return Promise.resolve();
        })
        .then(() => cloudformation.deleteStack({
          StackName: 'roles-management',
        }).promise())
        .then(() => cloudformation.deleteStack({
          StackName: 'management-tools',
        }).promise())
        .then(() => {
          callback(null);
        })
        .catch((err) => {
          callback(err);
        });
};
