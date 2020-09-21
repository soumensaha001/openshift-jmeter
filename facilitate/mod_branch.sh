clear

echo "Current GIT PipelineResource Configuration"
echo "-------------------------------------------------------------------"
oc get PipelineResource git-source-web -o yaml
echo ""

echo "available branches"
echo "-------------------------------------------------------------------"
git branch -av

read -p "Enter the branch (e.g. V5) : " name
echo "Switching to $name."
sleep 1

clear
#set -x
#oc patch pipelineresource git-source-web --type=json -p '[{"op":"replace","path":"/spec/params/0/value","value":V5}]'
PATCH="[{\"op\":\"replace\",\"path\":\"/spec/params/0/value\",\"value\":$name}]"
#echo $PATCH
oc patch pipelineresource git-source-web --type=json -p $PATCH

echo "New GIT PipelineResource Configuration"
echo "-------------------------------------------------------------------"
oc get PipelineResource git-source-web -o yaml
echo ""
