#!/bin/bash

deployClusterName=$1

# get the names of all directories
dirs=$(ls -d */ | grep -v "shared-pipeline-resources")

#log into the other cluster
# export KUBECONFIG=/workspace/kubeconfig-dir/kubeconfig
startDir=$(pwd)

# for each app
for i in $dirs
do
    projName=${i%/*}
    cd $i

    if ! oc get project $projName > /dev/null ; then
        #the project does not exist so it will need to be created
        # but we won't be able to switch to the new project bc kubeconfig read only
        oc new-project $projName 2> /dev/null || true
        if ! oc get project $projName > /dev/null ; then
            echo "Could not create project $projName"
            exit 1
        fi

        #thought about creating pull secret here but theoretically cluster pull
        # secret should allow for pull from intreg0

    fi

    # create pipeline triggerbinding, eventlistener and triggertemplate, pipeline and all tasks
    if [ -d ./deploy/deploy-pipeline ] ; then
        cd deploy/deploy-pipeline

        find . -name "*.yaml" | xargs sed -i.bak \
            -e "s/<deploy-cluster-name>/$deployClusterName/g"

        oc apply -f . --namespace $projName

        find . -name "*.yaml" | xargs sed -i.bak \
            -e "s/$deployClusterName/<deploy-cluster-name>/g"

        find . -name "*.bak" | xargs rm  
    fi

    cd $startDir
done