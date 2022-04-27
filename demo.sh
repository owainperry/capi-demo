#!/bin/bash 
set -e

CONTROL_PLANE_NAME=cplane1
CLUSER_NAMESPACE=clusters

function isInstalled {
    if ! command -v $1 &> /dev/null    
    then
        echo "$1 could not be found install it: $2"
        exit 1
    fi
    echo -e "=> \033[0;32m \xE2\x9C\x94 \033[0;37m $1 installed "
}

function allPodsRunning {
    echo "=> Start Waiting for all pods to be in Running state"
    while [ $(kubectl get pods --all-namespaces | grep -v Running| grep -v Complete | grep -v NAME | wc -l) -ne 0 ]
    do
        sleep 1
    done
    echo -e "=> \033[0;32m \xE2\x9C\x94 \033[0;37m OK"
}

function waitForClusterReady {
    SECONDS=0
    echo "=> Start Waiting for all pods to be in Running state on cluster $1"
    while [ $(clusterctl describe cluster $1 --namespace clusters 2>&1 | grep False | wc -l) -ne 0 ]
    do
        clusterctl describe cluster $1 --namespace clusters
        sleep 10
        echo ""
    done
    echo -e "=> \033[0;32m \xE2\x9C\x94 \033[0;37m Cluster is ready Elapsed Time: $SECONDS seconds "
}

function waitForMachinePools {
    SECONDS=0
    echo "=> Start Waiting for all machines pools to be ready "
    while [ $(kubectl get awsmanagedmachinepools.infrastructure.cluster.x-k8s.io --namespace clusters 2>&1 | grep "false" | wc -l) -ne 0 ]
    do
        kubectl get awsmanagedmachinepools.infrastructure.cluster.x-k8s.io --namespace clusters
        sleep 10
        echo ""
    done
    echo -e "=> \033[0;32m \xE2\x9C\x94 \033[0;37m OK Elapsed Time: $SECONDS seconds"
}

function waitForClusterSetup {
    SECONDS=0
    echo "=> Start Waiting for bootstrap process"
    while [ $(kubectl get pods --namespace clusters 2>&1 | grep "Completed" | wc -l) -ne 1 ]
    do
        kubectl get pods --namespace clusters
        sleep 5
        echo ""
    done
    echo -e "=> \033[0;32m \xE2\x9C\x94 \033[0;37m OK Elapsed Time: $SECONDS seconds"
}

function setupKindCluster {
    if [ $(kind get clusters | grep $1 | wc -l) -ne 1 ]; then
    
     cat <<EOF | kind create cluster  --name $1 --config=-
 kind: Cluster
 apiVersion: kind.x-k8s.io/v1alpha4
 nodes:
 - role: control-plane
EOF
    
        echo "=> Creating a cluster called: $1"
        sleep 10
        allPodsRunning
    fi
}



isInstalled kubectl "brew install kubectl "
isInstalled kind    "brew install kind "
isInstalled helm    "brew install helm "
isInstalled flux    "brew install fluxcd/tap/flux "
isInstalled aws    "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
isInstalled clusterawsadm    "https://github.com/kubernetes-sigs/cluster-api-provider-aws/releases"
isInstalled clusterctl    "https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.1.3/clusterctl-darwin-arm64"


echo "=> Get some aws credentials sourced"
source ~/bin/aws-capi-login

echo "=> Check credentials"
aws sts get-caller-identity 

setupKindCluster $CONTROL_PLANE_NAME

allPodsRunning

kubectl cluster-info

export CAPA_EKS_IAM=true
export CAPA_EKS_ADD_ROLES=true
export EXP_MACHINE_POOL=true
export EXP_CLUSTER_RESOURCE_SET=true
export CLUSTER_TOPOLOGY=true

echo "=> Run cloudformation for iam"
clusterawsadm bootstrap iam create-cloudformation-stack --config bootstrap-config.yaml

export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)

echo "=> Install capi on  $CONTROL_PLANE_NAME cluster"
clusterctl init --infrastructure aws  --target-namespace $CLUSER_NAMESPACE || true 

allPodsRunning

echo "=> Install cluster bootstrap controller"

kubectl apply -f https://github.com/weaveworks/cluster-bootstrap-controller/releases/download/v0.0.5/cluster-bootstrap-controller-v0.0.5.yaml

allPodsRunning

echo "=> Setup custom tasks on cluster creating"
kubectl apply -f ./cluster-resource-set.yaml
kubectl apply -f ./clusterbootstrap-cluster.yaml
kubectl apply -f ./github-token-secret.yaml

ENV_NAME=cluster-1

echo "=> Create a cluster using capi"
kubectl apply -f ./$ENV_NAME.yaml 
waitForClusterReady $ENV_NAME

waitForMachinePools

waitForClusterSetup

echo "=> Describe the cluster" 
echo "=> clusterctl describe cluster penv3 --namespace clusters"
clusterctl describe cluster $ENV_NAME --namespace clusters

echo "=> Get kubeconfig"
clusterctl get kubeconfig $ENV_NAME --namespace clusters > ~/.kube/$ENV_NAME.yaml

