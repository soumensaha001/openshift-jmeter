oc project tools
oc adm policy add-scc-to-user anyuid system:serviceaccount:tools:nexus3

#oc get packagemanifests -n openshift-marketplace --sort-by=.metadata.name | grep nexus
#oc get packagemanifest -o jsonpath='{range .status.channels[*]}{.name}{"\n"}{end}{"\n"}' -n openshift-marketplace nexus-operator-m88i


oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: nexus-operator-m88i
  namespace: openshift-operators
spec:
  channel: "alpha"
  name: nexus-operator-m88i
  source: community-operators
  sourceNamespace: openshift-marketplace
EOF

echo "waiting for 2 minutes for the operator in the tools namespace to get ready."
sleep 120
oc apply -f nexus-instance.yaml

echo "exposing nexus, ... wait 15 seconds"
sleep 15
oc expose svc nexus3
oc get routes

echo "use get-admin-password.sh to get the initial admin password, login and change it."