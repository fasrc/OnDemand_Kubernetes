	
#!/bin/bash

#
# Chek and cleanup pods and namespaces
#
# Input:
#	OPTION NAMESPACE 
# Output:
#
# Usage:
#	./check_cleanup_pods_ns_services.sh <OPTION> <NAMESPACE>
# Example:
#	./check_cleanup_pods_ns_services.sh 1 ju-3142345
#          will check resources of the namespace ju-3142345

OPTION=$1	
NAMESPACE=$2


function res_check() {

	echo
	echo "..........    NameSpace = $NAMESPACE    .........."
	echo
	echo "====================================================================="
	echo "............... configmaps  .............."
	#kubectl get  configmaps --namespace=$NAMESPACE | grep jupyter-  | awk '{print $1}'
	jcm=$(kubectl get  configmaps --namespace=$NAMESPACE | grep jupyter-  | awk '{print $1}')
	echo $jcm
	echo "kubectl describe configmap $jcm --namespace=$NAMESPACE"
	echo
	echo "====================================================================="
	echo "............... services  .............."
	#kubectl get  services   --namespace=$NAMESPACE | grep jupyter-  | awk '{print $1}'
	jsv=$(kubectl get  services   --namespace=$NAMESPACE | grep jupyter-  | awk '{print $1}')
	echo $jsv
	echo "kubectl describe service $jsv --namespace=$NAMESPACE"
	echo
	echo "====================================================================="
	echo "............... secrets  .............."
	#kubectl get  secrets    --namespace=$NAMESPACE | grep jupyter-  | awk '{print $1}'
	jsc=$(kubectl get  secrets    --namespace=$NAMESPACE | grep jupyter-  | awk '{print $1}')
	echo $jsc
	echo "kubectl describe secret $jsc --namespace=$NAMESPACE"
	echo
	echo "====================================================================="
	echo "............... pods  .............."
	#kubectl get  pods       --namespace=$NAMESPACE | grep jupyter-  | awk '{print $1}'
	jpo=$(kubectl get  pods       --namespace=$NAMESPACE | grep jupyter-  | awk '{print $1}')
	echo $jpo
	echo "kubectl describe pods $jpo --namespace=$NAMESPACE"  
	echo
	echo "====================================================================="
	
}
	
	
	
function res_delete() {
	
	jcm=$(kubectl get  configmaps --namespace=$NAMESPACE | grep jupyter-  | awk '{print $1}')
	jsv=$(kubectl get  services   --namespace=$NAMESPACE | grep jupyter-  | awk '{print $1}')
	jsc=$(kubectl get  secrets    --namespace=$NAMESPACE | grep jupyter-  | awk '{print $1}')
	jpo=$(kubectl get  pods       --namespace=$NAMESPACE | grep jupyter-  | awk '{print $1}')
	
	
	echo "=================================="
	echo "Remove ConfigMaps start with jupyter-"
	echo
	
	if [ ! -z "$jcm" ]
	then 
		for cm in $jcm 
		do 
			echo Remove: $cm
			kubectl delete configmap $cm --namespace=$NAMESPACE
		done
	else
		echo "No ConfigMap start with  jupyter-"
	fi
	
	echo
	
	
	echo "=================================="
	echo "Remove Secrets start with jupyter-"
	echo
	
	if [ ! -z "$jsc" ]
	then 
		for sc in $jsc
		do
			echo Remove: $sc
			kubectl delete secret $sc --namespace=$NAMESPACE
		done
	else
		echo "No Secret start with  jupyter-"
	fi
	
	echo
	
	echo "=================================="
	echo "Remove Servies start with jupyter-"
	echo
	
	if [ ! -z "$jsv" ]
	then 
		for sv in $jsv
		do
			echo Remove: $sv
			kubectl delete service $sv --namespace=$NAMESPACE
		done
	else
		echo "No Service start with  jupyter-"
	fi
	
	echo
	
	
	
	echo "=================================="
	echo "Remove Pods start with jupyter-"
	echo
	
	if [ ! -z "$jpo" ]
	then 
		for po in $jpo
		do
			echo Remove: $po
			kubectl delete pod $po --namespace=$NAMESPACE
		done
	else
		echo "No Pod start with  jupyter-"
	fi
	
	echo
}

case $OPTION in
	1) res_check  ;;
	2) res_delete ;;
	*) echo "1: res_check, 2:res_delete" ;;
esac

