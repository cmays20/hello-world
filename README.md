# Spring Boot Hello-World application
This app is for demoing OpenShift Pipelines

#Prerequisites


#Demo Setup

##Add Pipelines Operator

##Clone hello-world locally

##Create hello-world Project

oc create ns hello-world

oc project hello-world

##Add Persistent Volumes

##Add pipeline manifests

##Setup Tekton Task github-set-status

Make sure to run from inside namespace hello-world

kubectl create secret generic github --from-literal token="MY_TOKEN" 

kubectl apply -f https://raw.githubusercontent.com/tektoncd/catalog/main/task/github-set-status/0.2/github-set-status.yaml

##Add secret for access to quay

oc create secret docker-registry quay-registry --docker-server=quay.io --docker-username=<username> --docker-password=<password>

oc secrets link pipeline quay-registry --for=pull,mount

##Add Triggers and Tasks

##Point Webhook at triggers

oc get routes

##Allow pipeline service account to read the cluster api

oc adm policy add-cluster-role-to-user cluster-reader -z pipeline

##Setup for Prometheus Monitoring

Apply the manifest in Monitoring

oc adm policy add-cluster-role-to-user monitoring-edit -z pipeline

##Setup User defined Grafana

https://www.redhat.com/en/blog/custom-grafana-dashboards-red-hat-openshift-container-platform-4

Add Grafana Operator to namespace my-grafana

Create a Grafana instance with the name my-grafana

oc apply -f Grafana/grafana.yaml

oc adm policy add-cluster-role-to-user cluster-monitoring-view -z grafana-serviceaccount

oc serviceaccounts get-token grafana-serviceaccount -n my-grafana

Replace BEARER_TOKEN in grafana-ds.yaml

oc apply -f Grafana/grafana-ds.yaml