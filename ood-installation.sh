#!/bin/bash

#
# Install Open OnDemand, create user 'ondemand' with password 'ondemand'
#
# Input:
#	HOSTNAME CLUSTER_CONFIG_FILE K8S_CERTIFICATE
# Output:
#	http://${HOSTNAME}/pun/sys/dashboard
#	Login with user 'ondemand' with password 'ondemand'
#
# Usage:
#	ood-installation.sh <HOSTNAME> <CLUSTER_CONFIG_FILE> <K8S_CERTIFICATE> <HOOKENV>
# Example:
#	ood-installation.sh ood.seas.harvard.edu /tmp/k8s_cluster.yml /tmp/kubernetes-ca.crt /tmp/hook.env



if (($# < 4))
then
	echo "Number of arguments should be 3"
	exit 255
fi

HOSTNAME=$1
K8SCLUSTERCONFIG=$2
KUBECERT=$3
HOOKENV=$4


hostnamectl set-hostname  ${HOSTNAME}

# Install required pkgs
yum install -y centos-release-scl epel-release
yum install -y https://yum.osc.edu/ondemand/2.0/ondemand-release-web-2.0-1.noarch.rpm
yum install -y ondemand

# SELinux should be disabled otherwise need some work
sestatus

# Open Ports 80 and 443 from the Firewall or/and Security groups
iptables -L

# Start and Enable Apache
systemctl start httpd24-httpd
systemctl enable httpd24-httpd


# For testing purposes , add ondemand user . Only for development and testing purposes
#groupadd ondemand
#useradd -d /home/ondemand -g ondemand -k /etc/skel -m ondemand
#echo 'ondemandPassword' | /bin/passwd --stdin ondemand	#<-- Use this for authentication

# Add simple authentication -  PAM Authentication
# PAM can be used to authenticate users to OnDemand, for example if users only exist in /etc/passwd and /etc/shadow.
# https://osc.github.io/ood-documentation/master/authentication/pam.html
# /opt/ood/ood_auth_map/bin/ood_auth_map.regex <-- Faras commented out this line that is in the docs but the file is not found
yum install -y mod_authnz_pam
cp /usr/lib64/httpd/modules/mod_authnz_pam.so /opt/rh/httpd24/root/usr/lib64/httpd/modules/
echo "LoadModule authnz_pam_module modules/mod_authnz_pam.so" > /opt/rh/httpd24/root/etc/httpd/conf.modules.d/55-authnz_pam.conf
cp /etc/pam.d/sshd /etc/pam.d/ood
chmod 640 /etc/shadow
chgrp apache /etc/shadow
 
cat >> /etc/ood/config/ood_portal.yml << EOF
pun_pre_hook_root_cmd: /opt/ood/pre-hook.sh
servername: $HOSTNAME

host_regex: '[^/]+'
node_uri: '/node'
rnode_uri: '/rnode'

auth:
  - 'AuthType Basic'
  - 'AuthName "Open OnDemand"'
  - 'AuthBasicProvider PAM'
  - 'AuthPAMService ood'
  - 'Require valid-user'
# Capture system user name from authenticated user name
#user_map_cmd: "/opt/ood/ood_auth_map/bin/ood_auth_map.regex"
EOF
 

cat >> /var/www/ood/apps/sys/dashboard/config/initializers/session_store_override.rb << EOF
# setting this to false means you can have this stored in a cookie - but your session data is 
# transmitted over plain http which is not very secure!
Rails.application.config.session_store :cookie_store, key: '_dashboard_session', secure: false
EOF


mkdir -p /etc/ood/config/clusters.d
mkdir -p /etc/pki/tls/certs
cp $KUBECERT  /etc/pki/tls/certs/
cp $K8SCLUSTERCONFIG  /etc/ood/config/clusters.d/
cp $HOOKENV  /etc/ood/config/

rm -fr /opt/ood/pre-hook.sh
rm -fr /opt/ood/hooks

cp -r hooks_files/* /opt/ood/


# Restart the service
/opt/ood/ood-portal-generator/sbin/update_ood_portal
systemctl try-restart httpd24-httpd.service httpd24-htcacheclean.service

# Open the browser and login using ondemand user credentials
echo In your browser open http://${HOSTNAME}/pun/sys/dashboard

curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
mv /tmp/eksctl /usr/local/bin
ln -s /usr/local/bin/eksctl /bin/eksctl


curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
curl -LO "https://dl.k8s.io/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl.sha256"
echo "$(<kubectl.sha256) kubectl" | sha256sum --check
install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
ln -s /usr/local/bin/kubectl /bin/kubectl
rm -fr kubectl
rm -fr kubectl.sha256

yum install python3-pip -y
pip3 install awscli
ln -s /usr/local/bin/aws /bin/aws
aws configure


echo "======================================"
echo 
echo "you might need to trigger this command on the head node to configure .kube/config for the root"
echo 
echo aws eks update-kubeconfig --name YOUR-EKS-CLUSTER-NAME
echo
echo "Replace YOUR-EKS-CLUSTER-NAME with your EKS cluster name"
echo
echo "======================================"
