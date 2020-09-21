#! /bin/bash -x
#
# this script will install Twistlock defender into a local OpenShift cluster, connect to a remote Twistlock console, create a collection for the cluster hosts, 
# create a user for a participant with Auditor rights and restrict that user to the collection.
#
# create twistlock namespace
oc new-project twistlock
#
# install Twistlock Defender into local cluster
oc create -f daemonset-remote-ocp.yaml -n twistlock
#
# Get participants name
read -p "Please enter your name: " name
#
# Getting the node hostnames
nodes=$(oc get nodes -o jsonpath="{.items[*].spec.providerID}")
hostnames=()
for node in $nodes
do
	hostnames+=($(echo $node | cut -d '/' -f 7)".iks.ibm")
done
#
# Create a collection
collection_name="${name}-collection"
collection_request="{ \
 \"name\": \"$collection_name\", \
 \"description\": \"Collection of $name\", \
 \"hosts\": [ \
   \"${hostnames[0]}\", \
   \"${hostnames[1]}\" \
 ], \
 \"images\":[\"*\"], \
 \"labels\":[\"*\"], \
 \"containers\":[\"*\"], \
 \"services\":[\"*\"], \
 \"functions\":[\"*\"], \
 \"namespaces\":[\"*\"], \
 \"appIDs\":[\"*\"], \
 \"accountIDs\":[\"*\"], \
 \"color\":\"\" \
}"
echo $collection_request
curl -v -k -H 'Authorization: Basic YWRtaW46VHdpc3RhZG1pbjQz' -H 'Content-Type: application/json' -X POST --data "$collection_request" https://twistlock-console-twistlock.dte-ocp4-irn8k0-915b3b336cabec458a7c7ec2aa7c625f-0000.us-south.containers.appdomain.cloud/api/v1/collections
#
# Create User
user_request="{ \
  \"username\": \"$name\", \
  \"password\": \"myPassw0rd\", \
  \"role\": \"auditor\", \
  \"authType\": \"basic\", \
  \"permissions\": [ \
    { \
      \"project\": \"Central Console\",
      \"collections\": [ \
        \"$collection_name\" \
      ] \
    } \
  ] \
}"
echo $user_request
curl -v -k -H 'Authorization: Basic YWRtaW46VHdpc3RhZG1pbjQz' -H 'Content-Type: application/json' -X POST --data "$user_request" https://twistlock-console-twistlock.dte-ocp4-irn8k0-915b3b336cabec458a7c7ec2aa7c625f-0000.us-south.containers.appdomain.cloud/api/v1/users
#
# point user to Twistlock console
echo "Now point your browser at https://twistlock-console-twistlock.dte-ocp4-irn8k0-915b3b336cabec458a7c7ec2aa7c625f-0000.us-south.containers.appdomain.cloud/#!/login and login."
#