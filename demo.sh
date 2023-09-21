#!/usr/bin/env bash
export AWS_DEFAULT_REGION="eu-north-1"

IMAGE_NAME="soci-demo"
DOCKERFILE_SUFFIXES=( "huge" "normal" "small" )
ECR_REPO_SUFFIXES=( "soci-enabled" "soci-disabled" )
ACCOUNT_ID="$(aws sts get-caller-identity --query "Account" --output text)"
REPO_URI="${ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com"
TASK_LAUNCH_COUNT="5"

# Break out of function when SOCI layers exist for pushed image/tag
function WaitSociCreated () {
    local check="sha256-${1}"
    until [[ $(aws ecr list-images --repository-name soci-demo-soci-enabled | jq -r ".imageIds[] | select(.imageTag != null) | select(.imageTag | contains(\"${check}\")) | .imageTag") == "${check}" ]]; do
        sleep 10
    done
}

# Build, tag and push Docker image based on suffix
function BuildAndPush () {
    local suffix="$1"
    docker build --no-cache -f "./docker/Dockerfile-${suffix}" -t "${IMAGE_NAME}:${suffix}" .
    for repo_suffix in ${ECR_REPO_SUFFIXES[@]}; do
        local tag="${REPO_URI}/${IMAGE_NAME}-${repo_suffix}:latest"
        docker tag ${IMAGE_NAME}:${suffix} ${tag}
        docker push --quiet ${tag}
    done
}

function MeasureTaskStart () {
    local task_arn="$1"
    local started_tasks="$(aws ecs run-task --count ${TASK_LAUNCH_COUNT} --launch-type FARGATE --task-definition ${task_arn} --cluster ${IMAGE_NAME}-cluster --network-configuration "awsvpcConfiguration={subnets=[${VPC_SUBNETS}]}" | jq -r '.tasks[].taskArn')"
    aws ecs wait tasks-running --cluster "${IMAGE_NAME}-cluster" --tasks ${started_tasks}

    declare -a diff_available
    declare -a diff_pull
    for task in ${started_tasks[@]}; do
        local time=( $(aws ecs describe-tasks --tasks ${task} --cluster ${IMAGE_NAME}-cluster | jq -r '.tasks[].createdAt, .tasks[].startedAt, .tasks[].pullStartedAt, .tasks[].pullStoppedAt') )
        local diff_available+=("$(( $(date -d "${time[1]}" "+%s") - $(date -d "${time[0]}" "+%s") ))")
        local diff_pull+=("$(( $(date -d "${time[3]}" "+%s") - $(date -d "${time[2]}" "+%s") ))")
    done

    echo "    Average time to start a tasks was $(echo ${diff_available[@]} | awk '{s+=$0}END{print s/NR}' RS=" ") seconds"
    echo "    Average time to pull a image was $(echo ${diff_pull[@]} | awk '{s+=$0}END{print s/NR}' RS=" ") seconds"

    for arn in ${started_tasks[@]}; do
        aws ecs stop-task --cluster ${IMAGE_NAME}-cluster --task ${arn} > /dev/null
    done
}


# Login to AWS ECR Registry
aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${REPO_URI} > /dev/null


# Loop through all types of Dockerfile's in the array DOCKERFILE_SUFFIXES
for suffix in ${DOCKERFILE_SUFFIXES[@]}; do
    echo "--- Building and pushing Docker image with suffix ${suffix^^} ---"
    BuildAndPush "${suffix}"

    # Get taskArns into variables
    SOCI_ENABLED_TASK_ARN="$(aws ecs list-task-definitions --family-prefix ${IMAGE_NAME}-task-soci-enabled --sort DESC --max-items 1 | jq -r .taskDefinitionArns[])"
    SOCI_DISABLED_TASK_ARN="$(aws ecs list-task-definitions --family-prefix ${IMAGE_NAME}-task-soci-disabled --sort DESC --max-items 1 | jq -r .taskDefinitionArns[])"

    # Get subnets from current cluster config
    VPC_SUBNETS=$(aws ecs describe-services --services ${IMAGE_NAME}-service-soci-enabled --cluster ${IMAGE_NAME}-cluster | jq -r '.services[].deployments[].networkConfiguration.awsvpcConfiguration.subnets | join(",")')

    # Run the start task and compare in a function instead
    echo "-#- Starting SOCI-DISABLED-TASKS in ECS to measure start and pull times -#-"
    MeasureTaskStart "${SOCI_DISABLED_TASK_ARN}"

    SHA256=$(docker inspect "${REPO_URI}/${IMAGE_NAME}-${ECR_REPO_SUFFIXES[0]}:latest" | jq -r '.[].RepoDigests[0] | split(":")[1]')
    echo "--- Waiting for SOCI layers to be present for the image with sha256:${SHA256} ---"
    WaitSociCreated "${SHA256}"

    # Run the start task and compare in a function instead
    echo "-#- Starting SOCI-ENABLED-TASKS in ECS to measure start and pull times -#-"
    MeasureTaskStart "${SOCI_ENABLED_TASK_ARN}"
done
