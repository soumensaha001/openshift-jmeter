export NEXUS=$(oc get po | grep nexus | awk '{ print $1 }')
NPW=$(oc rsh -t $NEXUS cat /nexus-data/admin.password)
#echo $NPW
echo "Login to the console and complete the setup (change the admin password: $NPW)"