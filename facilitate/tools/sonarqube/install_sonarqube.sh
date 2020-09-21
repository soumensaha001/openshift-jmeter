mkdir -pv ~/bin
curl -k https://mirror.openshift.com/pub/openshift-v4/clients/helm/latest/helm-linux-amd64 -o ~/bin/helm
chmod 755 ~/bin/helm

# CHECKPOINT
~/bin/helm version

kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

#helm init
#kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

~/bin/helm repo add oteemo https://oteemo.github.io/charts/
~/bin/helm repo update

# CHECKPOINT:

~/bin/helm repo list

# CHECKPOINT
#NAME  	URL                                             
#oteemo	https://oteemo.github.io/charts/   

# install sonar qube in the existing tools namespace
oc project tools
oc create serviceaccount sonarqube -n tools
oc adm policy add-scc-to-user anyuid system:serviceaccount:tools:default
oc adm policy add-scc-to-user privileged system:serviceaccount:tools:default
oc adm policy add-scc-to-user privileged system:serviceaccount:tools:sonarqube

# Run the following command on DTE console to install sonarqube
~/bin/helm install sonarqube oteemo/sonarqube --version 6.6.0

sleep 20
oc patch deployment/sonarqube-sonarqube --patch '{"spec":{"template":{"spec":{"serviceAccountName": "sonarqube"}}}}'

oc get svc
# CHECKPOINT
#NAME                            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
#sonarqube-postgresql            ClusterIP   172.21.112.77   <none>        5432/TCP   9s
#sonarqube-postgresql-headless   ClusterIP   None            <none>        5432/TCP   9s
#sonarqube-sonarqube             ClusterIP   172.21.32.226   <none>        9000/TCP   9s

oc expose svc sonarqube-sonarqube

echo "External access"
oc get routes

echo "The internal SONARQUBE_URL in boot.sh should look like:" 
export SONARQUBE_URL='http://sonarqube-sonarqube.tools.svc.cluster.local:9000'


