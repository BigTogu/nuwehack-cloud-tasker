import json
import boto3
import os

dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    table = dynamodb.Table(os.environ.get("TABLE_NAME"))

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
