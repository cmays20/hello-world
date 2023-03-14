# Spring Boot Hello-World application
This app is for demoing OpenShift Pipelines

# Prerequisites

- Have an OpenShift (4.12+) cluster up and running
- Create a file in your home directory called NetworkAttachmentDefinition.yaml with these contents:
  ```yaml
  apiVersion: "k8s.cni.cncf.io/v1"
  kind: NetworkAttachmentDefinition
  metadata:
    name: istio-cni
  ```

## Add Operators

- Install Flux Operator
- Install OpenShift Pipelines Operator
- Install cert-manager Operator for Red Hat OpenShift
  - Create a cluster issuer for your environment

## Add External-DNS (Optional)

I rely on the External-DNS project to automatically update my DNS provider to point to my cluster.

https://github.com/kubernetes-sigs/external-dns

Follow the instructions for your dns provider.  If you are using one of the major clouds, 
Red Hat has an operator that may work for you as well.

## Install Big Bang on your cluster

TODO: NEED TO UPDATE TO POINT AT THE LATEST INSTRUCTIONS

Currently need to add anyuid scc and NetworkAttachmentDefinition for Gitlab and Harbor

```
oc adm policy add-scc-to-group anyuid system:serviceaccounts:harbor
oc adm policy add-scc-to-group anyuid system:serviceaccounts:gitlab

helm upgrade --install bigbang $HOME/bigbang/chart \
  --values $HOME/ingress-certs.yaml \
  --values $HOME/ib_creds.yaml \
  --values $HOME/demo_values.yaml \
  --namespace=bigbang --create-namespace
  
oc apply -f ~/NetworkAttachmentDefinition.yaml -n harbor
oc apply -f ~/NetworkAttachmentDefinition.yaml -n gitlab
```

Add NetworkPolicy for Harbor and Gitlab.  This is so the router can validate the certificates it is going to request using
cert-manager and let's encrypt.

```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: ingress-router
  namespace: harbor
spec:
  podSelector: {}
  ingress:
    - from:
        - podSelector: {}
          namespaceSelector:
            matchLabels:
              name: openshift-ingress
  policyTypes:
    - Ingress
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: ingress-router
  namespace: gitlab
spec:
  podSelector: {}
  ingress:
    - from:
        - podSelector: {}
          namespaceSelector:
            matchLabels:
              name: openshift-ingress
  policyTypes:
    - Ingress
```

# Demo Setup

## Gitlab Setup

Get the initial root password
```shell
oc get secret gitlab-gitlab-initial-root-password -n gitlab --template={{.data.password}} | base64 -d
```
1. Deactivate the public sign-up capability.  You should have a prompt at the top of the page.
2. Create a user for the demo (then edit the user to add an initial password)
3. Create a group called Red Hat (the URL path will end up being red-hat).
4. Add the user as an owner of the group
5. Import the hello-world project (Github Access token required)
6. Import the hello-world-deploy project (Github Access token required)
7. Logout and log back in as the user that was setup (You will be asked to update your password)
8. Create a Personal access token at the Red Hat group level that gives API access as a maintainer
9. Add the below secrets to the argocd namespace so that it can login to gitlab
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: hello-world-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://<GITLAB_URL>/red-hat/hello-world.git
---
apiVersion: v1
kind: Secret
metadata:
  name: hello-world-deploy-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: https://<GITLAB_URL>/red-hat/hello-world-deploy.git
---
apiVersion: v1
kind: Secret
metadata:
  name: private-repo-creds
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repo-creds
stringData:
  type: git
  url: https://<GITLAB_URL>/red-hat/
  password: <GITLAB_TOKEN>
  username: <GITLAB_USER>
