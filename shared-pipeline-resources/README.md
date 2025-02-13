# shared-pipeline-resources
This directory is a catch-all for random pipeline resources that may be used across pipelines.

## Sub-dirctories
### clustertask-yamls
This dir contains my custom clustertasks as well as a README that will explain what they do and give some insight into my thought process.
### manager-pipeline-resources
This dir contains the web hook and yaml for my manager pipeline. The manager pipeline is used to automatically update pipeline resources from this repository onto my OpenShift clusters.
### template-for-new-app-pipelines
This dir contains a bunch of template files for setting up an OCP pipeline for building or deploying an application. The templates to configure triggers from GitHub webhooks are also provided.

## Files
### image-pull-secret.yaml
This file is a template for an image pull secret. There is nothing too special here.
### github-pull-secret.yaml
This file is a template for creating a secret used by the pipelines to pull a repo from GitHub using a personal access token for authentication. Normally, a [GitHub Deploy Key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys#deploy-keys) would be the recommended auth method but these pipelines were designed to run behind an HTTPS proxy. There is a method for HTTPS forwarding of Deploy Keys but it was not supported by GHE at the time this project was created. 
