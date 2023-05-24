#! /bin/bash

# Delete a deploy EKS cluster
# Required parameters:
#	CLUSTER_NAME
# Usage:
#   ./delete.sh CLUSTER_NAME REGION
# Example
#  ./delete.sh fas-ood-eks us-east-1
# 

# Number of arguments should be 1
if (($# < 2))
then
	echo "Number of arguments should be 2"
	exit 255
fi

CLUSTER_NAME=$1
REGION=$2

aws eks update-kubeconfig --region=${REGION} --name ${CLUSTER_NAME}

# Remove Calico from the cluster.
helm uninstall calico

# Remove job-pod-reaper from the cluster
kubectl delete -f https://github.com/OSC/job-pod-reaper/releases/latest/download/ondemand-deployment.yaml
kubectl delete -f https://github.com/OSC/job-pod-reaper/releases/latest/download/namespace-rbac.yaml

# Delete the iamserviceaccount role 
eksctl delete iamserviceaccount --region=${REGION} --cluster=${CLUSTER_NAME} --name=cluster-autoscaler --namespace=kube-system

# List nodegroups of the ${CLUSTER_NAME}
nodegroups=$(eksctl get nodegroups --region=${REGION} --cluster=${CLUSTER_NAME} | grep -v NODEGROUP |  awk '{print $2}')

# Move through the nodegroups names and delete them
for ng in $nodegroups
do
  eksctl delete nodegroup --region=${REGION} $ng --cluster=${CLUSTER_NAME}
done

# Get the account Id that will be used to get the policy arn from the policy name
account_id=$(aws sts get-caller-identity  --region=${REGION} --query 'Account'  --output text)

# Suppose the policy name is ${CLUSTER_NAME}-AmazonEKSClusterAutoscalerPolicy as in deploy.sh
policy_name=${CLUSTER_NAME}-AmazonEKSClusterAutoscalerPolicy

# Generate the policy arn
policy_arn="arn:aws:iam::${account_id}:policy/${policy_name}"

# Delete the policy using the policy arn (you can not delete policy based on name, it should be on policy arn)
aws iam delete-policy --region=${REGION} --policy-arn ${policy_arn}

# Delete the EKS Cluster
eksctl delete cluster --region=${REGION} --name ${CLUSTER_NAME}

# Delete the security group CF stack
OOD_SG_NAME="${CLUSTER_NAME}-Nodes-Security-Group"
aws cloudformation delete-stack --region=${REGION} --stack-name ${OOD_SG_NAME}

