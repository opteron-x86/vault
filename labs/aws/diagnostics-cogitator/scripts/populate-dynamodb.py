#!/usr/bin/env python3
"""
DynamoDB table population script for Cogitator Exploit Lab
Creates 300 records with themed data and embeds final flag
"""

import boto3
import random
import string
import time
import sys

def random_string(length=10):
    """Generate random alphanumeric string"""
    return ''.join(random.choices(string.ascii_letters + string.digits, k=length))

def random_password(length=16):
    """Generate complex password"""
    chars = string.ascii_letters + string.digits + "!@#$%^&*()_-+=<>?"
    return ''.join(random.choices(chars, k=length))

def generate_record(record_id):
    """Generate themed data record"""
    data_types = [
        {
            'Type': 'RITE',
            'Description': 'Rite of Activation for sacred machinery',
            'Value': f'{{{random_string(8)}}}'
        },
        {
            'Type': 'USER',
            'Description': 'Credentials for Mechanicus adept',
            'Value': f'{{adept{record_id}:{random_password()}}}'
        },
        {
            'Type': 'LOG',
            'Description': 'Encrypted cogitator log',
            'Value': f'{{{random_string(30)}}}'
        },
        {
            'Type': 'KEY',
            'Description': 'Magenta level cipher key - AUTHORIZED USE ONLY',
            'Value': f'{{{random_string(12)}}}'
        },
        {
            'Type': 'CHANT',
            'Description': 'Chant to appease the machine spirits',
            'Value': f'{{{random_string(20)}}}'
        },
        {
            'Type': 'SERVOCMD',
            'Description': 'Encoded command for servo-skull',
            'Value': f'{{{random_string(15)}}}'
        }
    ]
    
    return random.choice(data_types)

def populate_table(table_name, region='us-east-1'):
    """Populate DynamoDB table with records"""
    dynamodb = boto3.resource('dynamodb', region_name=region)
    table = dynamodb.Table(table_name)
    
    total_records = 300
    flag_position = random.randint(50, 250)
    
    print(f"Populating table '{table_name}' with {total_records} records...")
    print(f"Flag will be placed at RecordID {flag_position}")
    
    for i in range(1, total_records + 1):
        item_data = generate_record(i)
        item = {
            'RecordID': str(i),
            'Type': item_data['Type'],
            'Description': item_data['Description'],
            'Value': item_data['Value']
        }
        
        # Insert final flag at random position
        if i == flag_position:
            item['Type'] = 'HTB'
            item['Description'] = 'Vermillion level cipher key - RESTRICTED'
            item['Value'] = 'FLAG{iam_privilege_escalation_dynamodb_exfiltration_complete}'
        
        table.put_item(Item=item)
        
        if i % 50 == 0:
            print(f"Progress: {i}/{total_records} records inserted")
        
        time.sleep(0.02)
    
    print(f"✓ Population complete. Flag at RecordID {flag_position}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 populate-dynamodb.py <table-name> [region]")
        print("Example: python3 populate-dynamodb.py cogitator-DataRelicRepository-abc123 us-east-1")
        sys.exit(1)
    
    table_name = sys.argv[1]
    region = sys.argv[2] if len(sys.argv) > 2 else 'us-east-1'
    
    try:
        populate_table(table_name, region)
    except Exception as e:
        print(f"✗ Error: {e}")
        sys.exit(1)