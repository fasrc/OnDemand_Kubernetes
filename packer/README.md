## Packer

[Packer](https://www.packer.io/) is a CLI tool that automates the process of building AMIs.

## Structure

This directory contains a single packer template `eks-node-gpu.json` that builds an EKS AMI for GPU nodes. You must specify the `vpc_id`, `subnet_id`, and `source_ami` in order to build the AMI. These variables are defined in `dev.json` and `prod.json` respectively, depending on which AWS account you want to build the AMI.

```
packer
├── dev.json
├── eks-node-gpu.json
└── prod.json
```

## Usage

```sh
$ packer validate eks-node-gpu.json
$ packer build -var-file=dev.json eks-node-gpu.json
```

When `packer build` is called, it will do the following:

- Launch a temporary EC2 instance using an [EKS optimized Amazon Linux](https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html) as the base AMI.
- Provision the EC2 instance with packages/software, possibly pre-loading docker images.
- Create a snapshot (AMI) of the EC2 instance.


## EKS Optimized Amazon Linux for GPU

To retrieve the [EKS optimized Amazon Linux](https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html) AMI ID:

```
aws ssm get-parameter --name /aws/service/eks/optimized-ami/1.23/amazon-linux-2-gpu/recommended/image_id --region us-east-1 --query "Parameter.Value" --output text
```

See also:
- https://docs.aws.amazon.com/eks/latest/userguide/retrieve-ami-id.html
- https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html#gpu-ami