#!/bin/bash
set -e -u

sudo pip install -U awscli

# bash script should be called with aws environment ($APP-dev / $APP-dev-green / $APP-prod)
# other required configuration:
# * APP
# * DOCKER_REPO
awsenv=$1

# build docker image and tag it with git hash and aws environment
githash=$(git rev-parse --short HEAD)

# get JSON describing task definition currently running on AWS
# use it as basis for new revision, but replace image with the one built above
taskdefinition=$(aws ecs describe-task-definition --region us-east-1 --task-definition $awsenv)
taskdefinition=$(echo $taskdefinition | jq ".taskDefinition | del(.status) | del(.taskDefinitionArn) | del(.requiresAttributes) | del(.revision) | del(.compatibilities)")
newcontainers=$(echo $taskdefinition | jq ".containerDefinitions | map(.image=\"$DOCKER_REPO:git-$githash\")")
aws ecs register-task-definition --region us-east-1 --family $awsenv --cli-input-json "$taskdefinition" --container-definitions "$newcontainers"
newrevision=$(aws ecs describe-task-definition --region us-east-1 --task-definition $awsenv | jq '.taskDefinition.revision')

function task_count_eq {
    local tasks
    task_count=$(aws ecs list-tasks --region us-east-1 --cluster $APP --service $awsenv| jq '.taskArns | length')
    [[ $task_count = "$1" ]]
}

function exit_if_too_many_checks {
  if [[ $checks -ge 60 ]]; then
    exit 1
  fi
  sleep 5
  checks=$((checks+1))
}

expected_count=$(aws ecs list-tasks --region us-east-1 --cluster $APP --service $awsenv| jq '.taskArns | length')

aws ecs update-service --region us-east-1 --cluster $APP --service $awsenv --task-definition $awsenv:$newrevision
if  [[ $expected_count = "0" ]]; then
    echo Environment $APP:$awsenv is not running!
    echo
    echo We updated the definition: you can manually set the desired instances to 1.
    exit 1
fi

checks=0
while task_count_eq $expected_count; do
    echo not yet started...
    exit_if_too_many_checks
done

checks=0
until task_count_eq $expected_count; do
    echo old task not stopped...
    exit_if_too_many_checks
done
