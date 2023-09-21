# fargate-soci-demo
Here's a small demonstration of how SOCI Layers can decrease your Docker image's pull and start time in AWS Fargate.

## Requirements
1. Terraform https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli
2. Docker https://docs.docker.com/engine/install/
3. AWS CLI https://aws.amazon.com/cli/
4. jq https://jqlang.github.io/jq/download/

## Disclamer
Don't implement this terraform environment in a production environment, create a new empty account for the purpose of this demo.

## Terraform
To create the demo environment you need to have Terraform installed. Once it's installed you simply run:
```
terraform init
terraform plan
terraform apply
```
This will create all the needed resources in the `eu-north-1` region. Terraform will create a dedicated VPC with a NAT Gateway, public and private subnets. It will also create the nessesary Lambda functions to filter on Docker image tag, and create the SOCI Index. A ECS Cluster and a ECR Registry will also be created for you.
With the default values, the `demo.sh` script will work as intended.

The ECS Task Definition in `terraform/ecs/main.tf` is configured to use `ARM64`, if you're on a different CPU Architecture while building your Docker image, you might need to adjust that configuration to `X86_64` for Intel/AMD based CPU's.

## Demo script
The `script.sh` will look for Dockerfiles, with a suffix in the `./docker` folder. There's three different types of Dockerfiles present in the repository. Small, normal and huge sized images.
Once all the Docker images are built, they will be pushed into the ECR Registry.

The Lambda function included in this repository will match the default `*soci-enabled:latest`, and create SOCI Layers.
The script will also figure out which task definition is the latest for both SOCI enabled and disabled. And use that while deploying the tasks to ECS Fargate.

Measurements are done after the deployment is completed, i.e. all tasks (default 5) has reached started state. The script will get `createdAt`, `startedAt`, `pullStartedAt` and `pullStoppedAt` from each tasks metadata. Then an average is calculated based on the number of tasks started and will be shown in the outputs of the script.

The measurements will be done for both SOCI enabled and disabled. And when SOCI enabled, the script will not continue until the SOCI Layers exists in the ECR Repository.
After the measuring is done, all started tasks will be automatically stopped.

## Clean-up
Before doing a `terraform destroy`, you must remove the Docker images created by the script, and SOCI Layers.
