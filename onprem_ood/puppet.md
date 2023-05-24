[_metadata_:author]:-"rjsingh"
[_metadata_:tags]:-["puppet","academic-ondemand","onprem","gateway"]

## Academic Cluster Onprem Puppet Changes 

To connect EKS cluster with onprem OnDemand, following changes are made in puppet. OnDemand uses FASRC [puppet 3 repo](https://gitlab-int.rc.fas.harvard.edu/puppet/puppet) and to access the repo, you will need to connect to FASRC hprc VPN and need to have GitLab account
 

### Changes to [academic-login.yaml](https://gitlab-int.rc.fas.harvard.edu/puppet/puppet/-/blob/production/hieradata/hosts/academic-login.yaml)

######Path: hieradata/hosts/academic-login.yaml

Changes:

1. To install python3 and python3-pip.
2. Allow access to members of academicportal_admins AD group to academic-login nodes. This is to run puppet, make cluster changes and debug kubernetes pods.
3. AWS Credentials and config is stored as part of this file.
4. Review the install-awscli and install-kubectl for installed libraries. 
5. "update-cluster" section has the cluster name so will need a change when you update the cluster.

Following is the merge request to look at to review inital changes made to make this work. [Link](https://gitlab-int.rc.fas.harvard.edu/puppet/puppet/-/merge_requests/5131)




