variable "name" {
  default     = "soci-demo"
}

variable "region" {
  default     = "eu-north-1"
}

variable "availability_zones" {
  default     = ["eu-north-1a", "eu-north-1b"]
}

variable "cidr" {
  default     = "10.0.0.0/16"
}

variable "private_subnets" {
  default     = ["10.0.0.0/20", "10.0.16.0/20"]
}

variable "public_subnets" {
  default     = ["10.0.32.0/20", "10.0.48.0/20"]
}

variable "service_desired_count" {
  default     = 0
}

variable "container_port" {
  default     = 80
}

variable "container_cpu" {
  default     = 256
}

variable "container_memory" {
  default     = 512
}

variable "health_check_path" {
  default     = "/health"
}

variable "name_suffix" {
  type        = list(string)
  default     = ["soci-enabled", "soci-disabled"]
}

variable "quickstart_s3_bucket" {
  default     = "aws-quickstart"
}

variable "event_filtering_function_name" {
  default     = "EventFilteringLambda"
}

variable "event_filtering_s3_key" {
  default     = "cfn-ecr-aws-soci-index-builder/functions/packages/ecr-image-action-event-filtering/lambda.zip"
}

variable "soci_index_generator_function_name" {
  default     = "SociIndexGenerator"
}

variable "soci_index_generator_s3_key" {
  default     = "cfn-ecr-aws-soci-index-builder/functions/packages/soci-index-generator-lambda/soci_index_generator_lambda.zip"
}

variable "soci_image_filter" {
  default     = "*soci-enabled:latest"
}
