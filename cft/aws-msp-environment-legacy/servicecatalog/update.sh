#!/bin/env bash

Profile=${1:-dcp}

aws cloudformation update-stack --stack-name servicecatalogbucket\
  --template-body file://servicecatalogbucket.template.json \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --profile $Profile
