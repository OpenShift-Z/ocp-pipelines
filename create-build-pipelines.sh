#!/bin/bash
set -ex

buildClusterName=$1
deployClusterName=$2

# get the names of all directories
dirs=$(ls -d */ | grep -v "shared-pipeline-resources")

startDir=$(pwd)

# create all the resources specified in the build directory for each app
for i in $dirs
do
    projName=${i%/*}
    cd $i

    newProject=false

    if ! oc get project $projName > /dev/null ; then
        #the project does not exist so it will need to be created
        # but we won't be able to switch to the new project bc kubeconfig read only
        oc new-project $projName || true
        if ! oc get project $projName > /dev/null ; then
            echo "Could not create project $projName"
            exit 1
        fi

        #use tekton to automatically clean up old pipelineruns after 2 days
        oc patch namespace $projName -p \
         '{"metadata": {"annotations": {"operator.tekton.dev/prune.resources": "taskrun, pipelinerun", "operator.tekton.dev/prune.keep-since": "2880"}}}'

        #Should probably just use ESO to add these secrets to each new project
	#create GH pull secret and link to the pipeline SA
        oc create secret generic sa-pull-secret --from-literal=username=<username> \
            --from-literal=password=<password> \
            --type=kubernetes.io/basic-auth --namespace $projName \
            && oc secrets link pipeline sa-pull-secret --namespace $projName \
            && oc patch secret sa-pull-secret -p '{"metadata": {"annotations": {"tekton.dev/git-0": "https://github.com"}}}' --namespace $projName

        #create the secret for pushing to intreg0, should eventually make more modular to use for any reg
        oc get secret/pull-secret -n openshift-config --template='{{index .data ".dockerconfigjson" | base64decode}}'> ./pullsecret.json
        oc create secret docker-registry intreg0 --namespace $projName \
            --from-file=config.json=./pullsecret.json \
            --from-file=.dockerconfigjson=./pullsecret.json \
            && oc secrets link pipeline intreg0 -n $projName

        newProject=true
    fi


    if [ -d ./build/build-pipeline ] ; then
        cd build/build-pipeline
        

        if echo $buildClusterName | grep -i "xocp1" ; then
            arch=x86
        else
            arch=s390x
        fi

        find . -name "*.yaml" | xargs sed -i.bak \
            -e "s/<build-cluster-name>/$buildClusterName/g" \
            -e "s/<deploy-cluster-name>/$deployClusterName/g" \
            -e "s/<arch>/$arch/g"

        oc apply -f . --namespace $projName

        find . -name "*.yaml" | xargs sed -i.bak \
            -e "s/$buildClusterName/<build-cluster-name>/g" \
            -e "s/$deployClusterName/<deploy-cluster-name>/g" \
            -e "s/$arch/<arch>/g"

        find . -name "*.bak" | xargs rm  

    fi

    if echo "$buildClusterName" | grep "build0" ; then
        
        # Create the prime pipeline but only on build0
        if [ -d $startDir/$projName/build/build-prime-pipeline ] ; then
            oc apply -f $startDir/$projName/build/build-prime-pipeline --namespace $projName
        fi
        
        # only add the new webhook when new project on build0 that way only one webhook is created
        if $newProject ; then
            #try to automatically add the webhook to GH repo from here?
            echo "new project: $projName"

            token=$(oc get secret sa-pull-secret --namespace $projName -o go-template='{{index .data "password"}}' | base64 -d)
            
            # use the same route host for all projects, then set the path for a given project name
            # this relies on the nginx proxy running on fpet
            ELRoute="reverseProxy.your.hostname.com:56852/$projName"

            #need to create some sort of map for project name to repo name
            repoURL=$(cat $projName.info | grep "repo_url:" | awk '{print $2}' | sed -e 's/.*\///' -e 's/.git//')
            repoName=${repoURL##*/}

            #this is supposed to add the webhook to GH, but the functional ID will need admin access to each project
            # for this to be successful
            
            # curl -L \
            # -X POST \
            # -H "Accept: application/vnd.github+json" \
            # -H "Authorization: Bearer $token"\
            # -H "X-GitHub-Api-Version: 2022-11-28" \
            # https://api.github.com/repos/$orgName/$repoName/hooks \
            # -d '{"name":"web","active":true,"events":["push","pull_request","releases"],"config":{"url":"http://'$ELRoute'","content_type":"json","insecure_ssl":"1"}}'
        fi
    fi

    cd $startDir
done
