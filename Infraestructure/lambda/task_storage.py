import json
import boto3
import uuid

BUCKET_NAME = "taskstorage"

s3_client = boto3.client('s3')

def lambda_handler(event, context):
    object_key = str(uuid.uuid4())

    object_content = "Hello, this is a new object created by executeScheduledTask lambda."

    try:
        response = s3_client.put_object(
            Bucket=BUCKET_NAME,
            Key=object_key,
            Body=object_content
        )
        print("Object uploaded successfully:", response)

        response = {
            "statusCode": 200,
            "body": json.dumps({"message": "Object created successfully in S3."})
        }

    except Exception as e:
        print("Error uploading object to S3:", str(e))
        response = {
            "statusCode": 500,
            "body": json.dumps({"error": "Failed to create object in S3."})
        }

    return response
