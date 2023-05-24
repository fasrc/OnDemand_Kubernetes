#!/bin/bash
for arg in "$@"
do
  case $arg in
    --user)
    ONDEMAND_USERNAME=$2
    shift
    shift
    ;;
esac
done

if [ "x${ONDEMAND_USERNAME}" = "x" ]; then
  echo "Must specify username"
  exit 1
fi

# List of the courses that are allowed to use AWS EKs
COURSELIST="g111383 g222333 g111835"

# Get the user's group 
USERGROUP=g$(echo $ONDEMAND_USERNAME | cut  -dg -f2)

# Check if the user's group in the list of courses that allowed to use AWS EKS
VALID=$(echo $COURSELIST | grep $USERGROUP)

# If the user's group is not in the list then exit the prehook
if [ -z "$VALID" ]
then
  echo "Not a Valid Group ........"
  exit 255
fi

HOOKSDIR="/opt/ood/hooks"
HOOKENV="/etc/ood/config/hook.env"

/bin/bash "$HOOKSDIR/k8s-bootstrap/k8s-bootstrap-ondemand.sh" "$ONDEMAND_USERNAME" "$HOOKENV"

# This file is sourced to populate the tokens that will be used by the set-k8s-creds.sh script below
source "$HOOKSDIR/k8s-bootstrap/setupCognitoUser.sh" "$ONDEMAND_USERNAME" "FAS0ndemandPassWord" "cognito-user-group" "$HOOKENV"

# This is only used when we use OIDC as auth provider
/bin/bash "$HOOKSDIR/k8s-bootstrap/set-k8s-creds.sh" "$ONDEMAND_USERNAME" "$HOOKENV"

# Add cluster context <-- Faras
source "$HOOK_ENV"
sudo -u "$ONDEMAND_USERNAME" kubectl config set-context ${EKSArn} --cluster ${EKSArn} --user ${ONDEMAND_USERNAME}
sudo -u "$ONDEMAND_USERNAME" kubectl config use-context ${EKSArn}
