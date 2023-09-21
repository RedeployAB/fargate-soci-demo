data "aws_iam_policy" "basic_execution_role" {
  name = "AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "invoke_soci_lambda" {
  statement {
    actions = [
      "lambda:InvokeFunction",
      "lambda:InvokeAsync",
    ]
    resources = [
      aws_lambda_function.soci_index_generator.arn
    ]
  }
}

data "aws_iam_policy_document" "allow_push_pull_ecr" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:CompleteLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_cloudwatch_log_group" "event_filtering" {
  name              = "/aws/lambda/${var.event_filtering_function_name}"
  retention_in_days = 1
}

resource "aws_lambda_function" "event_filtering" {
  function_name = var.event_filtering_function_name
  description = "Given an Amazon ECR image action event from EventBridge, matches event detail.repository-name and detail.image-tag against one or more known patterns and invokes Executor Lambda with the same event on a match."
  handler = "ecr_image_action_event_filtering_lambda_function.lambda_handler"
  runtime = "python3.9"
  role = aws_iam_role.event_filtering.arn
  timeout = 900
  s3_bucket = var.quickstart_s3_bucket
  s3_key = var.event_filtering_s3_key

  environment {
    variables = {
      soci_repository_image_tag_filters = var.soci_image_filter
      soci_index_generator_lambda_arn = aws_lambda_function.soci_index_generator.arn
    }
  }
}

resource "aws_iam_role" "event_filtering" {
  name                = "${var.name}-ECRImageActionEventFilteringLambdaRole"
  managed_policy_arns = [data.aws_iam_policy.basic_execution_role.arn]
  inline_policy {
    name = "invoke_soci_lambda"
    policy = data.aws_iam_policy_document.invoke_soci_lambda.json
  }
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
	{
	  "Action": "sts:AssumeRole",
	  "Principal": {
		"Service": "lambda.amazonaws.com"
	  },
	  "Effect": "Allow",
	  "Sid": ""
	}
  ]
}
EOF
}

resource "aws_cloudwatch_event_rule" "image_action_rule" {
  name = "${var.name}-ECRImageActionEventBridgeRule"
  description = "Invokes Amazon ECR image action event filtering Lambda function when image is successfully pushed to ECR."
  event_pattern = <<EOF
{
  "detail-type": ["ECR Image Action"],
  "source": ["aws.ecr"],
  "detail": {
    "result": ["SUCCESS"],
    "action-type": ["PUSH"]
  },
  "region": ["${var.region}"]
}
EOF
}

resource "aws_cloudwatch_event_target" "image_action_rule" {
  target_id = "image_action_rule"
  rule      = aws_cloudwatch_event_rule.image_action_rule.name
  arn       = aws_lambda_function.event_filtering.arn
}

resource "aws_lambda_permission" "image_action_rule" {
  statement_id  = "AllowExecutionFromCloudWatchEvents"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.event_filtering.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.image_action_rule.arn
}


resource "aws_cloudwatch_log_group" "soci_index_generator" {
  name              = "/aws/lambda/${var.soci_index_generator_function_name}"
  retention_in_days = 1
}

resource "aws_lambda_function" "soci_index_generator" {
  function_name = var.soci_index_generator_function_name
  description = "Given an Amazon ECR container repository and image, Lambda generates image SOCI artifacts and pushes to repository."
  handler = "main"
  runtime = "go1.x"
  role = aws_iam_role.soci_index_generator.arn
  timeout = 900
  s3_bucket = var.quickstart_s3_bucket
  s3_key = var.soci_index_generator_s3_key
  memory_size = 1024
  ephemeral_storage {
    size = 10240
  }
}

resource "aws_iam_role" "soci_index_generator" {
  name                = "${var.name}-SociIndexGeneratorLambdaRole"
  managed_policy_arns = [data.aws_iam_policy.basic_execution_role.arn]
  inline_policy {
    name = "allow_push_pull_ecr"
    policy = data.aws_iam_policy_document.allow_push_pull_ecr.json
  }
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
	{
	  "Action": "sts:AssumeRole",
	  "Principal": {
		"Service": "lambda.amazonaws.com"
	  },
	  "Effect": "Allow",
	  "Sid": ""
	}
  ]
}
EOF
}
