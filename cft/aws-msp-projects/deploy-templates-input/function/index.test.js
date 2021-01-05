const index = require('./index');

describe('Map from DynamoDB to account structure', () => {
    test('Happy path', () => {
        const items = [{
            accountId: {
                S: '12345678'
            },
            accountType: {
                S: 'logging'
            }
        }];
        expect(index.accountsConverter(items)).toEqual({
            logging: {
                accountId: '12345678',
                accountType: 'logging'
            }
        });
    })

});

describe('Create template input', () => {
    test('Logging happy path', () => {
        const event = {
            accountId: '12345678',
            accountType: 'logging',
            cloudCheckrAccountId: 'CC-123',
            cloudCheckrExternalId: 'CC-EXT',
            controlled: 'true',
            customer: 'Test Customer',
            environment: 'Logging'
        }
        const accounts = {
            logging: {
                accountId: '12345678',
                accountType: 'logging'
            }
        };
        expect(index.createTemplatesInput(event, accounts)).toEqual([
            {
                name: 'management',
                parameters: [
                    { ParameterKey: 'EnableCloudCheckr', ParameterValue: 'true' },
                    { ParameterKey: 'CloudCheckrAccountId', ParameterValue: 'CC-123' },
                    { ParameterKey: 'CloudCheckrExternalId', ParameterValue: 'CC-EXT' }
                ]
            },
            {
                name: 'alerts',
                parameters: [
                    { ParameterKey: 'Environment', ParameterValue: 'Test Customer Logging' },
                    { ParameterKey: 'EnableWarnings', ParameterValue: 'true' }
                ]
            },
            {
                name: 'config',
                parameters: [
                    { ParameterKey: 'AccountId', ParameterValue: '12345678' }
                ]
            },
            {
                name: 'cloudtrail',
                parameters: [
                    { ParameterKey: 'AccountId', ParameterValue: '12345678' }
                ]
            },
            {
                name: 'logging',
                path: 'aws-msp-single-use/undefined',
                parameters: []
            }
        ]);
    })
    test('Management happy path', () => {
        const event = {
            accountId: '910111213',
            accountType: 'management',
            cloudCheckrAccountId: 'CC-123',
            cloudCheckrExternalId: 'CC-EXT',
            controlled: 'true',
            customer: 'Test Customer',
            environment: 'Management',
            vpcCidrBlock: '10.98.0.0/23',
            sizeMask: '7'
        }
        const accounts = {
            logging: {
                accountId: '12345678',
                accountType: 'logging'
            },
            management: {
                accountId: '910111213',
                accountType: 'management'
            },
        };
        expect(index.createTemplatesInput(event, accounts)).toEqual([
            {
                file: 'sg-management.template.json',
                name: 'sg-management',
                parameters: [
                    { ParameterKey: 'ActiveDirectorySecurityGroup', ParameterValue: '' },
                    { ParameterKey: 'JumpHostSecurityGroup', ParameterValue: '' },
                    { ParameterKey: 'TrendMicroSecurityGroup', ParameterValue: '' },
                    { ParameterKey: 'WSUSSecurityGroup', ParameterValue: '' }
                ]
            },
            {
                file: 'natgateways.template.json',
                name: 'natgateways',
                parameters: []
            },
            {
                file: 'endpoints.template.json',
                name: 'endpoints',
                parameters: []
            },
            {
                file: 'nacls.template.json',
                name: 'nacls',
                parameters: []
            },
            {
                file: 'routes.template.json',
                name: 'routes',
                parameters: []
            },
            {
                file: 'vpc.template.json',
                name: 'vpc',
                parameters: [
                    { ParameterKey: 'Name', ParameterValue: 'Test Customer Management' },
                    { ParameterKey: 'VPCCidrBlock', ParameterValue: '10.98.0.0/23' },
                    { ParameterKey: 'SizeMask', ParameterValue: '7' }
                ]
            },
            {
                name: 'management',
                parameters: [
                    { ParameterKey: 'EnableCloudCheckr', ParameterValue: 'true' },
                    { ParameterKey: 'CloudCheckrAccountId', ParameterValue: 'CC-123' },
                    { ParameterKey: 'CloudCheckrExternalId', ParameterValue: 'CC-EXT' },
                    { ParameterKey: 'EnableCPM', ParameterValue: 'true' },
                    { ParameterKey: 'EnableTrend', ParameterValue: 'true' },
                    { ParameterKey: 'ManagementAccountId', ParameterValue: '910111213' },
                ]
            },
            {
                name: 'kms',
                parameters: []
            },
            {
                name: 'roles',
                parameters: []
            },
            {
                name: 'groups',
                parameters: []
            },
            {
                name: 'alerts',
                parameters: [
                    { ParameterKey: 'Environment', ParameterValue: 'Test Customer Management' },
                    { ParameterKey: 'EnableWarnings', ParameterValue: 'true' }
                ]
            },
            {
                name: 'config',
                parameters: [
                    { ParameterKey: 'AccountId', ParameterValue: '12345678' }
                ]
            },
            {
                name: 'cloudtrail',
                parameters: [
                    { ParameterKey: 'AccountId', ParameterValue: '12345678' }
                ]
            }
        ]);
    })
    test('Service account happy path', () => {
        const event = {
            accountId: '1415161718',
            accountType: 'service',
            cloudCheckrAccountId: 'CC-123',
            cloudCheckrExternalId: 'CC-EXT',
            controlled: 'false',
            customer: 'Test Customer',
            environment: 'Production',
            vpcCidrBlock: '10.98.1.0/23',
            sizeMask: '7'
        }
        const accounts = {
            logging: {
                accountId: '12345678',
                accountType: 'logging'
            },
            management: {
                accountId: '910111213',
                accountType: 'management',
                activeDirectorySecurityGroup: 'sg-123',
                jumpBoxSecurityGroup: 'sg-456',
                trendSecurityGroup: 'sg-789',
                wsusSecurityGroup: 'sg-101',
                vpcCidrBlock: '10.98.0.0/23',
                vpcId: 'vpc-123'
            },
            service1415161718: {
                accountId: '1415161718',
                accountType: 'service'
            },
        };
        expect(index.createTemplatesInput(event, accounts)).toEqual([
            {
                file: 'sg-management.template.json',
                name: 'sg-management',
                parameters: [
                    { ParameterKey: 'ActiveDirectorySecurityGroup', ParameterValue: 'sg-123' },
                    { ParameterKey: 'JumpHostSecurityGroup', ParameterValue: 'sg-456' },
                    { ParameterKey: 'TrendMicroSecurityGroup', ParameterValue: 'sg-789' },
                    { ParameterKey: 'WSUSSecurityGroup', ParameterValue: 'sg-101' }
                ]
            },
            {
                file: 'natgateways.template.json',
                name: 'natgateways',
                parameters: []
            },
            {
                file: 'endpoints.template.json',
                name: 'endpoints',
                parameters: []
            },
            {
                file: 'nacls.template.json',
                name: 'nacls',
                parameters: []
            },
            {
                file: 'peering-requester.template.json',
                name: 'peering-requester',
                parameters: [
                    { ParameterKey: 'PeerVpcId', ParameterValue: 'vpc-123' },
                    { ParameterKey: 'DestinationCidrBlock', ParameterValue: '10.98.0.0/23' },
                    { ParameterKey: 'PeerOwnerId', ParameterValue: '910111213' },
                    { ParameterKey: 'PeerRoleArn', ParameterValue: 'arn:aws:iam::910111213:role/Peering-Accepter-Role' }
                ]
            },
            {
                file: 'routes.template.json',
                name: 'routes',
                parameters: []
            },
            {
                file: 'vpc.template.json',
                name: 'vpc',
                parameters: [
                    { ParameterKey: 'Name', ParameterValue: 'Test Customer Production' },
                    { ParameterKey: 'VPCCidrBlock', ParameterValue: '10.98.1.0/23' },
                    { ParameterKey: 'SizeMask', ParameterValue: '7' }
                ]
            },
            {
                name: 'management',
                parameters: [
                    { ParameterKey: 'EnableCloudCheckr', ParameterValue: 'true' },
                    { ParameterKey: 'CloudCheckrAccountId', ParameterValue: 'CC-123' },
                    { ParameterKey: 'CloudCheckrExternalId', ParameterValue: 'CC-EXT' },
                    { ParameterKey: 'EnableCPM', ParameterValue: 'true' },
                    { ParameterKey: 'EnableTrend', ParameterValue: 'true' },
                    { ParameterKey: 'ManagementAccountId', ParameterValue: '910111213' },
                ]
            },
            {
                name: 'kms',
                parameters: []
            },
            {
                name: 'roles',
                parameters: []
            },
            {
                name: 'groups',
                parameters: []
            },
            {
                name: 'alerts',
                parameters: [
                    { ParameterKey: 'Environment', ParameterValue: 'Test Customer Production' },
                    { ParameterKey: 'EnableWarnings', ParameterValue: 'false' }
                ]
            },
            {
                name: 'config',
                parameters: [
                    { ParameterKey: 'AccountId', ParameterValue: '12345678' }
                ]
            },
            {
                name: 'cloudtrail',
                parameters: [
                    { ParameterKey: 'AccountId', ParameterValue: '12345678' }
                ]
            }
        ]);
    })
    test('Service account with 2 VPCs happy path', () => {
        const event = {
            accountId: '1415161718',
            accountType: 'service',
            cloudCheckrAccountId: 'CC-123',
            cloudCheckrExternalId: 'CC-EXT',
            controlled: 'false',
            customer: 'Test Customer',
            environment: 'Production',
            vpcCidrBlock: '10.98.1.0/23',
            sizeMask: '7',
            vpcCidrBlock2: '10.98.2.0/23',
            sizeMask2: '7',
            vpcIdentifier2: '2'
        }
        const accounts = {
            logging: {
                accountId: '12345678',
                accountType: 'logging'
            },
            management: {
                accountId: '910111213',
                accountType: 'management',
                activeDirectorySecurityGroup: 'sg-123',
                jumpBoxSecurityGroup: 'sg-456',
                trendSecurityGroup: 'sg-789',
                wsusSecurityGroup: 'sg-101',
                vpcCidrBlock: '10.98.0.0/23',
                vpcId: 'vpc-123'
            },
            service1415161718: {
                accountId: '1415161718',
                accountType: 'service'
            },
        };
        expect(index.createTemplatesInput(event, accounts)).toEqual([
            {
                file: 'sg-management.template.json',
                name: 'sg-management-2',
                parameters: [
                    { ParameterKey: 'ActiveDirectorySecurityGroup', ParameterValue: 'sg-123' },
                    { ParameterKey: 'JumpHostSecurityGroup', ParameterValue: 'sg-456' },
                    { ParameterKey: 'TrendMicroSecurityGroup', ParameterValue: 'sg-789' },
                    { ParameterKey: 'WSUSSecurityGroup', ParameterValue: 'sg-101' }
                ]
            },
            {
                file: 'natgateways.template.json',
                name: 'natgateways-2',
                parameters: []
            },
            {
                file: 'endpoints.template.json',
                name: 'endpoints-2',
                parameters: []
            },
            {
                file: 'nacls.template.json',
                name: 'nacls-2',
                parameters: []
            },
            {
                file: 'peering-requester.template.json',
                name: 'peering-requester-2',
                parameters: [
                    { ParameterKey: 'PeerVpcId', ParameterValue: 'vpc-123' },
                    { ParameterKey: 'DestinationCidrBlock', ParameterValue: '10.98.0.0/23' },
                    { ParameterKey: 'PeerOwnerId', ParameterValue: '910111213' },
                    { ParameterKey: 'PeerRoleArn', ParameterValue: 'arn:aws:iam::910111213:role/Peering-Accepter-Role' }
                ]
            },
            {
                file: 'routes.template.json',
                name: 'routes-2',
                parameters: []
            },
            {
                file: 'vpc.template.json',
                name: 'vpc-2',
                parameters: [
                    { ParameterKey: 'Name', ParameterValue: 'Test Customer Production' },
                    { ParameterKey: 'VPCCidrBlock', ParameterValue: '10.98.2.0/23' },
                    { ParameterKey: 'SizeMask', ParameterValue: '7' }
                ]
            },
            {
                file: 'sg-management.template.json',
                name: 'sg-management',
                parameters: [
                    { ParameterKey: 'ActiveDirectorySecurityGroup', ParameterValue: 'sg-123' },
                    { ParameterKey: 'JumpHostSecurityGroup', ParameterValue: 'sg-456' },
                    { ParameterKey: 'TrendMicroSecurityGroup', ParameterValue: 'sg-789' },
                    { ParameterKey: 'WSUSSecurityGroup', ParameterValue: 'sg-101' }
                ]
            },
            {
                file: 'natgateways.template.json',
                name: 'natgateways',
                parameters: []
            },
            {
                file: 'endpoints.template.json',
                name: 'endpoints',
                parameters: []
            },
            {
                file: 'nacls.template.json',
                name: 'nacls',
                parameters: []
            },
            {
                file: 'peering-requester.template.json',
                name: 'peering-requester',
                parameters: [
                    { ParameterKey: 'PeerVpcId', ParameterValue: 'vpc-123' },
                    { ParameterKey: 'DestinationCidrBlock', ParameterValue: '10.98.0.0/23' },
                    { ParameterKey: 'PeerOwnerId', ParameterValue: '910111213' },
                    { ParameterKey: 'PeerRoleArn', ParameterValue: 'arn:aws:iam::910111213:role/Peering-Accepter-Role' }
                ]
            },
            {
                file: 'routes.template.json',
                name: 'routes',
                parameters: []
            },
            {
                file: 'vpc.template.json',
                name: 'vpc',
                parameters: [
                    { ParameterKey: 'Name', ParameterValue: 'Test Customer Production' },
                    { ParameterKey: 'VPCCidrBlock', ParameterValue: '10.98.1.0/23' },
                    { ParameterKey: 'SizeMask', ParameterValue: '7' }
                ]
            },
            {
                name: 'management',
                parameters: [
                    { ParameterKey: 'EnableCloudCheckr', ParameterValue: 'true' },
                    { ParameterKey: 'CloudCheckrAccountId', ParameterValue: 'CC-123' },
                    { ParameterKey: 'CloudCheckrExternalId', ParameterValue: 'CC-EXT' },
                    { ParameterKey: 'EnableCPM', ParameterValue: 'true' },
                    { ParameterKey: 'EnableTrend', ParameterValue: 'true' },
                    { ParameterKey: 'ManagementAccountId', ParameterValue: '910111213' },
                ]
            },
            {
                name: 'kms',
                parameters: []
            },
            {
                name: 'roles',
                parameters: []
            },
            {
                name: 'groups',
                parameters: []
            },
            {
                name: 'alerts',
                parameters: [
                    { ParameterKey: 'Environment', ParameterValue: 'Test Customer Production' },
                    { ParameterKey: 'EnableWarnings', ParameterValue: 'false' }
                ]
            },
            {
                name: 'config',
                parameters: [
                    { ParameterKey: 'AccountId', ParameterValue: '12345678' }
                ]
            },
            {
                name: 'cloudtrail',
                parameters: [
                    { ParameterKey: 'AccountId', ParameterValue: '12345678' }
                ]
            }
        ]);
    })
});


