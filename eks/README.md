
## Deployment

#### Prerequisites

Please check the ManualInstructions.md file for more details about the requirements and requirements installation.

**IAM Credentials** described in the main README.md file.\
**IAM_USER** described in the main README.md file.\
**AWSCLI**\
**EKSCTL**\
**KUBECTL**\
**HELM**\
**COGNITO-STACK-NAME** cognito stack name that created the cognito user's pool to be used as Identity provider.\
**SSH_KEY**  described in the main README.md file.\
**GPU AMI**: An newly created GPU based **EKS-Optimized AMI** that will be used in GPU node group template.  [Read here](../packer/README.md) on how to build this AMI.

To create an EKS cluster with the nodegroup Run ``` deploy.sh ``` with the required parameters or using `.env` file.

##### Deploy with `.env` file
If the file `.env` exist, then `deploy.sh` will use this file to populate all the required variables like vpc id, subnet ids, etc.\
copy `.env.example` to `.env` and update the values to match your cluster networks and resources to use `.env` with the `deploy.sh`.
```
cp .env.example .env 
EDIT .env and update the values
deploy.sh CLUSTER_NAME
```

##### Deploy without `.env` file
In this case (`.env` file is not exist), `deploy.sh` needs the parameter specified below

```
deploy.sh CLUSTER_NAME REGION VPCTAG SUB1TAG SUB2TAG SSH_KEY IAM_USER OOD_CIDR COGNITO-STACK-NAME gpu|general
```

Where:

**CLUSTER_NAME** is the name of the EKS cluster you intend to create. Should be unique across EKS clusters on the same account and region.\
**REGION**: Region where EKS will be deployed (us-east-1 in our case).\
**VPCTAG**: The VPC tag name. Here you should use the value of the tag name of the VPC.\
**SUB1TAG**: The value of the tag name of the first subnet where EKS will be deployed.\
**SUB2TAG**: The value of the tag name of the second subnet where EKS will be deployed.\
**SSH_KEY**: ssh key name attached to each node in case a login needed to that node (for debugging).\
**IAM_USER**: IAM Service user that will be on the ondemand node to trigger API calls to cognito and eks\
**OOD_CIDR**: the CIDR of the open ondemand head node.\
**COGNITO-STACK-NAME**: The name of the cognito stack that will be used as the identity provider for the EKS cluster.\
**general|gpu**: need to specify either gpu or general given that you have a `gpu_nodegroups.yaml` or `general_nodegroups.yaml` located at `eks/templates/` folder.\

**Important:** while using `gpu` please update the **GPU AMI** in `eks/templates/gpu_nodegroups.yaml` template.

Example:
```
deploy.sh fas-ood-eks us-east-1 atood-dev-standard atood-dev-standard-app-pvt-1a atood-dev-standard-app-pvt-1b eks 10.31.0.0/16 ood-cognito-fas general
```

In this example ```deploy.sh``` will extract the **VPC Id** from **atood-dev-standard** tag name, and the **Subnet Ids** from **atood-dev-standard-app-pvt-1a** and **atood-dev-standard-app-pvt-1b**  tag names.The code will also get the **pool id** and **client pool id** and the **issuer url** from **ood-cognito-fas** cognito stack.\
Then the code will create a security group and EKS cluster with the name **fas-ood-eks** on the **us-east-1** region on the extracted VPC and the Subnets. The code will associate the extracted cognito attributes (poolid, client id and issuer url) to the EKS cluster for identity management, and it will  create and configure the **autoscaler** and the **autoscaler node group**.

#### Warmpool

AWS **warmpool** should be configured manually at this stage.\
To configure the **warmpool** for the above example ```deploy.sh fas-ood-eks ... ```
* Login to AWS
* EC2 -> Auto Scaling -> Auto Scaling Groups
* Locate the name of the Nade group created by ```deploy.sh```, name would be something like eksctl-**fas-ood-eks**-nodegroup-**general**-nodegroup-NodeGroup-A0BCD1EFG23H 
* Instance management -> Warm pool -> Action -> Edit
* Fill out the parameters -> Save changes

## Deleting an EKS cluster

To delete the EKS cluster, you first need to delete all the resources associated with the cluster like the Node Groups and its IAM Roles and Policies. ```delete.sh``` with the EKS cluster name can do that. \
So to delete an EKS cluster, run
 
```
delete.sh CLUSTER_NAME
```

Replace **CLUSTER_NAME** with you EKS cluster name. And that will delete the EKS CLUSTER_NAME resources, then it will delete the EKS cluster with the name **CLUSTER_NAME**.

Example:

```
delete.sh eks-fas-1
``` 

if the EKS cluster with the name **eks-fas-1** is available, the script will delete the policies, roles, node group(s) of the **eks-fas-1** cluster then it will delete the **eks-fas-1** itself.

#### Warmpool

If you attach a **warmpool** to the AWS node group autoscaler manually, then delete the **warmpool** manually before running the ```delete.sh``` script. Otherwise, the deletetion of that node group might take long time (and it might fail!).


