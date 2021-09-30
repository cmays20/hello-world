# Spring Boot Hello-World application
This app is for demoing OpenShift Pipelines

#Prerequisites


#Demo Setup
##Add Pipelines Operator
##Create hello-world Project
##Add pipeline manifests
##Setup Tekton Task github-set-status
Make sure to run from inside namespace hello-world

kubectl create secret generic github --from-literal token="MY_TOKEN" 
kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/github-set-status/0.2/github-set-status.yaml
##Add secret for access to quay
This might be best if we add a service account that is custom for this called build-bot
oc create secret docker-registry quay-registry --docker-server=quay.io --docker-username=<username> --docker-password=<password>
oc secrets link pipeline quay-registry --for=pull

##Add Triggers

##Point Webhook at triggers
oc get routes

##Allow pipeline service account to read the cluster api
oc adm policy add-cluster-role-to-user cluster-reader -z pipeline