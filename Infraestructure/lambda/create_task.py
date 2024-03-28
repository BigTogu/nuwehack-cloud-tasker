import json
import boto3
import uuid

TABLE_NAME = "TaskTable"

dynamodb = boto3.resource('dynamodb')

def lambda_handler(event, context):
    body = json.loads(event["body"])

    task_name = body.get("task_name")
    cron_expression = body.get("cron_expression")

    task_id = str(uuid.uuid4())

    table = dynamodb.Table(TABLE_NAME)

    table.put_item(
        Item={
            'task_id': task_id,
            'task_name': task_name,
            'cron_expression': cron_expression
        }
    )

    response = {
        "statusCode": 200,
        "body": json.dumps({"task_id": task_id})
    }

    return response
