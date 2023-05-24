## Requirements:


1. In AWS Console:

	1. Create IAM User with Admin Policy  
	Name: ```full_admin-for-eks-test``` with policy  
		```AdministratorAccess```  


	2. Create SSH keys to login to EC2 i.e. we have created `eks`


	3. Create a Security Group that will be used during Auto Scaling Group creation i.e. `as_nodegroups.yaml` and `gpu_nodegroups.yaml`. We need to add an inbound rule with **Type**: "All traffic" and **Source**: "0.0.0.0/0".

2. In the node (could be the onDemand web node)
	1. **awscli**  
	to grep authentication token required by eksctl (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
		```yum install python3-pip -y```  
		```pip3 install awscli```  
		```aws configure```  
		The below line is needed on the onDemand web server  
		```ln -s /usr/local/bin/aws /bin/aws ``` OR ```cp /usr/local/bin/aws /bin/aws``` 


	2. **eksctl**  
	setup and operation of EKS cluster(https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html)  
		```curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp```  
		```mv /tmp/eksctl /usr/local/bin```  


	3. **kubectl**  
	interaction with K8s API server (https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)  
		Ubuntu: ```snap install kubectl --classic```  
		Linux  
			```curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"```  
			```curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"```  
			```echo "$(<kubectl.sha256) kubectl" | sha256sum --check```  
			```install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl```  

	4. **helm**  
	package manager for kubernetes used to install calico (https://helm.sh/)
			```curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash```


## Deployment

1. Create EKS Cluster
	- List available VPCs and Subnets
		- ```aws ec2 --output text --query 'Vpcs[*].{VpcId:VpcId,Name:Tags[?Key==`Name`].Value|[0],CidrBlock:CidrBlock}' describe-vpcs```
		
		- ```aws ec2 --output text --query 'Subnets[*].{VpcId:VpcId,SubnetId:SubnetId,Name:Tags[?Key==`Name`].Value|[0]}' describe-subnets```

	- Using existing vpc:
		
		- ```SUBNET1=subnet-08716face1e8cc237; SUBNET2=subnet-07d895a17261f2277;VPC=vpc-0c7039f898660e678;REGION=us-east-1;CLUSTERNAME=EKS-ondemand-cluster```
		
		- ```sed "s/CLUSTERNAME/${CLUSTERNAME}/; s/REGION/${REGION}/; s/VPCID/${VPC}/; s/SUBNETID1/${SUBNET1}/; s/SUBNETID2/${SUBNET2}/" eks_cluster_with_vpc_template.yaml > eks_cluster_with_vpc.yaml```
		
		- ```eksctl create cluster -f eks_cluster_with_vpc.yaml```

   
2. wait for about 15 minutes

3. Check kubeconfig ``` kubectl config <COMMANDS> ``` to configure  `~/.kube/config` i.e. `kubectl config view`

**Notes:**

   -  `eksctl` command will create a cloudformation stack. You can review on AWS console's CloudFormation service.

   -  `eksctl` creates iam provider: ```aws eks describe-cluster --name ${CLUSTERNAME} --query "cluster.identity.oidc.issuer" --output text```


4. Add auto scaler nodegroup
	
	- Create SG

		```aws cloudformation create-stack --region=us-east-1 --stack-name ood-sg --template-body file:///ood-security_groups.yaml  --parameters ParameterKey=VPC,ParameterValue="vpc-133424"```
	- Update Autoscaler yaml 

		- ```SGID=$(aws ec2 --output text --query 'SecurityGroups[*].{GroupName:GroupName,GroupId:GroupId}'  describe-security-groups | grep SG_OPEN_ALL_PORTS | awk '{print $1}')```
		- ```REGION=us-east-1;CLUSTERNAME=EKS-ondemand-cluster```
		- ```sed "s/CLUSTERNAME/${CLUSTERNAME}/; s/REGION/${REGION}/; s/OODSG/${SGID}/" as_nodegroups_template.yaml > as_nodegroups.yaml```


	- Add `autoscaler-nodegroup` with minimal spec that will be always running max one `t2.small` instance as Auto Scaling Manager.

		```eksctl create nodegroup --config-file=as_nodegroups.yaml```
		
5. Add users nodegroup

	- For GPU node group check https://aws.amazon.com/about-aws/whats-new/2018/08/amazon-eks-supports-gpu-enabled-ec2-instances/

	- ***Important***: First you need to build an AMI build using `packer.json` located here (Please review and change some of the AWS account depended values in this `packer.json` file before running it!), by running:
	
			packer validate packer.json
			packer build packer.json
	
	- Add `gpu-nodegroup` with GPU spec with custom build **EKS-Optimized AMI** based on `g4dn.xlarge` instance from 0 to 200 **(This is set as per maximum user count based on the course requirment)** and scale based on user's demand:

		- ```eksctl get nodegroup --cluster=${CLUSTERNAME}```
		- ```eksctl create nodegroup --config-file=gpu_nodegroups.yaml```

		***Important***: Need to increase the limit of the GPU instance type before using those instance types --> by sending ticket to AWS support team.

6. Deploy and annotate K8s autoscaler: https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html#cluster-autoscaler

		cd autoscaler/

		./autoscaler.sh ${CLUSTERNAME}

	***NOTE***: What we are doing in this `autoscaler.sh` bash script file is:

	- Delete autoscaled if not sure  
			```kubectl -n kube-system delete deployment cluster-autoscaler```  
	- Apply the autoscaller  
			```kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml```  
	- Annotate the autoscaler to not scale itself  
			```kubectl -n kube-system annotate deployment.apps/cluster-autoscaler cluster-autoscaler.kubernetes.io/safe-to-evict="false"```  
	- Create an IAM policy and role: please look at https://docs.aws.amazon.com/eks/latest/userguide/autoscaling.html for details. Note that eksctl will create the policy that should be attached to the service using ```eksctl create iamserviceaccount  .... ``` as in the documentation of aws.

---

## (For Furture Update) update the autoscaler
- open https://github.com/kubernetes/autoscaler/releases and get the latest release version matching your Kubernetes version  
- set the image version at property ```image=k8s.gcr.io/cluster-autoscaler:vx.yy.z```  
	e.g. Kubernetes 1.21 => check for 1.21.n where "n" is the latest release version  
- Also change <YOUR CLUSTER NAME> with the name of your cluster  
- set your EKS cluster name at the end of property  
	```--node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/<<EKS cluster name>>```  
- Edit the autoscaler  
	```kubectl -n kube-system edit deployment.apps/cluster-autoscaler```  
- Describe the autoscaler  
	```kubectl -n kube-system describe deployment cluster-autoscaler```  
- Check the logs for the autoscaler  
	```kubectl -n kube-system logs deployment.apps/cluster-autoscaler```
---
## Useful commands on node group
		- Add all node groups in ```nodegroups_01.yaml```
		```eksctl create nodegroup --config-file=nodegroups_01.yaml```

		- OR: Add one node group in ```nodegroups_01.yaml```  
		```eksctl create nodegroup --config-file=nodegroups_01.yaml --include='scale-east1c'```

		```eksctl get nodegroup --cluster=EKS-ondemand-cluster```

		```eksctl delete nodegroup --config-file=nodegroups_01.yaml --include='scale-east1d' --approve```

		```eksctl scale nodegroup --cluster EKS-ondemand-cluster --nodes-max=10 --nodes=1 --name=scale-east1c```

		```eksctl scale nodegroup --cluster EKS-ondemand-cluster --nodes-min=1 --name=scale-east1c```

		```eksctl scale nodegroup --cluster EKS-ondemand-cluster --nodes-max=10 --nodes=1 --name=scale-east1c```

		```eksctl delete nodegroup --config-file=nodegroups_01.yaml  --include='scale-east1c' --approve```

## (Optional) Checking the system
This part is to check how to deploy pods in the created cluster

1. Create a namespace (Optional to separate words based on env, project, users etc)  
	```#ns=jupyter```  
	```ns=ondemand #<-- that what will be used,and should be created by the ondemand instruction not manually as i do here ```  
	```kubectl get namespaces```  
	```kubectl create namespace $ns```  
	```kubectl get namespaces```  


2. Deploy Jupyter on certain namespace, suppose 
	- deploying one pod only
	- use ```jupyter_1.yaml``` that have ```jupyter-deployment-1``` and  ```jupyter-service-1``` as deployment and service name
		```ns=ondemand```  
		```kubectl apply -f jupyter_1.yaml --namespace=$ns```  
		```jupyterdep1=$(kubectl get deployments --namespace=$ns | awk '{print $1}' | grep jupyter-deployment-1)```  
		```jupyterser1=$(kubectl get services --namespace=$ns | awk '{print $1}' | grep jupyter-service-1)```  
		```kubectl describe deployment $jupyterdep1 --namespace=$ns```  
		```kubectl describe service $jupyterser1 --namespace=$ns```  
		```jupyterpod1=$(kubectl get pods --namespace=$ns | awk '{print $1}' | grep jupyter-deployment-1)```  
		```kubectl logs $jupyterpod1 --namespace=$ns```  

		- note the url and token on the logs  
			eg: ```http://127.0.0.1:8888/?token=716cbde13c691d031cf98604b1d0841098dde8833a89bdc2```  
		- write down the token (**716cbde13c691d031cf98604b1d0841098dde8833a89bdc2**)  

3. Open the ports for the servers that have jupyter pods deployed  
	- get the node where the pod deployed  
	- open the web ports of node security group to the world  

4. Browes to jupyter container  
	- use the public IP (PUBLIC_IP)of the server that hosted pod  
	- prepare the NODEPORT (ex: nodePort: 30001) used in jupyter_1.yaml  
	- prepare the TOKEN from previos step (**716cbde13c691d031cf98604b1d0841098dde8833a89bdc2**)  
	- Browse to ```http://PUBLIC_IP:NODEPORT/?token=TOKEN```  

5. Clean up  
	```ns=ondemand```  
	```kubectl delete service $jupyterser1 --namespace=$ns```  
	```kubectl delete deployment $jupyterdep1 --namespace=$ns```  
	```kubectl get pods --namespace=$ns```  
	```kubectl delete namespace $ns```  


6. Useful debugging commands  
	```kubectl get events```  
	```kubectl get po```  
	```kubectl get pods --all-namespaces ```  
	```kubectl get pods --show-labels```  
	```kubectl get rs```  
	```kubectl get services```  
	```kubectl kubectl explain pods```  
