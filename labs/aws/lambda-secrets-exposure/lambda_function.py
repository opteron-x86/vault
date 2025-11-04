import json
import os
import boto3
from botocore.exceptions import ClientError

def lambda_handler(event, context):
    
    path = event.get('rawPath', '/')
    
    if path == '/health':
        return {
            'statusCode': 200,
            'body': json.dumps({
                'status': 'healthy',
                'service': 'lambda-api-handler'
            })
        }
    
    elif path == '/status':
        # Debug mode exposes internal configuration
        if os.environ.get('DEBUG_MODE') == 'true':
            response = {
                'status': 'operational',
                'environment': {
                    'runtime': 'python3.13',
                    'region': os.environ.get('AWS_REGION'),
                    'function': os.environ.get('AWS_LAMBDA_FUNCTION_NAME')
                },
                'configuration': {
                    'secret_arn': os.environ.get('SECRET_ARN'),
                    'db_host': os.environ.get('DB_HOST'),
                    'db_name': os.environ.get('DB_NAME'),
                    'api_key': os.environ.get('API_KEY'),
                    'internal_api': os.environ.get('INTERNAL_API_URL')
                },
                'message': 'Debug mode enabled - configuration exposed for troubleshooting'
            }
            
            return {
                'statusCode': 200,
                'body': json.dumps(response, indent=2)
            }
        else:
            return {
                'statusCode': 200,
                'body': json.dumps({'status': 'operational'})
            }
    
    elif path == '/db-test':

        try:
            secret_arn = os.environ.get('SECRET_ARN')
            
            if not secret_arn:
                return {
                    'statusCode': 500,
                    'body': json.dumps({
                        'error': 'SECRET_ARN not configured'
                    })
                }
            
            secrets_client = boto3.client('secretsmanager')
            
            try:
                secret_response = secrets_client.get_secret_value(SecretId=secret_arn)
                db_creds = json.loads(secret_response['SecretString'])
                
                return {
                    'statusCode': 200,
                    'body': json.dumps({
                        'message': 'Database credentials retrieved successfully',
                        'db_host': db_creds.get('host'),
                        'db_name': db_creds.get('dbname'),
                        'db_user': db_creds.get('username'),
                        'db_password': db_creds.get('password'),
                    })
                }
                
            except ClientError as e:
                return {
                    'statusCode': 500,
                    'body': json.dumps({
                        'error': 'Failed to retrieve secret',
                        'details': str(e),
                        'secret_arn': secret_arn
                    })
                }
                
        except Exception as e:
            return {
                'statusCode': 500,
                'body': json.dumps({
                    'error': 'Unexpected error',
                    'details': str(e),
                    'environment_vars': list(os.environ.keys())
                })
            }
    
    else:
        return {
            'statusCode': 404,
            'body': json.dumps({
                'error': 'Not found',
                'available_endpoints': ['/health', '/status', '/db-test']
            })
        }