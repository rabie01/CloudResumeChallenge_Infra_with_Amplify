import boto3
import json
import os
from decimal import Decimal

ddb = boto3.resource('dynamodb')
table = ddb.Table(os.environ['TABLE_NAME'])

def lambda_handler(event, context):
    response = table.update_item(
        Key={'id': 'global'},
        UpdateExpression='ADD cnt :incr',
        ExpressionAttributeValues={':incr': Decimal(1)},
        ReturnValues="UPDATED_NEW"
    )
    updated_count = response['Attributes']['cnt']
    
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Content-Type': 'application/json'
        },
        'body': json.dumps({'count': int(updated_count)})
    }
