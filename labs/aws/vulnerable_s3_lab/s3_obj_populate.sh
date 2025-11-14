#! /bin/bash

mkdir files
cd files

for i in {1..10}; do
  base64 /dev/urandom | head -c $(( RANDOM % 500 + 50 )) > "s3_bucket_data_${i}.txt"
done

aws s3 cp --recursive . s3://$1