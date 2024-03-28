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

# Add here all the infraestructure logic



# Define IAM roles and policies
resource "aws_iam_role" "iam_policy_for_lambda" {
  name         = "aws_iam_policy_for_terraform_aws_lambda_role"
  path         = "/"
  description  = "AWS IAM Policy for managing aws lambda role"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
    "Resource": "arn:aws:logs:*:*:*",
    "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role        = aws_iam_role.lambda_role.name
  policy_arn  = aws_iam_policy.iam_policy_for_lambda.arn
}

# Define resources
resource "aws_dynamodb_table" "TaskTable" {
  name           = "TaskTable"
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
    Name        = "TaskTable"
    Environment = "Development"
  }

}

resource "aws_s3_bucket" "TaskStorage" {
  bucket = "taskstorage"

  tags = {
    Name        = "TaskStorage"
    Environment = "Development"
  }

}


# Define Lamda ZIP files
data "archive_file" "zip_create_task_lamda" {
  type        = "zip"
  source_dir  = "${path.module}/Infraestructure/lambda/create_task.py"
  output_path = "${path.module}/Infraestructure/create_task.zip"
}

data "archive_file" "zip_list_task_lamda" {
  type        = "zip"
  source_dir  = "${path.module}/Infraestructure/lambda/list_task.py"
  output_path = "${path.module}/Infraestructure/list_task.zip"
}

# Define Lambda functions
resource "aws_lambda_function" "createScheduledTask" {
  filename         = "${path.module}/Infraestructure/create_task.zip"
  function_name    = "createScheduledTask"
  role             = aws_iam_role.lambda_role.arn
  handler          = "create_task.lambda_handler"
  runtime          = "python3.8"
  depends_on       = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
}

resource "aws_lambda_function" "listScheduledTask" {
  filename         = "${path.module}/Infraestructure/list_task.zip"
  function_name    = "listScheduledTask"
  role             = aws_iam_role.lambda_role.arn
  handler          = "list_task.lambda_handler"
  runtime          = "python3.8"
  depends_on       = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
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
  integration_http_method = "GET"
  uri = aws_lambda_function.listScheduledTask.invoke_arn
}