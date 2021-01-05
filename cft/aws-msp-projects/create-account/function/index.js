const response = require('cfn-response');
const AWS = require('aws-sdk'); // eslint-disable-line import/no-extraneous-dependencies

const lambda = new AWS.Lambda();
const {
  FunctionName,
  StateMachine,
} = process.env;
exports.handler = (event, context) => {
  console.log(JSON.stringify(event));
  if (event.RequestType === 'Create') {
    console.log('Create');
    lambda.invoke({
      FunctionName,
      Payload: JSON.stringify({
        global: {},
        local: {
          machine: {
            arn: StateMachine,
            input: event.ResourceProperties,
          },
          accountId: event.ResourceProperties.accountName,
          email: event.ResourceProperties.email,
        },
      }),
    }).promise()
      .then((data) => {
        console.log(data);
        response.send(event, context, response.SUCCESS, {});
      })
      .catch(() => {
        response.send(event, context, response.FAILED, {});
      });
  } else {
    response.send(event, context, response.SUCCESS, {});
  }
};
