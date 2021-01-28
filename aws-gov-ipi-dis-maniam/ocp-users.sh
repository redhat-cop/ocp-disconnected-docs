#!/bin/bash -x

# 
# This script is intended to assist users with manually managing AWS IAM accounts
# when installing OCP 4.6.X with the "credentialMode: Manual" installation option.
# 
# Dependencies:
#   jq,
#   aws cli
#   
# 
# Available commands:
#
#   writePolicies: Copy users and policies from AWS to local files in the same directory (uses aws current context)
#
#   prepPolicies: Prepares policy files for redeployment (uses aws current contxt)
#
#   createUsers: Creates users and attaches new policies to them (uses aws current context)
#
#   cleanupFiles: Deletes policy files from current directory
#
#   help: Prints this message
#
#


# Lists all usernames
function __listUserNames() {

  aws iam list-users | jq -r '.Users | map(.UserName)' | sed -e 's/.$//' -e 's/"//g'

}

# List tags of a user
function __listUserTags() {

  aws iam list-user-tags --user-name $1

}

# List policies attached to a user
function __listPolices() {

  aws iam list-user-policies --user-name $1 | jq -r '.PolicyNames | .[]' | sed -e 's/"//g'

}

# Dump a poliicies' details
function __getPolicy() {

  aws iam get-user-policy --user-name $1 --policy-name $2

}

# Creates IAM user and returns arn

function __createUser() {

  aws iam create-user --user-name $1 | jq -r '.User.Arn'

}

# Create IAM Policy

function __createPolicy() {

  aws iam create-policy --policy-name $1 --policy-document file://./$2 | jq -r '.Policy.Arn'

}

function __attachPolicy() {

  aws iam attach-user-policy --user-name $1 --policy-arn "$2"

}

# Get users created by openshift
function __getClusterUsers() {

  for u in $(__listUserNames)
  do 
    UT=$(__listUserTags $u | grep -o kubernetes\.io\/cluster)
    if [ $UT ]
    then 
      echo $u
    fi
  done

}

function writeUsers() {
  
  for c in $(__getClusterUsers)
  do
    UN=$(echo $c | sed -re 's/^(\w*\-){3}//' -e 's/(\-\w*$)//')
    echo $UN >> account_names.txt
  done

}

function writePolicies() {

  for un in $(__getClusterUsers)
  do 
    for lp in $(__listPolices $un)
    do
      __getPolicy $un $lp > $(echo $un | sed -re 's/^(\w*\-){3}//' -e 's/(\-\w*$)//').json
    done
  done 

}

function prepPolicies() {

  for u in $(cat account_names.txt)
  do
    f=$(grep -ls $u --exclude="account_names.txt" *) # get filename to edit
    on=$(jq -r '.UserName' $f) # get original account name
    sed -i "s/$on/$u/g" $f # edit account name
    na=$(aws sts get-caller-identity | jq -r '.Arn' | grep -oP '.*?/')$u
    oa=$(grep -Po 'arn.*(?<!")' $f)
    sed -i "s~$oa~$na~" $f
    jq '.PolicyDocument' $f > $u-policy.json
    rm -f $f
  done

}

function createUsers() {

  for u in $(cat account_names.txt)
  do
    f=$(grep -ls $u --exclude="account_names.txt" *)
    ua=$(__createUser $u)
    pa=$(__createPolicy $u-policy $f)
    __attachPolicy $u $pa
  done
}

function cleanupFiles() {

  for u in $(cat account_names.txt)
  do
    rm -f $(grep -ls $u --exclude="account_names.txt" *)
  done
  rm -f account_names.txt
}

function help() {

  echo "
    ./ocp-users.sh:

      This script is intended to assist users with manually managing AWS IAM accounts
      when installing OCP 4.6.X with the \"credentialMode: Manual\" installation option.


    Dependencies:

      jq,
      aws cli
   
 
    Available subcommands:

      writePolicies: Copy users and policies from AWS to local files in the same directory (uses aws current context)

      prepPolicies: Prepares policy files for redeployment (uses aws current contxt)

      createUsers: Creates users and attaches new policies to them (uses aws current context)

      cleanupFiles: Deletes policy files from current directory

      help: Prints this message"
}

FUNCTIONS=$(typeset -f | awk '/ \(\) $/ && !/^main / {print $1}')

if [ $# -eq 0 ]
then
  echo "No arguments provided"
  echo "Use "./ocp-users.sh help" for more info"
  exit 1
else 
  if [[ ! $FUNCTIONS[$1] ]]
  then
    echo "$1 is not a supported option."
    echo "Use "./ocp-users.sh help" for more info"
    exit 1
  fi
fi

"$@"