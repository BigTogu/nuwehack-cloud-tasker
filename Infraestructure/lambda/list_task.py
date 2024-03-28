import json
import boto3

TABLE_NAME = "TaskTable"

dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    table = dynamodb.Table(TABLE_NAME)

    response = table.scan()

    items = response.get("Items", [])

    response_body = {
        "tasks": items
    }

    response = {
        "statusCode": 200,
        "body": json.dumps(response_body)
    }

    return response
