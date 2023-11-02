# ocp-pipelines
Repository for build and deployment pipelines. Acmeair and petstore have been configured to be built and deployed on x86 and s390x using multi-arch manifests. The general flow for each app is approximately the same, however, they each require some extra, unique configuration steps.
The motivation of this repository is the idea that build and test clusters should not be manually modified. Therefore, OCP pipelines have been created to propogate the changes made in this cluster to the build and test clusters. Also, all of this occurs inside a disconnected environment.

![Multi-Arch build flow](./MultiArch-Flow.png)
![Image build flow](./Build-Flow.png)

## petstore
Pipelines to build and deploy the petstore app available [here](https://github.com/OpenShift-Z/petstore)
### build/build-pipeline
The files in this directory are the generic build pipeline files. Using the manager-pipeline automation on build0, these pipelines can be quickly deployed to build either s390x or x86 images.
### build/build-prime-pipeline
The pipeline in this folder manages the multi-arch builds. Once each architecture has been built, this pipeline creates a multi-arch manifest for deployment.
### deploy/deploy-pipeline
This pipeline works with the build pipelines to be able to deploy petstore. It relies on some custom resources created by the build pipeline since those resources rely on the application source. The idea is that the clusters an app is deployed on will probably be disconnected.

## acmeaircard
Pipelines to build and deploy the acmeaircard app available [here](https://github.com/OpenShift-Z/Acme-Air-3.0)

## shared-pipeline-resources
This directory contains yaml for various resources that are to be shared across multiple pipelines. This includes clusterTasks, the manager pipeline and more. See the directories README for more details.

## create-build-pipelines.sh
This bash script is used by the manager pipeline to create resources for the application build pipelines. The manager pipeline was connected to a webhook from this repository such that each new commit to the pipelines repo would automatically update all pipeline resources across all clusters. The full description of the manager pipeline can be found in `./shared-pipeline-resources/manager-pipeline-resources/manager-pipeline.yaml`.

## create-deploy-pipelines.sh
This is the equivalent of the `create-build-pipelines.sh` script except for deploy pipelines rather than build pipelines.


## Other Notes
### Adding a new application
Create a new directory in the root of this repo. The name of the directory will be the deployment namespace. Then create build and deploy pipelines and directories following the resources in `shared-pipeline-resource/template`. Once you are ready to test, push the changes to GH and make sure the build and deploy pipelines are correctly created on build0, test0 and xocp1. 

### Functional ID Access
To authenticate with other clusters a functional ID is used. The credentials for the functional ID are stored in IBM Cloud Secrets Manager, and the external secrets operator is used to get the creds into an OCP secret (functionalID-creds). 
In general, the functionalID was added as a cluster admin such that it would have permissions to start pipelines, view their outputs and complete other configuration tasks though I am sure this could be done using more strict RBAC.
