#!/usr/bin/python

# Jenkins build script to create CloudFormation change sets
# and execute change-sets on 'dev' accounts. 
#
import json
import os
import glob
import time
import itertools
import argparse
import boto3
import botocore
from operator import itemgetter

class DcomCF:
    def create_session(self,**args):
        client = boto3.client('sts')
        response = client.assume_role(**args)
        try:
            session = boto3.Session(
                aws_access_key_id=response['Credentials']['AccessKeyId'],
                aws_secret_access_key=response['Credentials']['SecretAccessKey'],
                aws_session_token=response['Credentials']['SessionToken']
            )
            return session
        except:
            print "[error] Unable to create a boto session"


    def list_cfn_stacks(self,session):
        client = session.client('cloudformation')
        response = client.list_stacks(
            StackStatusFilter=[
                'CREATE_COMPLETE',
                'UPDATE_COMPLETE'
            ]
        )
        return response

    def get_stack_name_from_filename(self,filename):
        return filename.rsplit('.')[0]


    def get_template_summary(self,session, **args):
        client = session.client('cloudformation')
        response = client.get_template_summary(**args)
        return response


    def describe_stacks(self,session, **args):
        client = session.client('cloudformation')
        response = client.describe_stacks(**args)
        return response

    
    def get_template_body(self, session, **args):
        client = session.client('cloudformation')
        response = client.get_template(**args)
        return response['TemplateBody']


    def s3_upload(self,session, filename, bucket, key):
        s3 = session.resource('s3')
        s3.meta.client.upload_file(filename, bucket, key)


    def create_change_set(self,session,stackname,bucketname,parameters,changesetname,description):
        client = session.client('cloudformation')
        cf = boto3.client("cloudformation")
        response = client.create_change_set(
            StackName=stackname,
            TemplateURL="https://s3-ap-southeast-2.amazonaws.com/"+bucketname+"/"+stackname+".template",
            Parameters= parameters,
            Capabilities=[
                'CAPABILITY_IAM',
                'CAPABILITY_NAMED_IAM'
            ],
            ChangeSetName=changesetname,
            Description=description
        )
        # wait till task completes, waiter breaks when create_change_set failes
        try:
            waiter = cf.get_waiter('change_set_create_complete')
            waiter.wait(StackName=stackname,ChangeSetName=changesetname)
        except botocore.exceptions.WaiterError:
            # possibly create_change_set failed
            pass

        return response 



    def describe_change_set(self,session,changesetname,stackname):
        client = session.client('cloudformation')
        response = client.describe_change_set(
                ChangeSetName=changesetname,
                StackName=stackname
            )

        try:
            print("waiting for CREATE_COMPLETE...")
            waiter = client.get_waiter('change_set_create_complete')
            waiter.wait(StackName=stackname,ChangeSetName=changesetname)

            response = client.describe_change_set(
                ChangeSetName=changesetname,
                StackName=stackname
            )

            return response
        except botocore.exceptions.WaiterError:
            return response


    def delete_change_set(self,session,changesetname,stackname):
        client = session.client('cloudformation')
        response = client.delete_change_set(
            ChangeSetName=changesetname,
            StackName=stackname
        )
        return response


    def execute_change_set(self,session,changesetname,stackname):
        client = session.client('cloudformation')
        response = client.execute_change_set(
            ChangeSetName=changesetname,
            StackName=stackname
        )
        return response


# --end of class--




def stack_exist(stackname):
        try:
            stack = dcf.describe_stacks(session,StackName=stackname)
            return True
        except:
            return False


def get_stack_parameters(stackname):
    section = list()
    try:
        stack = dcf.describe_stacks(session,StackName=stackname)
        section = stack['Stacks'][0]['Parameters']
        return sorted(section, key=itemgetter('ParameterKey'), reverse=False)
    except:
        return section 

def get_stack_outputs(stackname):
    section = list()
    try:
        stack = dcf.describe_stacks(session,StackName=stackname)
        section = stack['Stacks'][0]['Outputs']
        return section 

    except:
        return section 


def get_template_parameters(templatename):
    TemplateBody = open(templatename).read()
    summary = dcf.get_template_summary(session, TemplateBody=TemplateBody)
    LocalParameters = list() 
    for item in summary['Parameters']:
        try:
            LocalParameters.append(
                {
                "ParameterKey": item['ParameterKey'], 
                "ParameterValue": item['DefaultValue']
                }
            )
        except KeyError:
            # Default not set
            LocalParameters.append(
                    {
                    "ParameterKey": item['ParameterKey'], 
                    "ParameterValue": ""
                    }
            )
        except:
            return False

    return sorted(LocalParameters, key=itemgetter('ParameterKey'), reverse=False)


