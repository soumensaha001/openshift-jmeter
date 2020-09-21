oc new-project tools

# Setup nexus3
#cd nexus3
#./install_nexus3.sh
#cd ..

# Setup Openshift pipelines
cd pipelines
./install_pipelines.sh
cd ..

# Setup sonarqube

cd sonarqube
./install_sonarqube.sh
cd ..

cd jmeter
bash ./install_jmeter_framework.sh
bash ./build_jmeter_image.sh
cd ..

# TODO: setup Openshift service mesh
