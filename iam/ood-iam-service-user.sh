#!/bin/bash

# ood-iam-service-user.sh {IAM-USER-NAME}

if (($# < 1))
then
	echo "User name is required"
	exit 255
fi

#USER_NAME=ood-iam-service-user
USER_NAME=$1
POLICY_NAME=${USER_NAME}-policy
POLICY_FILE=${POLICY_NAME}.json

cat > $POLICY_FILE << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:*",
                "cognito-identity:*",
                "cognito-idp:*",
                "cognito-sync:*"
            ],
            "Resource": "*"
        }
    ]
}
EOF

aws iam create-user --user-name ${USER_NAME}

aws iam put-user-policy --user-name ${USER_NAME} --policy-name ${POLICY_NAME} --policy-document file://${POLICY_FILE}

rm -fr ${POLICY_FILE}
