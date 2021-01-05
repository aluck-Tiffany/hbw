#!/bin/bash
# 
# deploy_test_instances.sh
#   Shell script to deploy Amzon Linux 1 and RHEL 7 instance to test bootstrap API
#
# Author: Eric Ho (eric.ho@datacom.com.au, hbwork@gmail.com, https://www.linkedin.com/in/hbwork/)
#

# AWS CLI default profile 
ProfileName=${1:-demomsp-dev}
BaseUrl="demo.hcs.datacom.com.au"

timestamp=$(date +%Y%m%d%H%M)
Template="bootstrap-test-instance.template.json"

aws cloudformation validate-template --template-body file://${Template}

echo "Launch Amazon Linux in CIS enforce mode"
aws cloudformation create-stack --stack-name bootstrap-amz1-enforce-${timestamp} \
	--template-body file://${Template} \
    	--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    	--profile ${ProfileName} \
    	--parameters \
    	  ParameterKey=OS,ParameterValue="amazonlinux1" \
          ParameterKey=EnforceMode,ParameterValue="enforce" \
          ParameterKey=BaseUrl,ParameterValue=${BaseUrl}


echo "Launch Amazon Linux in CIS Report mode"
aws cloudformation create-stack --stack-name bootstrap-amz1-report-${timestamp} \
	--template-body file://${Template} \
    	--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    	--profile ${ProfileName} \
    	--parameters \
    	  ParameterKey=OS,ParameterValue="amazonlinux1" \
          ParameterKey=EnforceMode,ParameterValue="report" \
          ParameterKey=BaseUrl,ParameterValue=${BaseUrl}

echo "Launch RHEL-7 Linux in CIS enforce mode"
aws cloudformation create-stack --stack-name bootstrap-rhel7-enforce-${timestamp} \
	--template-body file://${Template} \
    	--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    	--profile ${ProfileName} \
    	--parameters \
    	  ParameterKey=OS,ParameterValue="rhel-7" \
          ParameterKey=EnforceMode,ParameterValue="enforce" \
          ParameterKey=BaseUrl,ParameterValue=${BaseUrl}


echo "Launch RHEL-7Linux in CIS Report mode"
aws cloudformation create-stack --stack-name bootstrap-rhel7-report-${timestamp} \
	--template-body file://${Template} \
    	--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    	--profile ${ProfileName} \
    	--parameters \
    	  ParameterKey=OS,ParameterValue="rhel-7" \
          ParameterKey=EnforceMode,ParameterValue="report" \
          ParameterKey=BaseUrl,ParameterValue=${BaseUrl}

# __EOF__
