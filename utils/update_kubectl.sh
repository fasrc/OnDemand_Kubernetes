
REGION=us-east-1

aws sts get-caller-identity

CLUSTER_NAME=$(aws eks list-clusters --output text | awk '{print $2}')

aws eks update-kubeconfig --region ${REGION} --name ${CLUSTER_NAME}


END_POINT=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.endpoint" --output text | sed 's/https:\/\///')

IDENTITY_ISSUER=$(aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.identity.oidc.issuer" --output text)


eksctl get nodegroup --cluster=${CLUSTER_NAME}

kubectl get po -A
