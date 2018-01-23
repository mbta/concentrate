#!/bin/bash
set -e -x -u

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

function update_service_with_desired_count {
    aws ecs update-service --region us-east-1 --cluster $APP --service $awsenv --desired-count $1
}

function no_tasks_are_running {
    local tasks
    tasks=$(aws ecs list-tasks --region us-east-1 --cluster $APP --service $awsenv| jq '.taskArns')
    [[ $tasks = '[]' ]]
}

function exit_if_too_many_checks {
  if [[ $checks -ge 6 ]]; then
    exit 1
  fi
  sleep 5
  checks=$((checks+1))
}
# by setting the desired count to 0, ECS will kill the task that the ECS service is running
# allowing us to update it and start the new one. Check every 5 seconds to see if it's dead
# yet (AWS issues `docker stop` and it could take a moment to spin down). If it's still running
# after several checks, something is wrong and the script should die.
update_service_with_desired_count 0

checks=0
until no_tasks_are_running; do
    echo "tasks still running"
    exit_if_too_many_checks
done

# Update the ECS service to use the new revision of the task definition. Then update the desired
# count back to 1, so the container instance starts up the task. Check periodically to see if the
# task is running yet, and signal deploy failure if it doesn't start up in a reasonable time.
aws ecs update-service --region us-east-1 --cluster $APP --service $awsenv --task-definition $awsenv:$newrevision
update_service_with_desired_count 1
checks=0
while no_tasks_are_running; do
    echo "no tasks running"
    exit_if_too_many_checks
done
