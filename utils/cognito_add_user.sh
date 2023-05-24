#!/bin/bash

# Usage:
#  setupCgnitoUser.sh ondemand ondemandPassword cs109b

USER_NAME=$1
PASS_WORD=$2
GROUP_NAME=$3

EKSArn=arn:aws:eks:us-east-1:xxxxxxxxxxxx:cluster/mycluster
UserPoolId=us-east-1_xxxxxxxxx
UserPoolClientId=xxxxxxxxxxxxxxxxxxxxxxxxxx
UserPoolIssuer=https://cognito-idp.us-east-1.amazonaws.com/us-east-1_abcdefghI

CLIENT_ID=${UserPoolClientId} && ISSUER_URL=${UserPoolIssuer} && POOL_ID=${UserPoolId}

refresh_token=""
id_token=""

function create_group() {
	GROUP=$(aws cognito-idp get-group --group-name ${GROUP_NAME} --user-pool-id $POOL_ID 2>/dev/null)
	if [ -z "${GROUP}" ]; then
		aws cognito-idp create-group --group-name ${GROUP_NAME} --user-pool-id $POOL_ID
	fi
}

function create_user() {
	USER=$(aws cognito-idp admin-get-user --user-pool-id ${POOL_ID}  --username ${USER_NAME} 2>/dev/null)
	if [ -z "${USER}" ]; then
		aws cognito-idp admin-create-user --user-pool-id $POOL_ID --username ${USER_NAME} --temporary-password tmpPassword
		aws cognito-idp admin-set-user-password --user-pool-id $POOL_ID --username ${USER_NAME} --password ${PASS_WORD} --permanent
	fi
	aws cognito-idp admin-add-user-to-group --user-pool-id $POOL_ID --username ${USER_NAME} --group-name ${GROUP_NAME}
}
 
function get_user_auth_token() {
	tokens=$(aws cognito-idp admin-initiate-auth --auth-flow ADMIN_USER_PASSWORD_AUTH \
	--client-id $CLIENT_ID \
	--auth-parameters USERNAME=${USER_NAME},PASSWORD=${PASS_WORD} \
	--user-pool-id $POOL_ID \
	--query 'AuthenticationResult.[RefreshToken, IdToken]' --output text)

	refresh_token=$(echo $tokens | awk '{print $1}')
	id_token=$(echo $tokens | awk '{print $2}')
}

function test_single_token() {
	kubectl --token=$id_token get po
}

function configure_kubectl() {
	kubectl config set-credentials ${USER_NAME} \
	--auth-provider=oidc \
	--auth-provider-arg=idp-issuer-url=$ISSUER_URL \
	--auth-provider-arg=client-id=$CLIENT_ID \
	--auth-provider-arg=refresh-token=${refresh_token} \
	--auth-provider-arg=id-token=${id_token}
	
	kubectl config set-context ${EKSArn} --cluster ${EKSArn} --user ${USER_NAME}
	kubectl config use-context ${EKSArn}
	kubectl  get po
}

#create_group
#create_user
get_user_auth_token
test_single_token
configure_kubectl

