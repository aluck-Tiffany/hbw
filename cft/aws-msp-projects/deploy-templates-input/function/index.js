const AWS = require('aws-sdk'); // eslint-disable-line import/no-extraneous-dependencies

const dynamodb = new AWS.DynamoDB();
const stepfunctions = new AWS.StepFunctions();
const {
  deployTemplatesMachine,
  tableName,
  awsMspEnvironmentsVersion,
  awsMspSingleUseVersion,
  createPeeringRoutesVersion,
  // createHostedZoneAssociationVersion,
  cpmVersion,
  copyCostCentreTagVersion,
} = process.env;

const checkStackParameters = (event, accounts, stackName) => {
  const updatedAccountType = (event.accountType === 'service') ? `${event.accountType}${event.accountId}` : event.accountType;
  const accountEntry = accounts[updatedAccountType];

  if (accountEntry.inputs) {
    const inputs = accountEntry.inputs;

    if (Object.prototype.hasOwnProperty.call(inputs, stackName)) {
      return inputs[stackName];
    }
  }
  return null;
};

const createVpcTemplateInput = (event, accounts, vpcs) => {
  const templates = [];

  vpcs.forEach((vpc) => {
    const vpcIdentifier = vpc.vpcIdentifier ? `-${vpc.vpcIdentifier}` : '';

    templates.unshift({
      name: `vpc${vpcIdentifier}`,
      path: `aws-msp-environments/${awsMspEnvironmentsVersion}`,
      file: 'vpc.template.json',
      parameters: [{
        ParameterKey: 'Name',
        ParameterValue: `${event.customer} ${event.environment}`,
      },
      {
        ParameterKey: 'VPCCidrBlock',
        ParameterValue: vpc.vpcCidrBlock,
      },
      {
        ParameterKey: 'SizeMask',
        ParameterValue: vpc.sizeMask,
      },
      ],
    });
    templates.unshift({
      name: `routes${vpcIdentifier}`,
      path: `aws-msp-environments/${awsMspEnvironmentsVersion}`,
      file: 'routes.template.json',
      parameters: [],
    });
    // Service accounts only, MGMT is peering-acceptor
    if (event.accountType === 'service') {
      // Customized Stack Parameters defined in DynomoDB entry
      templates.unshift({
        name: `peering-requester${vpcIdentifier}`,
        path: `aws-msp-environments/${awsMspEnvironmentsVersion}`,
        file: 'peering-requester.template.json',
        parameters: [{
          ParameterKey: 'PeerVpcId',
          ParameterValue: accounts.management.vpcId,
        },
        {
          ParameterKey: 'DestinationCidrBlock',
          ParameterValue: accounts.management.vpcCidrBlock,
        },
        {
          ParameterKey: 'PeerOwnerId',
          ParameterValue: accounts.management.accountId,
        },
        {
          ParameterKey: 'PeerRoleArn',
          ParameterValue: `arn:aws:iam::${accounts.management.accountId}:role/Peering-Accepter-Role`,
        },
        ],
      });
    }
    templates.unshift({
      name: `nacls${vpcIdentifier}`,
      path: `aws-msp-environments/${awsMspEnvironmentsVersion}`,
      file: 'nacls.template.json',
      parameters: [],
    });
    templates.unshift({
      name: `endpoints${vpcIdentifier}`,
      path: `aws-msp-environments/${awsMspEnvironmentsVersion}`,
      file: 'endpoints.template.json',
      parameters: [],
    });
    templates.unshift({
      name: `natgateways${vpcIdentifier}`,
      path: `aws-msp-environments/${awsMspEnvironmentsVersion}`,
      file: 'natgateways.template.json',
      parameters: [],
    });

    let params = checkStackParameters(event, accounts, `flowlogs${vpcIdentifier}`);
    templates.unshift({
      name: `flowlogs${vpcIdentifier}`,
      path: `aws-msp-environments/${awsMspEnvironmentsVersion}`,
      file: 'flowlogs.template.json',
      parameters: params || [{
        ParameterKey: 'URL',
        ParameterValue: '',
      },
      {
        ParameterKey: 'VPCIdentifier',
        ParameterValue: `${vpcIdentifier}`,
      },
      ],
    });

    params = checkStackParameters(event, accounts, `sg-management${vpcIdentifier}`);
    templates.unshift({
      name: `sg-management${vpcIdentifier}`,
      path: `aws-msp-environments/${awsMspEnvironmentsVersion}`,
      file: 'sg-management.template.json',
      parameters: params || [{
        ParameterKey: 'ActiveDirectorySecurityGroup',
        ParameterValue: accounts.management.activeDirectorySecurityGroup ?
          accounts.management.activeDirectorySecurityGroup : '',
      },
      {
        ParameterKey: 'JumpHostSecurityGroup',
        ParameterValue: accounts.management.jumpHostSecurityGroup ?
          accounts.management.jumpHostSecurityGroup : '',
      },
      {
        ParameterKey: 'TrendMicroSecurityGroup',
        ParameterValue: accounts.management.trendMicroSecurityGroup ?
          accounts.management.trendMicroSecurityGroup : '',
      },
      {
        ParameterKey: 'WSUSSecurityGroup',
        ParameterValue: accounts.management.wsusSecurityGroup ?
          accounts.management.wsusSecurityGroup : '',
      },
      {
        ParameterKey: 'SCOMSecurityGroup',
        ParameterValue: accounts.management.scomSecurityGroup ?
          accounts.management.scomSecurityGroup : '',
      },
      {
        ParameterKey: 'PRTGSecurityGroup',
        ParameterValue: accounts.management.prtgSecurityGroup ?
          accounts.management.prtgSecurityGroup : '',
      },
      ],
    });
    if (event.accountType === 'management') {
      templates.unshift({
        name: 'create-peering-routes',
        path: `aws-msp-projects/create-peering-routes/${createPeeringRoutesVersion}`,
        parameters: [{
          ParameterKey: 'CICDBucket',
          ParameterValue: 'enabling-services-ci-cd',
        },
        {
          ParameterKey: 'CreatePeeringRoutesVersion',
          ParameterValue: createPeeringRoutesVersion,
        },
        ],
      });
    }
  });
  return templates;
};