```
NOTE: Make sure to replace GITLAB_URL, GITLAB_TOKEN and GITLAB_USER with your values

## Harbor Setup

Login to Harbor, by default admin/Harbor12345 are the creds.
1. Once logged in as admin, update the password from the well known default
2. Create a new project called 'redhat'
3. Create a new user
4. Set that new user as an Admin
5. Add that user as a member to the 'redhat' project

## Sonarqube Setup
Login to Sonarqube, by default admin/admin are the creds.  It will ask you to update the password.

## Setup the pipeline

1. Create the hello-world-pipeline namespace `oc create ns hello-world-pipeline`
2. Give the pipeline user access to the oc api 
   `oc adm policy add-cluster-role-to-user cluster-reader -z pipeline -n hello-world-pipeline`
3. Add the gitlab token for the gitlab commit status update task
   `oc create secret generic gitlab-api-secret --from-literal=token=<GITLAB_ACCESS_TOKEN> -n hello-world-pipeline`
3. Add git credentials as a secret

    ```yaml
    kind: Secret
    apiVersion: v1
    metadata:
      name: git-basic-auth-secret
      namespace: hello-world-pipeline
    type: Opaque
    stringData:
      .gitconfig: |
        [credential "https://<hostname>"]
          helper = store
      .git-credentials: |
        https://<user>:<pass>@<hostname>
    ```
4. Apply the tekton-gitlab.yaml in the argo folder to the argocd namespace
5. Login to ArgoCD to check on its status
   ```shell
   oc get secret argocd-initial-admin-secret -n argocd --template={{.data.password}} | base64 -d
   ```
6. The PVCs will spin in ArgoCD until the pipelines are executed
7. Setup the webhooks in Gitlab
   1. Get the listener URLs: `oc get route -n hello-world-pipeline`
   2. In Gitlab, navigate to the hello-world project -> Settings -> Webhooks
   3. Add the non-test URL, click on push events, set the wildcard pattern to master
   4. Disable SSL verification then hit Add Webhook
   5. Now add the test webhook URL, click on Merge Request Events
   6. Disable SSL verification then hit Add Webhook
8. Add Harbor Secret
   1. Create secret and link to service account
      ``` 
      oc create secret docker-registry harbor-registry \
        --docker-server=<your-registry-server> \
        --docker-username=<your-name> \ 
        --docker-password=<your-pword> \
        -n hello-world-pipeline
      oc secrets link pipeline harbor-registry --for=pull,mount -n hello-world-pipeline
      ```
9. Add maven-settings.xml as a Config Map
   ```xml
   apiVersion: v1
   kind: ConfigMap
   metadata:
     name: maven-settings-cm
     namespace: hello-world-pipeline
   data:
     settings.xml: |-
       <settings>
         <pluginGroups>
           <pluginGroup>org.sonarsource.scanner.maven</pluginGroup>
         </pluginGroups>
         <profiles>
           <profile>
             <id>sonar</id>
             <activation>
               <activeByDefault>true</activeByDefault>
             </activation>
             <properties>
               <sonar.host.url>
                 #URL to sonarqube - use the internet path to avoid istio issues
               </sonar.host.url>
               <sonar.login>
                 #FILL IN WITH YOUR TOKEN FROM THE SONAR GUI
               </sonar.login>
             </properties>
           </profile>
         </profiles>
       </settings>
   binaryData: {}
   immutable: false
   ```

## Kick off Dev and Prod hello-world apps

```
oc create ns hello-world
oc label namespaces hello-world istio-injection=enabled
oc adm policy add-scc-to-group nonroot-v2 system:serviceaccounts:hello-world
oc apply -f ~/NetworkAttachmentDefinition.yaml -n hello-world
oc create secret docker-registry harbor-registry --docker-server=$HARBOR_URL --docker-username=$HARBOR_USER --docker-password=$HARBOR_PASS -n hello-world
oc secrets link default harbor-registry --for=pull,mount -n hello-world
oc create ns hello-world-dev
oc label namespaces hello-world-dev istio-injection=enabled
oc adm policy add-scc-to-group nonroot-v2 system:serviceaccounts:hello-world-dev
oc apply -f ~/NetworkAttachmentDefinition.yaml -n hello-world-dev
oc create secret docker-registry harbor-registry --docker-server=$HARBOR_URL --docker-username=$HARBOR_USER --docker-password=$HARBOR_PASS -n hello-world-dev 
oc secrets link default harbor-registry --for=pull,mount -n hello-world-dev
```
After running the above, please add the app and app-dev yamls from the argo directory

## Setup Grafana

Get the password for Grafana.  The default user is admin.

```shell
oc get secret monitoring-monitoring-grafana -n monitoring --template='{{index .data "admin-password"}}' -o go-template | base64 -d
```

1. Login and navigate to dashboards
2. Click on the blue New button and select Import
3. The Import ID is 12900