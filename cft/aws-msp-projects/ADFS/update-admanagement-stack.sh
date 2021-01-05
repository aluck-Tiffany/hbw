#!/bin/bash
# 
# update_stack.sh
#   Shell script to deploy/update Microsoft AD/ADmanagement tools statck
# Dependecy: 
#   - pip
#   - AWS CLI configured with credential and default AWS regions
# Author: Eric Ho (eric.ho@datacom.com.au, hbwork@gmail.com, https://www.linkedin.com/in/hbwork/)
#

# AWS CLI default profile 
ProfileName=${1:-olgr-management}

#Stack Deploy Parameters
StackName="ad-management"
Template="ad-management.template.json"
MicrosoftADPW="Datacom2018!"
AMIID="ami-0ecbd53f8048315c9"
# End of Customzation 

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
    	  ParameterKey=MicrosoftADPW,ParameterValue=${MicrosoftADPW} \
    	  ParameterKey=AMIID,ParameterValue=${AMIID} 

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
    	  ParameterKey=MicrosoftADPW,ParameterValue=${MicrosoftADPW} \
    	  ParameterKey=AMIID,ParameterValue=${AMIID} 

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
