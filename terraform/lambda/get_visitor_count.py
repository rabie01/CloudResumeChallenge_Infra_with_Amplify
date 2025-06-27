import boto3
import json
import os

ddb = boto3.resource('dynamodb')
table = ddb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    table.update_item(
        Key={'id': 'global'},
        UpdateExpression='ADD cnt :incr',
        ExpressionAttributeValues={':incr': 1}
    )
    response = table.get_item(Key={'id': 'global'})
    return {
        'statusCode': 200,
        'headers': {'Content-Type': 'application/json'},
        'body': json.dumps({'cnt': response['Item']['cnt']})
    }
