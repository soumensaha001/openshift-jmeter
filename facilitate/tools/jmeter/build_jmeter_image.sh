#!/bin/bash

# alternatives are dockerhub and openshift internal registry

export OCP_USER=$(oc whoami)
export OCP_TOKEN=$(oc whoami -t)

oc adm policy add-role-to-user system:registry $OCP_USER
oc adm policy add-role-to-user system:image-builder $OCP_USER

# https://docs.openshift.com/container-platform/4.3/registry/securing-exposing-registry.html
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge

sleep 30

export HOST=$(oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}')
docker login -u $(oc whoami) -p $(oc whoami -t) $HOST

docker build -t jmeter-prevail2020 .
docker images

docker tag jmeter-prevail2020 $HOST/tools/jmeter-prevail2020
docker push $HOST/tools/jmeter-prevail2020

oc get is
# Expected result
#NAME                 IMAGE REPOSITORY                                                            TAGS     UPDATED
#jmeter-prevail2020   image-registry.openshift-image-registry.svc:5000/tools/jmeter-prevail2020   latest   About a minute ago

# as of now the tekton task can use image-registry.openshift-image-registry.svc:5000/tools/jmeter-prevail2020

# TODO:
#oc policy add-role-to-group -n tools system:image-puller system:serviceaccounts:app_project
