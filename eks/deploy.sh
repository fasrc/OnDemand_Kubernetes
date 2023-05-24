#! /bin/bash

# Deploy EKS cluster
# Usage:
#   If .env file is availabe
#     ./deploy.sh CLUSTER_NAME
#   Otherwise
#     ./deploy.sh CLUSTER_NAME [ REGION VPCTAG SUB1TAG SUB2TAG SSH_KEY IAM_USER OOD_CIDR COGNITO-STACK-NAME gpu|general ]
# Example
#   If .env file is availabe
#     ./deploy.sh my-ood-eks
#   Otherwise
#     ./deploy.sh my-ood-eks us-east-1 atood-dev-standard atood-dev-standard-app-pvt-1a atood-dev-standard-app-pvt-1b eks ood-dev-eks-cognito 10.31.0.0/16 ood-cognito general
# 

CLUSTER_NAME=$1
if [ -z "$CLUSTER_NAME" ]
then
  echo " Custer Name should be provided"
  exit 255
fi

ENV_FILE=.env
if [ -f "$ENV_FILE" ]; then
  echo "Evironmental File \'$ENV_FILE\' will be used"
  source "$ENV_FILE"
  export $(grep -Ev "^#" "$ENV_FILE" | cut -d= -f1)
else
  echo "No evironmental File \'$ENV_FILE\' found."
  echo "Will calculate the variables using AWS CLI command based on the input parameters; that might take few seconds"
  # Number of arguments should be 10
  if (($# < 10))
  then
    echo "Number of arguments should be 10"
    exit 255
  fi
  REGION=$2
  VPCTAG=$3
  SUB1TAG=$4
  SUB2TAG=$5
  SSH_KEY=$6
  IAM_USER=$7
  OOD_CIDR=$8
  COGNITO_STACK_NAME=$9
  NODE_TYPE=${10}
  
  echo "Wait to populate the ACCOUNT, VPC_ID, SUB_ID_1, SUB_ID_2, UserPoolId, UserPoolClientId, and UserPoolIssuer"
  ACCOUNT=$(aws sts get-caller-identity --region=${REGION} --query "Account" --output text)
  VPC_ID=$(aws ec2 describe-vpcs --region=${REGION} --filters Name=tag:Name,Values=${VPCTAG} --query "Vpcs[*].VpcId" --output text)
  SUB_ID_1=$(aws ec2 describe-subnets --region=${REGION} --filters Name=tag:Name,Values=${SUB1TAG} Name=vpc-id,Values=${VPC_ID} --query "Subnets[*].SubnetId" --output text)
  SUB_ID_2=$(aws ec2 describe-subnets --region=${REGION} --filters Name=tag:Name,Values=${SUB2TAG} Name=vpc-id,Values=${VPC_ID} --query "Subnets[*].SubnetId" --output text)
  UserPoolId=$(aws cloudformation describe-stacks --region=${REGION} --stack-name ${COGNITO_STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='UserPoolId']" --output text | awk '{print $3}')
  UserPoolClientId=$(aws cloudformation describe-stacks --region=${REGION} --stack-name ${COGNITO_STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='UserPoolClientId']" --output text | awk '{print $3}')
  UserPoolIssuer=$(aws cloudformation describe-stacks --region=${REGION} --stack-name ${COGNITO_STACK_NAME} --query "Stacks[0].Outputs[?OutputKey=='UserPoolIssuer']" --output text | awk '{print $3}')
fi

# Security Group ID is empty and will be generated later
SGID=""

# Check all variables are not empty
echo Check all variables are not empty
# For now lets check on the VPC ID only
echo "Check that all variables are populated, otherwise exit"
if [ -z $VPC_ID ]; then
  echo "VPC ID is empty"
  exit 1
fi
echo ".............."
echo


# Create a folder to for the eks resources templates that will deployed.
echo Create a folder to for the eks resources templates that will deployed.
createdat=$(date +"%h%dth%Yat%H%M%S")
mkdir -p "clusters_deployed/${CLUSTER_NAME}_${createdat}"
DEPLOYPATH="clusters_deployed/${CLUSTER_NAME}_${createdat}"
echo "Templates to deploy the cluster can be found in this path: $DEPLOYPATH"
echo ".............."
echo

# Create the Security Group that will be attached to each node of the EKS
function ood_cidr_sg() {
  OOD_SG_NAME="${CLUSTER_NAME}-Nodes-Security-Group"
  sed "s#OODSGNAME#${OOD_SG_NAME}#;s#VPCID#${VPC_ID}#;s#OODCIDR#${OOD_CIDR}#" templates/ood-security_groups.yaml > ${DEPLOYPATH}/ood-security_groups.yaml
  echo " Create the Security group {$OOD_SG_NAME} with stack name ${OOD_SG_NAME}"
  STACKARN=$(aws cloudformation create-stack --region=${REGION} --stack-name ${OOD_SG_NAME} --template-body file://${DEPLOYPATH}/ood-security_groups.yaml --output text)
  echo " Wait for the security group stack $OOD_SG_NAME to complete; that might take sometime .."
  aws cloudformation wait stack-create-complete --region=${REGION} --stack-name ${STACKARN} --color on
  echo "get the security group Id from the the group name ${OOD_SG_NAME}"
  SGID=$(aws ec2 describe-security-groups --region=${REGION} --filter Name=group-name,Values=${OOD_SG_NAME} --query 'SecurityGroups[*].[GroupId]' --output text)
}

# Prepare the templates
function prepare_templates() {
  # Prepare the EKS yaml template that will be used by eksctl to deploy the cluster.
  sed "s#CLUSTERNAME#${CLUSTER_NAME}#; s#REGION#${REGION}#; s#VPCID#${VPC_ID}#; s#SUBNETID1#${SUB_ID_1}#; s#SUBNETID2#${SUB_ID_2}#" templates/eks.yaml > ${DEPLOYPATH}/eks.yaml

  # Prepare the Identity Provider yaml template that will be associated with the EKS cluster for user authentication.
  sed "s#CLUSTERNAME#${CLUSTER_NAME}#; s#REGION#${REGION}#; s#USERPOOLCLIENTID#${UserPoolClientId}#; s#ISSUERURL#${UserPoolIssuer}#; s#PROVIDERNAME#${COGNITO_STACK_NAME}#" templates/identity-provider.yaml > ${DEPLOYPATH}/identity-provider.yaml

  # Prepare the autoscaler autodiscover and nodegroups templates using the region and cluster name arguments.
  sed "s#<YOUR CLUSTER NAME>#${CLUSTER_NAME}#" templates/cluster-autoscaler-autodiscover.yaml > ${DEPLOYPATH}/cluster-autoscaler-autodiscover.yaml
  sed "s#CLUSTERNAME#${CLUSTER_NAME}#; s#REGION#${REGION}#" templates/autoscaler_nodegroups.yaml > ${DEPLOYPATH}/autoscaler_nodegroups.yaml

  # Prepare the workergroups template using the cluster name, region, key and node type arguments.
  sed "s#CLUSTERNAME#${CLUSTER_NAME}#; s#REGION#${REGION}#; s#SGID#${SGID}#; s#PUBLICKEYNAME#${SSH_KEY}#" templates/${NODE_TYPE}_nodegroups.yaml > ${DEPLOYPATH}/${NODE_TYPE}_nodegroups.yaml

}

# Setup job-pod-reaper into the cluster
function setup_job_pod_reaper() {
  kubectl apply -f https://github.com/OSC/job-pod-reaper/releases/latest/download/namespace-rbac.yaml
  kubectl apply -f https://github.com/OSC/job-pod-reaper/releases/latest/download/ondemand-deployment.yaml
}

# Setup Calico and calicoctl tools required for namespace level network policy enforcement
function setup_calico() {
  # Install Helm
  curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
  # Install Calico Operator
  helm repo add projectcalico https://docs.projectcalico.org/charts
  helm repo update
  helm install calico projectcalico/tigera-operator --version v3.21.4
}

# Configure the autoscaler autodescover.
function autoscaler_config() {
  eksctl utils associate-iam-oidc-provider --region=${REGION} --cluster=${CLUSTER_NAME} --approve
  POLICY_ARN=$(aws iam create-policy --region=${REGION} --policy-name ${CLUSTER_NAME}-AmazonEKSClusterAutoscalerPolicy --policy-document file://templates/autoscaler_iam_policy.json  --output text | awk '{print $2}')
  SERVICE_ACCT=$(eksctl create iamserviceaccount --region=${REGION} --cluster=${CLUSTER_NAME} --namespace=kube-system --name=cluster-autoscaler --attach-policy-arn=${POLICY_ARN} --override-existing-serviceaccounts --approve)
  # Get autoscaler file
  # curl -o templates/cluster-autoscaler-autodiscover.yaml https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
  # Edit templates/cluster-autoscaler-autodiscover.yaml and replace image and clustername
  kubectl apply -f  ${DEPLOYPATH}/cluster-autoscaler-autodiscover.yaml
  kubectl patch deployment cluster-autoscaler -n kube-system -p '{"spec":{"template":{"metadata":{"annotations":{"cluster-autoscaler.kubernetes.io/safe-to-evict": "false"}}}}}'
  echo "IF NEEDED you need to do some Manual work:"
  echo "1. get Role ARN (ROLE_ARN) created by the \$SERVICE_ACCT command above"
  echo "2. kubectl annotate serviceaccount cluster-autoscaler -n kube-system eks.amazonaws.com/role-arn=\${ROLE_ARN}"
}

function cluster_config() {
  EKS_ARN=$(aws eks describe-cluster --region=${REGION} --name ${CLUSTER_NAME} --query "cluster.arn" --output text)
  EKS_ENDPOINT=$(aws eks describe-cluster --region=${REGION} --name ${CLUSTER_NAME} --query "cluster.endpoint" --output text)
  EKS_HOST=$(echo ${EKS_ENDPOINT} | sed 's/https:\/\///')
  IDENTITY_ISSUER=$(aws eks describe-cluster --region=${REGION} --name ${CLUSTER_NAME} --query "cluster.identity.oidc.issuer" --output text)
  mkdir -p ${DEPLOYPATH}/cluster_config
  aws eks describe-cluster --region=${REGION} --name ${CLUSTER_NAME} --output text | grep CERTIFICATEAUTHORITY | awk '{print $2}' | base64 --decode   > ${DEPLOYPATH}/cluster_config/kubernetes-ca.crt
  sed "s#CLUSTER_NAME#${CLUSTER_NAME}#;s#EKS_HOST#${EKS_HOST}#;s#EKS_ENDPOINT#https://${EKS_HOST}#;s#KUBE_CLUSTER#${EKS_ARN}#;s#KUBE_CONTEXT#${EKS_ARN}#;" templates/k8s_cluster.yml > ${DEPLOYPATH}/cluster_config/k8s_cluster.yml
  sed "s#POOLID#${UserPoolId}#;s#CLIENTID#${UserPoolClientId}#;s#IDPISSUERURL#${UserPoolIssuer}#;s#EKSARN#${EKS_ARN}#;s#OODCIDR#${OOD_CIDR}#" templates/hook.env > ${DEPLOYPATH}/cluster_config/hook.env

  # Bootstrapping the Kuberenetes cluster
  kubectl apply -f https://raw.githubusercontent.com/OSC/ondemand/master/hooks/k8s-bootstrap/ondemand.yaml
  
  echo "mkdir -p /etc/ood/config/clusters.d"
  echo "mkdir -p /etc/pki/tls/certs"
  echo "Copy ${DEPLOYPATH}/cluster_config/kubernetes-ca.crt to /etc/pki/tls/certs/kubernetes-ca.crt" 
  echo "Copy ${DEPLOYPATH}/cluster_config/k8s_cluster.yml to /etc/ood/config/clusters.d/"
  echo "Copy ${DEPLOYPATH}/cluster_config/hook.env to /etc/ood/config/hook.env"
}


# --------------- Main ---------------------

echo 
echo "................"
echo 

# Create the security groups for the nodes based on the cidr and vpc id
echo Create the security groups for the nodes based on the cidr and vpc id
ood_cidr_sg
echo "................"
echo 

# check SG ID not empty
echo "Check that security group Id is populated, otherwise exit"
if [ -z $SGID ]; then
  echo "SGID is empty"
  #rm -fr $DEPLOYPATH
  exit 1
fi

# Prepare the templates
echo Prepare the templates
prepare_templates
echo "................"
echo 

# Create the EKS cluster
echo Create the EKS cluster
eksctl create cluster -f ${DEPLOYPATH}/eks.yaml
echo "................"
echo 

# Update .kub/config 
echo Update .kube/config 
echo > ~/.kube/config
aws eks update-kubeconfig --region=${REGION} --name ${CLUSTER_NAME}
echo "................"
echo 

# Associate the identity provider to the EKS cluster
echo Associate the identity provider to the EKS cluster
eksctl associate identityprovider -f ${DEPLOYPATH}/identity-provider.yaml
echo "................"
echo 

# Create the autoscaler node group for the EKS cluster
echo Create the autoscaler node group for the EKS cluster
eksctl create nodegroup --config-file=${DEPLOYPATH}/autoscaler_nodegroups.yaml
echo "................"
echo 

# Setup job-pod-reaper into the cluster
echo Setup job-pod-reaper into the cluster
setup_job_pod_reaper
echo "................"
echo 

# Setup Calico required for namespace level network policy enforcement
echo Setup Calico required for namespace level network policy enforcement
setup_calico
echo "................"
echo 

# Configure the autoscaler
echo Configure the autoscaler
autoscaler_config
echo "................"
echo 

# Create the worker node group
echo Create the worker node group
eksctl create nodegroup --config-file=${DEPLOYPATH}/${NODE_TYPE}_nodegroups.yaml
echo "................"
echo 

# Associate the IAM Identity Mappings with a config map called aws-auth in the EKS cluster.
echo Associate the IAM user identity mapping to the EKS cluster
eksctl create iamidentitymapping --region=${REGION} --cluster ${CLUSTER_NAME} --arn arn:aws:iam::${ACCOUNT}:user/${IAM_USER} --username ${IAM_USER} --group system:masters --no-duplicate-arns
echo "................"
echo 

# Prepare the cluster configuration file and certificate
echo Prepare the cluster configuration file and certificate
cluster_config
echo "................"
echo 

echo DONE
echo
