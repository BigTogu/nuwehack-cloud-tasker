provider "aws" {
  access_key                  = "test"
  secret_key                  = "test"
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true

  endpoints {
    apigateway     = "http://localhost:4566"
    cloudwatch     = "http://localhost:4566"
    lambda         = "http://localhost:4566"
    dynamodb       = "http://localhost:4566"
    events         = "http://localhost:4566"
    iam            = "http://localhost:4566"
    sts            = "http://localhost:4566"
    s3             = "http://localhost:4566"
  }
}

# Variables
variable "TABLE_NAME" {
  type    = string
  default = "TaskTable"
}

variable "BUCKET_NAME" {
  type    = string
  default = "taskstorage"
}

variable "runtime" {
  type    = string
  default = "python3.8"
}



# Define IAM roles and policies
resource "aws_iam_role" "lambda_role" {
  name = "lambda_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "iam_policy_for_lambda" {
  name        = "aws_iam_policy_for_terraform_aws_lambda_role"
  description = "AWS IAM Policy for managing AWS Lambda role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*",
        Effect   = "Allow"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_lambda_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}


# Define resources
resource "aws_dynamodb_table" "TaskTable" {
  name           = var.TABLE_NAME
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "task_id"
  attribute {
    name = "task_id"
    type = "S"
  }

  # Encriptado de datos para proteger la confidencialidad de los datos almacenados
  server_side_encryption {
    enabled = true
  }

  # Permite restaurar la tabla a un estado anterior en caso de pérdida de datos, etc.
  point_in_time_recovery {
    enabled = true
  }

  tags = {
    Name        = var.TABLE_NAME
    Environment = "Development"
  }

}

resource "aws_s3_bucket" "TaskStorage" {
  bucket = var.BUCKET_NAME

  tags = {
    Name        = var.BUCKET_NAME
    Environment = "Development"
  }

}


# Define Lamda ZIP files
data "archive_file" "zip_create_task_lamda" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda"
  output_path = "${path.module}/lambda_functions.zip"
}


# Define Lambda functions
resource "aws_lambda_function" "createScheduledTask" {
  filename         = "${path.module}/lambda_functions.zip"
  function_name    = "createScheduledTask"
  role             = aws_iam_role.lambda_role.arn
  handler          = "create_task.lambda_handler"
  runtime          = "${var.runtime}"
  environment {
    variables = {
      TABLE_NAME  = var.TABLE_NAME
    }
  }
  depends_on       = [aws_iam_role_policy_attachment.attach_iam_policy_to_lambda_role]
}

resource "aws_lambda_function" "listScheduledTask" {
  filename         = "${path.module}/lambda_functions.zip"
  function_name    = "listScheduledTask"
  role             = aws_iam_role.lambda_role.arn
  handler          = "list_task.lambda_handler"
  runtime          = "${var.runtime}"
  environment {
    variables = {
      TABLE_NAME  = var.TABLE_NAME
    }
  }
  depends_on       = [aws_iam_role_policy_attachment.attach_iam_policy_to_lambda_role]
}

resource "aws_lambda_function" "executeScheduledTask" {
  filename         = "${path.module}/lambda_functions.zip"
  function_name    = "executeScheduledTask"
  role             = aws_iam_role.lambda_role.arn
  handler          = "task_storage.lambda_handler"
  runtime          = "${var.runtime}"
  environment {
    variables = {
      TABLE_NAME  = var.TABLE_NAME
      BUCKET_NAME = var.BUCKET_NAME
    }
  }
  depends_on       = [aws_iam_role_policy_attachment.attach_iam_policy_to_lambda_role]
}

# Define AWS API Gateway
resource "aws_api_gateway_rest_api" "TaskAPI" {
  name        = "TaskAPI"
  description = "This is an API for the Task API"
}

# Define endpoints
resource "aws_api_gateway_resource" "CreateTask" {
  rest_api_id = aws_api_gateway_rest_api.TaskAPI.id
  parent_id   = aws_api_gateway_rest_api.TaskAPI.root_resource_id
  path_part   = "createtask"
}

resource "aws_api_gateway_resource" "ListTask" {
  rest_api_id = aws_api_gateway_rest_api.TaskAPI.id
  parent_id   = aws_api_gateway_rest_api.TaskAPI.root_resource_id
  path_part   = "listtask"
}


# Define API methods
resource "aws_api_gateway_method" "CreateTaskMethod" {
  rest_api_id = aws_api_gateway_rest_api.TaskAPI.id
  resource_id = aws_api_gateway_resource.CreateTask.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "ListTaskMethod" {
  rest_api_id = aws_api_gateway_rest_api.TaskAPI.id
  resource_id = aws_api_gateway_resource.ListTask.id
  http_method = "GET"
  authorization = "NONE"
}


# Define API integrations
resource "aws_api_gateway_integration" "CreateTaskIntegration" {
  rest_api_id = aws_api_gateway_rest_api.TaskAPI.id
  resource_id = aws_api_gateway_resource.CreateTask.id
  http_method = aws_api_gateway_method.CreateTaskMethod.http_method
  type = "AWS_PROXY"
  integration_http_method = "POST"
  uri = aws_lambda_function.createScheduledTask.invoke_arn
}

resource "aws_api_gateway_integration" "ListTaskIntegration" {
  rest_api_id = aws_api_gateway_rest_api.TaskAPI.id
  resource_id = aws_api_gateway_resource.ListTask.id
  http_method = aws_api_gateway_method.ListTaskMethod.http_method
  type = "AWS_PROXY"
  integration_http_method = "POST"
  uri = aws_lambda_function.listScheduledTask.invoke_arn
}

# Deploy API Gateway
resource "aws_api_gateway_deployment" "TaskAPIDeployment" {
  depends_on = [aws_api_gateway_integration.CreateTaskIntegration, aws_api_gateway_integration.ListTaskIntegration]
  rest_api_id = aws_api_gateway_rest_api.TaskAPI.id
  stage_name = "unused-stage"

  lifecycle {
    create_before_destroy = true
  }
}

# Deploy API Gateway Stage
resource "aws_api_gateway_stage" "TaskAPIStage" {
  stage_name = "dev"
  rest_api_id = aws_api_gateway_rest_api.TaskAPI.id
  deployment_id = aws_api_gateway_deployment.TaskAPIDeployment.id
}

# Define cloudwatch event brigde for executeScheduledTask
resource "aws_cloudwatch_event_rule" "TaskEventRule" {
  name        = "TaskEventRule"
  description = "Rule for executeScheduledTask"
  schedule_expression = "rate(1 minute)"
}
# define event target for executeScheduledTask
resource "aws_cloudwatch_event_target" "TaskEventTarget" {
  rule = aws_cloudwatch_event_rule.TaskEventRule.name
  arn  = aws_lambda_function.executeScheduledTask.arn
}