const createTemplatesInput = (event, accounts, vpcs) => {
  const templates = [];
  if (event.accountType === 'logging') {
    const params = checkStackParameters(event, accounts, 'logging');
    templates.unshift({
      name: 'logging',
      path: `aws-msp-single-use/${awsMspSingleUseVersion}`,
      parameters: params || [],
    });
    templates.unshift({
      name: 'sumologic',
      path: `aws-msp-single-use/${awsMspSingleUseVersion}`,
      parameters: [],
    });
  }
  // ALL accounts
  templates.unshift({
    name: 'cloudtrail',
    path: `aws-msp-environments/${awsMspEnvironmentsVersion}`,
    parameters: [{
      ParameterKey: 'AccountId',
      ParameterValue: accounts.logging.accountId,
    }],
  });
  templates.unshift({
    name: 'config',
    path: `aws-msp-environments/${awsMspEnvironmentsVersion}`,
    parameters: [{
      ParameterKey: 'AccountId',
      ParameterValue: accounts.logging.accountId,
    }],
  });
  templates.unshift({
    name: 'alerts',
    path: `aws-msp-environments/${awsMspEnvironmentsVersion}`,
    parameters: [{
      ParameterKey: 'Environment',
      ParameterValue: `${event.customer} ${event.environment}`,
    },
    {
      ParameterKey: 'EnableWarnings',
      ParameterValue: event.controlled,
    },
    ],
  });

  const managementParameters = [];
  managementParameters.push({
    ParameterKey: 'EnableCloudCheckr',
    ParameterValue: 'true',
  });
  managementParameters.push({
    ParameterKey: 'CloudCheckrAccountId',
    ParameterValue: event.cloudCheckrAccountId,
  });
  managementParameters.push({
    ParameterKey: 'CloudCheckrExternalId',
    ParameterValue: event.cloudCheckrExternalId,
  });
  // MGMT and SERVICE accounts
  if (event.accountType !== 'logging') {
    managementParameters.push({
      ParameterKey: 'EnableCPM',
      ParameterValue: 'true',
    });
    managementParameters.push({
      ParameterKey: 'EnableTrend',
      ParameterValue: 'true',
    });
    managementParameters.push({
      ParameterKey: 'ManagementAccountId',
      ParameterValue: accounts.management.accountId,
    });
    templates.unshift({
      name: 'groups',
      path: `aws-msp-environments/${awsMspEnvironmentsVersion}`,
      parameters: [],
    });

    const params = checkStackParameters(event, accounts, 'roles');
    templates.unshift({
      name: 'roles',
      path: `aws-msp-environments/${awsMspEnvironmentsVersion}`,
      parameters: params || [],
    });
    templates.unshift({
      name: 'kms',
      path: `aws-msp-environments/${awsMspEnvironmentsVersion}`,
      parameters: [],
    });
  }
  // Push cpm role first to avoid conflict with management
  if (event.accountType === 'management') {
    // TODO How to handle account creation?
    /* templates.unshift({
      name: 'create-hostedzone-association',
      path: `aws-msp-projects/create-hostedzone-association/${createHostedZoneAssociationVersion}`,
      parameters: [
        {
          ParameterKey: 'CICDBucket',
          ParameterValue: 'enabling-services-ci-cd',
        },
        {
          ParameterKey: 'CreateHostedZoneAssociationVersion',
          ParameterValue: createHostedZoneAssociationVersion,
        },
      ],
    }); */
    templates.unshift({
      name: 'health',
      path: `aws-msp-single-use/${awsMspSingleUseVersion}`,
      parameters: [{
        ParameterKey: 'Customer',
        ParameterValue: `${event.customer}`,
      }],
    });
    let params = checkStackParameters(event, accounts, 'cpm');
    templates.unshift({
      name: 'cpm',
      path: `aws-msp-projects/cpm/${cpmVersion}`,
      parameters: [{
        ParameterKey: 'CICDBucket',
        ParameterValue: 'enabling-services-ci-cd',
      },
      {
        ParameterKey: 'CPMVersion',
        ParameterValue: cpmVersion,
      },
        ...params,
      ],
    });
    params = checkStackParameters(event, accounts, 'copy-costcentre-tag');
    templates.unshift({
      name: 'copy-costcentre-tag',
      path: `aws-msp-projects/copy-costcentre-tag/${copyCostCentreTagVersion}`,
      parameters: params || [],
    });
  }
  // ALL accounts
  templates.unshift({
    name: 'management',
    path: `aws-msp-environments/${awsMspEnvironmentsVersion}`,
    parameters: managementParameters,
  });
  return (event.accountType !== 'logging') ? createVpcTemplateInput(event, accounts, vpcs).concat(templates) : templates;
};

