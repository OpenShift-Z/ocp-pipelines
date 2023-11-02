# clustetask-yamls
The custom clustertasks I wrote for creating disconnected, multi-arch builds with OpenShift. [This paper](https://ibm.biz/BdyaPz) has more description of motivation, issues, etc.

## assemble-manifest-task.yaml
This clustertask assembles a list of images into a single "fat" manifest using `buildah`.
#### Parameters:
- `manifest-name` --> this is the desired name for the final "fat" manifest including tag. Once assembled the manifest will be pushed here so make sure this includes your destination image registry. (Ex: imageReg1.your.hostname.here.com:5000/petstore/multiArchPetstore:v1)
- `image-name` --> the name of the images that are to be assembled into the manifest. For this task, all images should have the same name and only their tags should vary. (Ex: imageReg1.your.hostname.here.com:5000/petstore/singleArchPetstore)
- `tags` --> a comma separated list of tags that should be assembled into the manifest. The task will concatenate these tags to the end of the `image-name` parameter. (Ex: x86-V1,s390x-V1)

Using my examples this task would assemble `imageReg1.your.hostname.here.com:5000/petstore/singleArchPetstore:x86-V1` and `imageReg1.your.hostname.here.com:5000/petstore/singleArchPetstore:s390x-V1` into a single manifest `imageReg1.your.hostname.here.com:5000/petstore/multiArchPetstore:v1` and push the resulting manifest to `imageReg1.your.hostname.here.com:5000`. Image cosumers on the x86 or s390x architectures could then both consume the image by pulling from `imageReg1.your.hostname.here.com:5000/petstore/multiArchPetstore:v1` 
#### Workspaces
- `src-pull-secret` --> pass a secret of type `kubernetes.io/dockerconfigjson` that contains the authentication required to pull from the image registry referenced in the `image-name` parameter.
- `dest-pull-secret` --> pass a secret of type `kubernetes.io/dockerconfigjson` that contains the authentication required to push to the image registry referenced in the `manifest-name` parameter.

## sign-into-cluster-task.yaml
This clustertask uses credentials provided to authenticate with a remote cluster. Once authentication occurs, a `kubeconfig` is created for use by subsequent tasks in a pipeline. This was designed to use LDAP credentials to authenticate as a functional ID (I.E., using a user inside LDAP that is not connected to a person on the team and is only used as an ID during automated authenntication). This task uses basic user/password authentication and was only tested with LDAP. It may be suitable for other auth methods but that depends on your cluster configuration.
This task uses the same image as the `openshift-cli` clustertask since this seemed like the easiest way to get the OpenShift CLI.
#### Parameters
- `clusterURL` --> the URL of the cluster the task should authenticate with. This can be gotten by running `oc whoami --show-console |sed -E 's/.*?apps.//'`.

#### Workspaces
- `kubeconfig` --> A small PVC where the resulting kubeconfig file will be placed. The kubeconfig will be placed in the root of the PVC. It must only be large enough for one small file so don't go overboard
- `creds` --> A secret that contains the credentials to be used for the login. I had the values stored in [IBM Cloud Secrets Manager](https://www.ibm.com/products/secrets-manager) and the secret managed by the [External Secrets Operator](https://external-secrets.io/latest/) as described in [this paper](https://ibm.biz/BdMtKx). 
    Sample `creds` secret yaml:
    ```
    apiVersion: v1
    data:
      password: <base-64-encoded-passwd>
      username: <base-64-encoded-username>
    immutable: false
    kind: Secret
    metadata:
      name: ocp-user-creds
    type: Opaque
    ```

## make-sub-from-secret
This clustertask was designed to take data from a secret (in this case the secret was managed by External Secrets Operator) and place credential data into files. For example, inserting a database username and password into both an applications FEPCluster yaml, a DB configuration script and a java application's `jdbc.properties`. This means that filler data could be stored in GitHub without exposing the credentials. Additionally, credentials could be changed once in the secret manager, rather than across multiple files. Finally, the credentials could change as an app moves from test to production.
I used the `ubi8/ubi-minimal` since it seemed to be the smallest image available that had BASH and sed which were really all I needed. Also, I did neeed to set the securityContext to `runAsUser: 65532` based on the permissions of the files in the `files` workspace.
#### Parameters
- `fileName` --> comma separated list of file paths where the replacement should be made. (Ex: `manifests/create-fepcluster.yaml,jpetstore/war/WEB-INF/jdbc.properties,jpetstore/db/postgres/configure_db.sh` see the [petstore repo](https://github.com/OpenShift-Z/petstore/tree/main/jpetstore) for more info/to view these files.)
- `oldText` --> the filler text to be replaced. (Ex: I used `<db-password>`)
- `secretKey` --> the key inside the OpenShift secret where the credential information is stored. (Ex: `pgpassword`, see the `secretData` workspace section below for a template)

#### Workspaces
- `files` --> this PVC contains the files to be edited. In my case, this was the PVC I had previously `git cloned` all of my application files to.
- `secretData` --> an OpenShift secret that contains the data to be substituted into the files.
    Sample yaml:
    ```
    apiVersion: v1
    data:
      pgpassword: <base64-encoded-database-password>
      pguser: <base64-encode-database-username>
    immutable: false
    kind: Secret
    metadata:
      name: petstoredb-creds
    type: Opaque
    ```
