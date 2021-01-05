#!/bin/bash
# 
# update_stack.sh
#   Shell script to deploy/update AWS CloudFormation Stack
# Dependecy: 
#   - pip
#   - AWS CLI configured with credential and default AWS regions
# Author: Eric Ho (eric.ho@datacom.com.au, hbwork@gmail.com, https://www.linkedin.com/in/hbwork/)
#

# AWS CLI default profile 
ProfileName=${1:-demomsp-mgmt}

#Stack Deploy Parameters
StackName="bootstrap"
CICDBucket="dcp-install"
CertificateArn="arn:aws:acm:us-east-1:131100401635:certificate/19b962dc-4d82-41f6-9187-73ed779de4cd"
PolicyList='windows2016:14,windows2012r2:7'
Route53HostedZone="Z1LNMPGULJSD7T"
Route53ZoneName="demo.hcs.datacom.com.au"

# End of Customzation 

Template="../bootstrap_demomsp_test.template.json"

#cd function
#npm run lint
#npm run package
#npm run s3upload

BootstrapVersion=`aws s3 ls s3://dcp-install/aws-msp-projects/bootstrap/ |grep -v latest|awk '{print $2}'|sort | tail -1|sed s_/__`

echo "Update Bootstrap version to $BootstrapVersion"

aws cloudformation validate-template --template-body file://${Template}

set +e

StackStatus=$(aws cloudformation describe-stacks --stack-name ${StackName} --query Stacks[0].StackStatus --profile ${ProfileName} --output text)

set -e

if [ ${#StackStatus} -eq 0 ]
then
    echo "Please ignore the Validation Error messagege above. Create CloudFormation stack ${StackName} ..."

    aws cloudformation create-stack --stack-name ${StackName} \
	--template-body file://${Template} \
    	--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    	--profile ${ProfileName} \
    	--parameters \
    	  ParameterKey=CICDBucket,ParameterValue=${CICDBucket} \
          ParameterKey=BootstrapVersion,ParameterValue=${BootstrapVersion} \
    	  ParameterKey=CertificateArn,ParameterValue=${CertificateArn} \
    	  #ParameterKey=PolicyList,ParameterValue="${PolicyList}" \
          ParameterKey=Route53HostedZone,ParameterValue=${Route53HostedZone} \
          ParameterKey=Route53ZoneName,ParameterValue=${Route53ZoneName} 

    sleep 30

#elif [ ${StackStatus} == 'CREATE_COMPLETE' -o ${StackStatus} == 'UPDATE_COMPLETE' -o ${StatkStatus} == 'UPDATE_ROLLBACK_COMPLETE' ]
elif [ $(echo ${StackStatus} | grep _COMPLETE) ]
then
    echo "Update stack ${StackName} ..."

    ChangeSetName="${StackName}-$(uuidgen)"

    aws cloudformation create-change-set --stack-name ${StackName} \
	--template-body file://${Template} \
    	--capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
    	--profile ${ProfileName} \
      	--change-set-name ${ChangeSetName} \
    	--parameters \
    	  ParameterKey=CICDBucket,ParameterValue=${CICDBucket} \
          ParameterKey=BootstrapVersion,ParameterValue=${BootstrapVersion} \
    	  ParameterKey=CertificateArn,ParameterValue=${CertificateArn} \
    	  #ParameterKey=PolicyList,ParameterValue="${PolicyList}" \
          ParameterKey=Route53HostedZone,ParameterValue=${Route53HostedZone} \
          ParameterKey=Route53ZoneName,ParameterValue=${Route53ZoneName} 

    sleep 10

    ChangeSetStatus=$(aws cloudformation describe-change-set  \
    	--profile ${ProfileName} \
        --change-set-name ${ChangeSetName} \
        --stack-name ${StackName} \
        --query Status \
        --output text)

    #CREATE_IN_PROGRESS , CREATE_COMPLETE , or FAILED
    while [ ${ChangeSetStatus} == 'CREATE_IN_PROGRESS' ]
    do
        sleep 30
        ChangeSetStatus=$(aws cloudformation describe-change-set \
            --change-set-name ${ChangeSetName} \
    	    --profile ${ProfileName} \
            --change-set-name ${ChangeSetName} \
            --stack-name ${StackName} \
            --query Status \
            --output text)
    done

	  if [ ${ChangeSetStatus} == 'FAILED' ]
	  then
     	 	echo "No change found in ${Template}, quit ..."
    else
        echo "Execute change set ${ChangeSetName}"
        aws cloudformation execute-change-set --change-set-name ${ChangeSetName} --stack-name ${StackName} --profile ${ProfileName}
        sleep 30
    fi
else
    echo "Failed to create or update stack ${StackName} (Unexpected stack status: ${StackStatus})"
    exit 1
fi

StackStatus=$(aws cloudformation describe-stacks \
    --stack-name ${StackName} \
    --query Stacks[0].StackStatus \
    --output text  \
    --profile ${ProfileName})

#CREATE_IN_PROGRESS
#UPDATE_IN_PROGRESS

while [ $StackStatus == "CREATE_IN_PROGRESS" -o $StackStatus == "UPDATE_IN_PROGRESS" ]
do
    sleep 30
    StackStatus=$(aws cloudformation describe-stacks \
      --stack-name ${StackName} \
      --query Stacks[0].StackStatus \
      --output text  \
      --profile ${ProfileName})
done

# CREATE_COMPLETE
# UPDATE_COMPLETE
# UPDATE_COMPLETE_CLEANUP_IN_PROGRESS
if [ $StackStatus != "CREATE_COMPLETE" -a $StackStatus != "UPDATE_COMPLETE_CLEANUP_IN_PROGRESS" -a $StackStatus != "UPDATE_COMPLETE" ]
then
    echo "Create/Update stack failed - ${StackStatus}"
    exit 1
fi

echo "Create/Update stack succeeded"
# __EOF__