const accountsConverter = items => items
  .map((item =>
    AWS.DynamoDB.Converter.unmarshall(item)))
  .reduce((accounts, account) => {
    account.inputs = (account.inputs) ? // eslint-disable-line no-param-reassign
      JSON.parse(account.inputs) : {};
    accounts[account.accountType] = account; // eslint-disable-line no-param-reassign
    return accounts;
  }, {});

const getTemplatesInput = (event, accounts) => {
  const sortKey = (event.accountType === 'service') ?
    `${event.accountType}${event.accountId}` :
    event.accountType;
  return JSON.parse(accounts[sortKey].inputs);
};

const deployTemplates = input => new Promise((resolve, reject) => {
  stepfunctions.startExecution({
    stateMachineArn: deployTemplatesMachine,
    input: JSON.stringify(input),
  }).promise()
    .then(() => {
      resolve(input.global.templates);
    })
    .catch((err) => {
      reject(err);
    });
});

const createVpcsFromEvent = (event) => {
  const vpcs = [];
  // Create vpcs array for loop from params
  const props = Object.keys(event);
  props.forEach((prop) => {
    if (prop.indexOf('vpcCidrBlock') > -1) {
      const suffix = prop.substr(12);
      const vpc = {
        vpcCidrBlock: event[prop],
        sizeMask: event[`sizeMask${suffix}`],
        suffix,
      };
      if (suffix.length > 0) {
        vpc.vpcIdentifier = event[`vpcIdentifier${suffix}`];
      }
      vpcs.push(vpc);
    }
  });
  return vpcs;
};

const handler = (event, context, callback) => {
  const updatedAccountType = (event.accountType === 'service') ? `${event.accountType}${event.accountId}` : event.accountType;
  let updateExpression = 'SET accountId = :accountId, environment = :environment, cloudCheckrAccountId = :cloudCheckrAccountId, cloudCheckrExternalId = :cloudCheckrExternalId, controlled = :controlled';
  const expressionAttributeValues = {
    ':accountId': event.accountId,
    ':environment': event.environment,
    ':controlled': event.controlled,
    ':cloudCheckrAccountId': event.cloudCheckrAccountId,
    ':cloudCheckrExternalId': event.cloudCheckrExternalId,
  };
  const vpcs = createVpcsFromEvent(event);
  vpcs.forEach((vpc) => {
    updateExpression += `, vpcCidrBlock${vpc.suffix} = :vpcCidrBlock${vpc.suffix}`;
    expressionAttributeValues[`:vpcCidrBlock${vpc.suffix}`] = vpc.vpcCidrBlock;
    updateExpression += `, sizeMask${vpc.suffix} = :sizeMask${vpc.suffix}`;
    expressionAttributeValues[`:sizeMask${vpc.suffix}`] = vpc.sizeMask;
  });
  Promise.resolve()
    .then(() => dynamodb.updateItem({
      Key: {
        customer: {
          S: event.customer,
        },
        accountType: {
          S: updatedAccountType,
        },
      },
      TableName: tableName,
      UpdateExpression: updateExpression,
      ExpressionAttributeValues: AWS.DynamoDB.Converter.marshall(expressionAttributeValues),
    }).promise())
    .then(() => dynamodb.query({
      ExpressionAttributeValues: {
        ':customer': {
          S: event.customer,
        },
      },
      KeyConditionExpression: 'customer = :customer',
      TableName: tableName,
    }).promise())
    .then((data) => {
      const accounts = accountsConverter(data.Items);
      const templates = createTemplatesInput(event, accounts, vpcs);
      const input = {
        global: {},
      };
      input.global.templates = templates;
      input.global.assume = {
        accountId: event.accountId,
        externalId: 'ecruteak',
        roleName: 'DatacomCICD',
        roleSessionName: 'DatacomCICD',
      };
      input.global.artefact = {
        bucket: 'enabling-services-ci-cd',
      };
      return deployTemplates(input);
    })
    .then(() => {
      callback(null, event);
    })
    .catch((err) => {
      callback(err);
    });
};

module.exports = {
  accountsConverter,
  createTemplatesInput,
  createVpcTemplateInput,
  getTemplatesInput,
  handler,
};
