#!/bin/bash

# if secrets folder already exists, remove it
[[ -d secrets ]] && rm -rf secrets || true
mkdir -p secrets
for u in $(cat account_names.txt)
do
  obj=$(aws iam create-access-key --user-name $u)
  export keyid=$(jq -r '.AccessKey.AccessKeyId' <<< $obj)
  export key=$(jq -r '.AccessKey.SecretAccessKey' <<< $obj)
  envsubst < $(find ./ -name $u*-templ.yaml) > secrets/$u-secret.yaml
done
