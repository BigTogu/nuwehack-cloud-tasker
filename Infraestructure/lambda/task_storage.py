import json
import boto3
import uuid
import os


s3_client = boto3.client('s3')

def lambda_handler(event, context):
    object_key = str(uuid.uuid4())

    object_content = "Hello, this is a new object created by executeScheduledTask lambda."

    try:
        response = s3_client.put_object(
            Bucket=os.environ.get("BUCKET_NAME"),
            Key=object_key,
            Body=object_content
        )
        response = {
            "statusCode": 200,
            "body": json.dumps({"message": "Object created successfully in S3."})
        }

    except Exception as e:
        response = {
            "statusCode": 500,
            "body": json.dumps({"error": "Failed to create object in S3."})
        }

    return response
