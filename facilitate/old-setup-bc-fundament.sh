#!/bin/sh

clear
echo "working on project ${BC_PROJECT}"
echo "----------------------------------------------------------------------------------------------" 
oc project ${BC_PROJECT}
oc status --suggest

echo "----------------------------------------------------------------------------------------------" 
echo "Welcome"
echo "- Typically you will want to create the project first"
echo "- After setting up the namespace you will proceed to install mysql"
echo "- Next populate the mysql database, if your cluster has dynamic storage provising then you can choose for the persistent option"
echo "- Next you install the pipeline"
echo "- Next you run the pipeline"
echo "----------------------------------------------------------------------------------------------"
echo " " 

PS3='Please enter your choice: '
options=("install tools" "delete namespace" "init namespace" "install mysql non-persistent" "install mysql persistent" "setup basic pipeline" "run pipeline" "load db" "add sonar scan to pipeline" "setup pipeline with push to ICR" "run pipeline with push to ICR" "switch branch" "install Palo Alto Prisma Cloud Compute (Twistlock)" "setup jmeter-pipeline" "run jmeter-pipeline" "add auto-scaler" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "install tools")   
            echo "installing tools"
            cd tools
            ./setup.sh
            cd ..
            break
            ;;       
        "delete namespace")
            #1 remove the namespace with all of its resources
            echo "************************ Deleting namespace ${BC_PROJECT} ******************************************"        
            oc delete project ${BC_PROJECT}
            echo "note: though the persistent volume claim is removed, the persistent volume will still have a reference to that claim (data is not lost)."
            break
            ;;
        "init namespace")

            echo "************************ Initializing namespace ${BC_PROJECT} ******************************************" 
            
            # 1
            echo "creating namespace"
            oc new-project ${BC_PROJECT} 

            # allow pull access to the jmeter image the tools namespace.
            oc policy add-role-to-group -n tools system:image-puller system:serviceaccounts:${BC_PROJECT} 

            # 2 - TODO replace image with non-priviledged user
            echo "allow the default account to run in priviledged mode (hint: not a best practice)"
            oc adm policy add-scc-to-user anyuid system:serviceaccount:${BC_PROJECT}:default

            # 3 - store access token to docker hub 
            echo "create access key to docker hub account"
            oc create secret docker-registry regcred \
            --docker-server=https://index.docker.io/v1/ \
            --docker-username=${DOCKER_USERNAME} \
            --docker-password=${DOCKER_PASSWORD} \
            --docker-email=${DOCKER_EMAIL}
            #oc get secret regcred

            # 4 - link the pipeline service account to the regcred secret to allow a push
            echo "giving the pipeline account the access keys to dockerhub"
            oc apply -f link-sa-pipeline.yaml
            #oc describe secret regcred

            # 5 - make the pipeline-account (sa) cluster-admin. 
            # - is that necessary?
            # - note: the pipeline-account does not exist yet.
            echo "go wild and make the pipeline service account CLUSTER admin (hint: not a best practice)"
            oc apply -f clusteradmin-rolebinding.yaml

            # 6 - give the default service account the access keys to the registry 
            echo " overwhelming the deployer with irrelevant information (hint: not a best practice)"
            echo " did you know that the human mind has place for about 4 facts in working memory?"
            echo " by now, some important details might have been pushed out of your working memory"
            oc secrets link default regcred --for=pull

            echo "done, please proceed to installing mysql"
            echo "NOTE: when you install mysql with persistent storage then you need a cluster that can honor persistent volume claim requests"

            break
            ;;
        "install mysql non-persistent")
            echo "************************ installing mysql in NON-PERSISTENT mode (data will be lost in various situations) ******************************************" 
            oc apply -f mysql.yaml
            echo "done, please proceed to loading mysql with data.  Give the database 30 seconds to start and get ready before loading it with data."            
            break
            ;;
        "install mysql persistent")
            echo "************************ installing mysql in PERSISTENT mode (data will not be lost as long as your persistent storage is OK) ******************************************" 
            oc apply -f mysql-persistent.yaml
            echo "done, please proceed to loading mysql with data. Give the database 30 seconds to start and get ready before loading it with data."             
            break
            ;;
        "install tekton")
            echo "installing tekton"

            # create project tekton-pipelines
            oc new-project tekton-pipelines

            # deploy various tekton artefacts into the openshift-pipelines namespace 
            oc project openshift-pipelines

            # deploy the dashboard
            # TODO: make the version configurable  
            # TODO: check the md5sum
            oc apply --filename https://github.com/tektoncd/dashboard/releases/download/v0.5.2/openshift-tekton-dashboard-release.yaml

            # increase the gateway time-out
            oc annotate route tekton-dashboard --overwrite haproxy.router.openshift.io/timeout=2m -n tekton-pipelines

            # install the tekton triggers 
            # TODO: make the version configurable  
            # TODO: check the md5sum
            oc apply --filename https://storage.googleapis.com/tekton-releases/triggers/previous/v0.2.1/release.yaml

            # install the tekton webhook extensions
            # TODO: make the version configurable  
            # TODO: check the md5sum
            curl -L https://github.com/tektoncd/dashboard/releases/download/v0.5.2/openshift-tekton-webhooks-extension-release.yaml -o openshift-tekton-webhooks-extension-release.yaml
            sed -i "s/{openshift_master_default_subdomain}/$APPS_LB/g" openshift-tekton-webhooks-extension-release.yaml
            grep $APPS_LB openshift-tekton-webhooks-extension-release.yaml
            oc apply -f  openshift-tekton-webhooks-extension-release.yaml
            rm openshift-tekton-webhooks-extension-release.yaml

            break
            ;;
        "setup basic pipeline")

            echo "re-create access key to docker hub account"
            oc delete secret regcred 
            oc create secret docker-registry regcred \
            --docker-server=https://index.docker.io/v1/ \
            --docker-username=${DOCKER_USERNAME} \
            --docker-password=${DOCKER_PASSWORD} \
            --docker-email=${DOCKER_EMAIL}
            #oc get secret regcred

            #1 setup tekton resources
            echo "************************ setup Tekton PipelineResources ******************************************"
            #echo "note: the generic pipeline should allready have been installed from the light-bc-inventory repo"

            cp ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            sed -i "s/ibmcase/${DOCKER_USERNAME}/g" ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            sed -i "s/phemankita/${GIT_USERNAME}/g" ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            #cat ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml
            oc apply -f ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            rm ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            #oc get PipelineResources
            tkn resources list

            #2 - setup tekton tasks to interact with OpenShift
            # credits: https://github.com/openshift/pipelines-tutorial/
            # licensed under Apache 2.0
            echo "************************ setup Tekton Tasks for interacting with OpenShift ******************************************"
            oc apply -f 01_apply_manifest_task.yaml
            oc apply -f 02_update_deployment_task.yaml
            oc apply -f 03_restart_deployment_task.yaml
            oc apply -f 04_build_vfs_storage.yaml
            oc apply -f 05_nodejs_sonarqube_task.yaml
            oc apply -f 06_VA_scan.yaml
            tkn task list

            #3 - setup tekton pipeline 
            echo "************************ setup Tekton Pipeline ******************************************"
            #oc apply -f pipeline.yaml
            oc apply -f pipeline-vfs.yaml
            tkn pipeline list

            break
            ;;
        "run pipeline")
            echo "************************ run Tekton Pipeline using: ******************************************"
            tkn resource list | grep web
            #echo "note: the Generic Pipeline should allready have been installed from the light-bc-inventory repo"
            #echo "note: the Pipeline Resources should allready have been installed from this repo"           
            tkn pipeline start build-and-deploy-node -r git-repo=git-source-web -r image=docker-image-web -p deployment-name=web-lightblue-deployment
            break
            ;;
        "load db")
            echo "************************ initializing database with tables and records ******************************************"
            POD=$(oc get po | grep mysql | awk '{print $1}')
            
            #oc cp mysql-data.sql $POD:/tmp/mysql-data.sql
            #oc rsh $POD ls -l /tmp/mysql-data.sql
            oc rsh $POD mysql -udbuser -pPass4dbUs3R inventorydb < mysql-data.sql
            if [ 0 -eq $? ]; then
              echo "discovered pod $POD"
              echo "database initialized succesfully"
            else
              echo "failed to initialize the database, make sure it is started and ready"
              exit 2
            fi
            break
            ;;
        "add sonar scan to pipeline")

            echo "re-create access key to docker hub account"
            oc delete secret regcred 
            oc create secret docker-registry regcred \
            --docker-server=https://index.docker.io/v1/ \
            --docker-username=${DOCKER_USERNAME} \
            --docker-password=${DOCKER_PASSWORD} \
            --docker-email=${DOCKER_EMAIL}
            #oc get secret regcred

            #1 setup tekton resources
            echo "************************ setup Tekton PipelineResources ******************************************"
            #echo "note: the generic pipeline should allready have been installed from the light-bc-inventory repo"

            cp ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            sed -i "s/ibmcase/${DOCKER_USERNAME}/g" ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            sed -i "s/phemankita/${GIT_USERNAME}/g" ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            #cat ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml
            oc apply -f ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            rm ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            #oc get PipelineResources
            tkn resources list

            oc apply -f pipeline-vfs-sonar.yaml
            tkn pipeline list

            echo "using SONARQUBE_URL=${SONARQUBE_URL}"
            oc delete configmap sonarqube-config 2>/dev/null
            oc create configmap sonarqube-config \
              --from-literal SONARQUBE_URL=${SONARQUBE_URL}
            
            oc delete secret sonarqube-access 2>/dev/null
            oc create secret generic sonarqube-access \
              --from-literal SONARQUBE_PROJECT=${SONARQUBE_PROJECT} \
              --from-literal SONARQUBE_LOGIN=${SONARQUBE_LOGIN} 

            break
            ;;            
        "setup pipeline with push to ICR")

            # Recreate access token to IBM Container Registry
            oc delete secret regcred 
            oc create secret docker-registry regcred \
            --docker-server=https://${IBM_REGISTRY_URL}/v1/ \
            --docker-username=iamapikey \
            --docker-password=${IBM_ID_APIKEY} \
            --docker-email=${IBM_ID_EMAIL}

            # Update Tekton Resources to push 
            cp ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            sed -i "s/ibmcase/${IBM_REGISTRY_NS}/g" ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            sed -i "s/index.docker.io/${IBM_REGISTRY_URL}/g" ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            sed -i "s/phemankita/${GIT_USERNAME}/g" ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            #cat ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml
            oc apply -f ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            rm ../tekton/PipelineResources/bluecompute-web-pipeline-resources.yaml.mod
            #oc get PipelineResources
            tkn resources list

            echo "************************ setup Tekton Pipeline with IBM VA scan ******************************************"
            oc apply -f pipeline-vfs-icr.yaml
            #oc apply -f pipeline-full.yaml
            tkn pipeline list
            
            oc delete secret ibmcloud-apikey 2>/dev/null
            oc create secret generic ibmcloud-apikey --from-literal APIKEY=${IBM_ID_APIKEY}

            oc delete configmap ibmcloud-config 2>/dev/null
            oc create configmap ibmcloud-config \
             --from-literal RESOURCE_GROUP=default \
             --from-literal REGION=eu-de

            break
            ;;            
        "run pipeline with push to ICR")
            
            tkn pipeline start build-and-deploy-node \
                -r git-repo=git-source-web \
                -r image=docker-image-web \
                -p deployment-name=web-lightblue-deployment \
                -p image-url-name=${IBM_REGISTRY_URL}/${IBM_REGISTRY_NS}/lightbluecompute-web:latest \
                -p scan-image-name=true

            break
            ;;            
        "switch branch")
            echo "switching branch"
            ./mod_branch.sh
            break
            ;;
        "install Palo Alto Prisma Cloud Compute (Twistlock)")
            echo "installing Palo Alto Prisma Cloud Compute (Twistlock)"
            cd tools/twistlock
            #pwd
            bash ./twist-params2.sh
            cd -           
            #pwd
            break
            ;;
        "setup jmeter-pipeline")
            echo "setup jmeter-pipeline"

            oc apply -f 07_jmeter_task.yaml 

            cp pipeline-jmeter.yaml pipeline-jmeter.yaml.mod
            sed -i "s/kitty-catt/${GIT_USERNAME}/g" pipeline-jmeter.yaml.mod
            oc apply -f pipeline-jmeter.yaml.mod
            rm pipeline-jmeter.yaml.mod

            break
            ;;    
        "run jmeter-pipeline")
            echo "run jmeter-pipeline"
            tkn pipeline start jmeter-pipeline
            break
            ;;     
         "add auto-scaler")
            echo "adding horizontal pod autoscaling for the web-ui"
            oc autoscale deployment web-lightblue-deployment --cpu-percent=10 --min=1 --max=3
            #oc set resources dc web-lightblue-deployment --requests=cpu=50m
            #oc autoscale deploymentconfig web-lightblue-deployment --cpu-percent=10 --min=1 --max=3
            
            oc get hpa
            break
            ;;                                         
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done
cat prevail-2020.txt
