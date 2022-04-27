# capi-demo

This demo is about using cluster api to setup and install EKS clusters and as a post step configure and add files to flux so the cluster is preinstalled with additional components  

The demo.sh script (which is sort of executable documentation) will  

- Launch a Kind based control plane
- Install CAPI
- Install Cluster Bootstrap Controller  
- Configure the cluster bootstrap controller with some items details below  
- Launch a cluster  
- Display cluster state  

The cluster bootstrap does the following.

- run flux bootstarp  
- create iam role (with a trust policy for the cluster & service account) for kustomize  
- create iam role (with a trust policy for the cluster & service account) for external-dns  
- create iam role (with a trust policy for the cluster & service account) for cluster-autoscaler  

Before running you will need to  

1. Fork this git repository [https://github.com/owainperry/capi-demo-flux.git](https://github.com/owainperry/capi-demo-flux.git)

2. Have some aws credentials with suitable permissions to create IAM roles and EKS, VPC subnets etc which can be sourced from ~/bin/aws-capi-login or comment line 91 of demo.sh if you already have AWS permissions setup via any other of the usual ways for aws.  

3. you will need the following installed and on your $PATH:  

- install kubectl           "brew install kubectl "
- install kind              "brew install kind "
- install helm              "brew install helm "
- install flux              "brew install fluxcd/tap/flux "
- install aws              "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
- install clusterawsadm    "https://github.com/kubernetes-sigs/cluster-api-provider-aws/releases"
- install clusterctl       "https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.1.3/clusterctl-darwin-arm64"

4. Set your github token for flux to use in github-token-secret.yaml it will need repo permissions

e.g.  copy the result of this into that file 
kind 
```bash 
echo -n "ghp_JW0C0CeKgQetudDn3BaBx3nBA41234567890" | base64 
```
5. Update file clusterbootstrap-cluster.yaml:  

- Add a github token on line 542 base64 encoded to the secret to give access to the flux github repository  
- Change the owner on line 347 to your github (or change the flux bootstrap command as you see fit)
- Change the repository to yours on line 349  
- Change the repository details on line 375  

6. Then run  

```bash
demo.sh 
```

It will take roughly 15 mins to spin up an EKS cluster you get the provisioned cluster credentials with:  

```bash
clusterctl get kubeconfig <name> --namespace clusters > ~/.kube/<name>.yaml
```

7. To delete the cluster 

```bash 
kubectl delete cluster cluster-1 
```

8. Manually delete the iam roles that have been created , search for "cluster-1" in iam roles. 

9. Delete the kind cluster 

```bash 
kind delete cluster --name cplane1
```

