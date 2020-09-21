# Docker Hub Section
export DOCKER_USERNAME='your docker-hub user here'
export DOCKER_PASSWORD='your docker-hub password here'
export DOCKER_EMAIL='your email here'

# GIT Section
export GIT_USERNAME='your git user here'

# SonarQube Server Section
# Login to SonarQube Server, make a project and generate a token for it.
export SONARQUBE_URL='http://sonarqube-sonarqube.tools.svc.cluster.local:9000'
export SONARQUBE_PROJECT='<project here>'
export SONARQUBE_LOGIN='<login here>'

# The OpenShift Target Namespace / Project
export BC_PROJECT="bc-light"

# ICR with VA Scan
export IBM_ID_APIKEY='<api key here>'
export IBM_ID_EMAIL='<ibm id here>'
export IBM_REGISTRY_URL='de.icr.io'
export IBM_REGISTRY_NS='<namespace here>'


./old-setup-bc-fundament.sh
