#!/bin/bash

# Script to 
#	1. Creates cognito group if not exist
#	2. Create cognito user  if not exist.
#	3. Add the user to the group
#	4. Create and export the user tokens (id token and refresh token)
#
# Usage:
#  setupCognitoUser.sh USERNAME USERPASSWORD GROUP HOOKENV
#
#  Example
#  	setupCognitoUser.sh ondemand ondemandPassword cs109b /etc/ood/config/hook.env
#
# Note the script need to be exported to populate the user tokens


# Path to the logs of this script
LOG_PATH=/var/log/setupCognitoUser.log
echo "..........." >> $LOG_PATH
date >> $LOG_PATH
echo >> $LOG_PATH

if (($# < 4))
then
	echo "Number of arguments should be 4" >> $LOG_PATH
	exit 1
fi

USER_NAME=$1
PASS_WORD=$2
GROUP_NAME=$3
HOOK_ENV=$4

# Source hooks to get the ID credentials and urls
source $HOOK_ENV

# Create user's group if not exist
GROUPEXIST=$(aws cognito-idp get-group --group-name ${GROUP_NAME} --user-pool-id $POOL_ID 2>/dev/null)
if [ -z "${GROUPEXIST}" ]; then
  aws cognito-idp create-group --group-name ${GROUP_NAME} --user-pool-id $POOL_ID
  echo "Group: ${GROUP_NAME} created" >> $LOG_PATH
else
  echo "Group: ${GROUP_NAME} exists" >> $LOG_PATH 
fi      

# Create the user if not exist, and add the user to the group
USEREXIST=$(aws cognito-idp admin-get-user --user-pool-id ${POOL_ID}  --username ${USER_NAME} 2>/dev/null)
if [ -z "${USEREXIST}" ]; then
  userTmpPass=$(aws cognito-idp admin-create-user --user-pool-id $POOL_ID --username ${USER_NAME} --temporary-password tmpPassword 2>/dev/null )
  if [ ! -z "${userTmpPass}" ]; then
    userPrmPass=$(aws cognito-idp admin-set-user-password --user-pool-id $POOL_ID --username ${USER_NAME} --password ${PASS_WORD} --permanent 2>/dev/null)
    if [ ! -z "${userPrmPass}" ]; then
      echo "Could not create permanent password for user ${USER_NAME}" >> $LOG_PATH
      exit 1
    fi
  else
    echo "Could not create user ${USER_NAME}" >> $LOG_PATH
    exit 1
  fi
  echo "User ${USER_NAME} created" >> $LOG_PATH
else
  echo "User ${USER_NAME} exists" >> $LOG_PATH
fi      

echo "Add user:${USER_NAME} to group:${GROUP_NAME}" >> $LOG_PATH
addToGrp=$(aws cognito-idp admin-add-user-to-group --user-pool-id $POOL_ID --username ${USER_NAME} --group-name ${GROUP_NAME} 2>/dev/null)
if [ ! -z "${addToGrp}" ]; then
  echo "Could not add  user:${USER_NAME} to group:${GROUP_NAME}" >> $LOG_PATH
  exit 1
fi

# Generate user tokens, id token and refresh token
TOKENS=$(aws cognito-idp admin-initiate-auth --auth-flow ADMIN_USER_PASSWORD_AUTH --client-id $CLIENT_ID --auth-parameters USERNAME=${USER_NAME},PASSWORD=${PASS_WORD} --user-pool-id $POOL_ID --query 'AuthenticationResult.[RefreshToken,IdToken]' --output text 2>/dev/null)

if [ ! -z "${TOKENS}" ]; then
  echo "Create Tokens (id and refresh tokens) for user:${USER_NAME}" >> $LOG_PATH
else
   echo "Could not create user:${USER_NAME} Tokens " >> $LOG_PATH
fi

# export the tokens
export OOD_OIDC_REFRESH_TOKEN=$(echo $TOKENS | awk '{print $1}')
export OOD_OIDC_ACCESS_TOKEN=$(echo $TOKENS | awk '{print $2}')
echo "Export user:${USER_NAME} OOD_OIDC_REFRESH_TOKEN and OOD_OIDC_ACCESS_TOKEN" >> $LOG_PATH

# Users should not be able to read the log file
chmod 640 $LOG_PATH

