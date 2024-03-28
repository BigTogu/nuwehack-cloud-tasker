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
data "archive_file" "lambda_functions" {
  type        = "zip"
  source_dir  = "${path.module}/Infraestructure/lambda"
  output_path = "${path.module}/Infraestructure/lambda_function_payload.zip"
}

# Define Lambda functions
resource "aws_lambda_function" "CreateTask" {
  function_name    = "CreateTask"
  handler          = "create_task.lambda_handler"
  runtime          = "python3.8"
  filename         = data.archive_file.lambda_functions.output_path
  source_code_hash = data.archive_file.lambda_functions.output_base64sha256
  role             = "arn:aws:iam::123456789012:role/lambda-role"


  tags = {
    Name        = "CreateTask"
    Environment = "Development"
  }
}

resource "aws_lambda_function" "ListTask" {
  function_name    = "ListTask"
  handler          = "list_task.lambda_handler"
  runtime          = "python3.8"
  filename         = data.archive_file.lambda_functions.output_path
  source_code_hash = data.archive_file.lambda_functions.output_base64sha256
  role             = "arn:aws:iam::123456789012:role/lambda-role"


  tags = {
    Name        = "ListTask"
    Environment = "Development"
  }
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