def find_key_in_parameters(parameterkey, localparameters):
    if not any(d['ParameterKey'] == parameterkey for d in localparameters):
        return False
    else:
        return True


def append_new_parameters(stackparameters, localparameters):
    for item in localparameters:
        pkey = item['ParameterKey']
        if find_key_in_parameters(pkey, stackparameters):
            pass
        else:
            stackparameters.append(
                {
                "ParameterKey": item['ParameterKey'], 
                "ParameterValue": item['ParameterValue'] 
                }
            )

    return sorted(stackparameters, key=itemgetter('ParameterKey'), reverse=False)

def setup_parameters(stackname, template):
    if stack_exist(stackname):
        Parameters = get_stack_parameters(stackname)
        # get local template parameters
        LocalParameters = get_template_parameters(template)
        if LocalParameters != False:
            return append_new_parameters(Parameters, LocalParameters)
        else:
           #"Local parameters doesn't exist or err"
           return False
    else:
        #"Stack %s doesn't exits" % stackname
        return False 


# TODO: Add 'dev' accounts
def is_dev_account(accountnumber):
    dev_accounts = list()
    dev_accounts.append("224526257458")  
    dev_accounts.append("298291703432") 
    dev_accounts.append("051620370519") 
    dev_accounts.append("945553734850") 
    dev_accounts.append("286907020421")  
    dev_accounts.append("507760001018")
    dev_accounts.append("614850154202")
    dev_accounts.append("227148359287")
    dev_accounts.append("200495984349")
    dev_accounts.append("419070736574")
    dev_accounts.append("849859720021")
    dev_accounts.append("082291192867")
    dev_accounts.append("648342337235")

    if accountnumber in dev_accounts:
        return True
    else:
        return False


def proccess(session, accountnumber, filename, description):
    # Get stack name
    stackname = dcf.get_stack_name_from_filename(filename)

    # Upload file to s3
    dcf.s3_upload(session,templatename,s3_bucket_name,stackname+".template")

    # Setup parameters
    newparameters = setup_parameters(stackname, templatename) 

    # create_change_set
    changesetname="cs-"+str(int(time.time()))
    print "Creating change set %s" % changesetname
    dcf.create_change_set(session,stackname,s3_bucket_name,newparameters,changesetname,description)

    # get change-set status
    print "Checking status of %s" % changesetname
    #time.sleep(2)
    retval = dcf.describe_change_set(session,changesetname,stackname)
    cs_status = retval['Status']
    cs_exe_status = retval['ExecutionStatus']

    if cs_status == "CREATE_COMPLETE":
        # Change set creation successful
        print "Change set %s creation sucessful" % changesetname

        if is_dev_account(aws_account_number):
            print "Executing change set %s" % changesetname
            if cs_exe_status == "AVAILABLE":
                dcf.execute_change_set(session,changesetname,stackname)
            else:
                print "[403] Unable to execute change set"
        else:
            print "%s is not a dev account, skipping change-set execution." % accountnumber

    elif cs_status == "FAILED":
        cs_status_reason = retval['StatusReason']
        if cs_status_reason == no_change_status:
            # Delete the changes-set
            print "[400] Deleting failed changeset %s " % changesetname
            print "[400] %s" % cs_status_reason
            dcf.delete_change_set(session,changesetname,stackname)
        else:
            print "[401] Change set creation failed"

    else:
        print "[402] Unknown change set status %s" % cs_status




parser = argparse.ArgumentParser(description='CloudFromation create change set')
parser.add_argument("-a", "--account", help="AWS account number", type=str)
parser.add_argument("-d", "--description", help="Changeset description", default="Created by Jenkins", type=str)
parser.add_argument("-t", "--templatename", help="Template", type=str)
args = parser.parse_args()

# Setting arg values 
aws_account_number = args.account
description = args.description
templatename = args.templatename


if args.account is None:
    print "[error] Account number required"
    exit(1)



no_change_status="The submitted information didn't contain changes. Submit different information to create a change set."

s3_bucket_name=aws_account_number+"-cf"
role_arn = "arn:aws:iam::"+aws_account_number+":role/changesets"
# Initiate an instance of DcomCF
dcf = DcomCF()
session  = dcf.create_session(RoleArn=role_arn,RoleSessionName='Jenkins')

# for each file in the current directory run the process
for templatename in glob.glob("*.json"):
    print "Processing template %s" % templatename
    proccess(session, aws_account_number, templatename,description)






# Change set creation conditions
# --------------------------------
# Resources: Creates a change set
# Outputs: Creates a change set
# Metadata: Doesn't create a changeset
# Parameters: Doesn't create a changeset 
# Mappings: Doesn't create a changeset
# Conditions: Doesn't create a changeset
