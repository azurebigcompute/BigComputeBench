#!/bin/bash -x
###############################################################################
# Azure Extension Script:
# Install essential tools for Azure Big Compute / Azure Batch
#
# Tested On: Ubuntu 16.04 && 17.10
#
###############################################################################
if [[ $(id -u) -ne 0 ]] ; then
    echo "Must be run as root"
    exit 1
fi

ADMIN=$1
# Linux distro detection remains a can of worms, just pass it in here:
VMIMAGE=$2
# Or uncomment one of these if running this script by hand. 
#VMIMAGE="microsoft-ads:linux-data-science-vm-ubuntu:1.1.2"
#VMIMAGE="Canonical:UbuntuServer:16.04-LTS"
#VMIMAGE="Canonical:UbuntuServer:17.10"

PUBLISHER=`echo $VMIMAGE| awk -F ":" '{print $1}'`
OFFER=`echo $VMIMAGE| awk -F ":" '{print $2}'`
SKU=`echo $VMIMAGE| awk -F ":" '{print $3}'`
OSVERS=`echo $VMIMAGE| awk -F ":" '{print $4}'`

echo "##############################################################################"
echo "Extension $0: $ADMIN, $VMIMAGE"

export DEBIAN_FRONTEND=noninteractive
echo "* hard memlock unlimited" >> /etc/security/limits.conf
echo "* soft memlock unlimited" >> /etc/security/limits.conf
apt-get -y update
#apt-get -y upgrade

# Install dev & sysadmin tools
apt-get install -y build-essential g++ git gcc make cmake htop iotop autotools-dev libicu-dev libbz2-dev libboost-all-dev libssl-dev libffi-dev libpython-dev python-dev python-pip python3-pip zip squashfs-tools
pip3 install --upgrade pip
pip3 install wheel
apt-get install -y redis-tools
echo "# devtools ###################################################################"

# Install azure-cli
# https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
if [[ $PUBLISHER == "Canonical" && $OFFER == "UbuntuServer" && $SKU == "16.04-LTS" ]]; then
	echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli xenial main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
elif [[ $PUBLISHER == "Canonical" && $OFFER == "UbuntuServer" && $SKU == "17.10" ]]; then
	echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli artful main" | sudo tee /etc/apt/sources.list.d/azure-cli.list
fi

apt-key adv --keyserver packages.microsoft.com --recv-keys 417A0893
apt-get install -y apt-transport-https
apt-get -y update && apt-get install -y azure-cli
# Configure azure cli
# https://docs.microsoft.com/en-us/cli/azure/format-output-azure-cli?view=azure-cli-latest
mkdir /home/$ADMIN/.azure
cat <<'EOF' >> /home/$ADMIN/.azure/config
[cloud]
name = AzureCloud

[core]
first_run = yes
output = table
collect_telemetry = yes

[logging]
enable_log_file = yes
EOF
chown $ADMIN /home/$ADMIN/.azure
echo "# azurecli ###################################################################"
#
# Install azure batch cli extensions & examples
# https://github.com/Azure/azure-batch-cli-extensions
#/opt/az/bin/python3 -m pip install azure-cli-batch-extensions
pip install azure-batch-extensions
su - $ADMIN -c 'git clone https://github.com/Azure/azure-batch-cli-extensions.git /home/azureuser/azure-batch-cli-extensions'
echo "#cli extensions###############################################################"

# Install DOTNET & azcopy
# https://www.microsoft.com/net/core#linuxubuntu
# https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy-linux
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
mv microsoft.gpg /etc/apt/trusted.gpg.d/microsoft.gpg

if [[ $PUBLISHER == "Canonical" && $OFFER == "UbuntuServer" && $SKU == "16.04-LTS" ]]; then
echo $SKU
echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-xenial-prod xenial main" > /etc/apt/sources.list.d/dotnetdev.list
elif [[ $PUBLISHER == "Canonical" && $OFFER == "UbuntuServer" && $SKU == "17.10" ]]; then
echo $SKU
echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-artful-prod artful main" > /etc/apt/sources.list.d/dotnetdev.list
fi
sudo apt-get update
apt-get install -y dotnet-sdk-2.1.4
dotnet --version
echo "# dotnet ######################################################################"

wget -O azcopy.tar.gz https://aka.ms/downloadazcopyprlinux
tar -xvf azcopy.tar.gz
./install.sh
echo "# azcopy #####################################################################"

# Install Docker
# https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#install-using-the-repository
apt-get install -y linux-image-extra-$(uname -r) linux-image-extra-virtual
apt-get install -y apt-transport-https ca-certificates software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository -y "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
apt-get install -y docker-ce
echo "# docker #####################################################################"

# Install Batch Shipyard - Ensure you are NOT root for this section
# https://github.com/Azure/batch-shipyard/blob/master/docs/01-batch-shipyard-installation.md
# credit to Karl Podesta for this little hack:
su - $ADMIN -c 'SYVERSION="3.1.0";\
wget https://github.com/Azure/batch-shipyard/archive/$SYVERSION.tar.gz;\
tar -xvf $SYVERSION.tar.gz; \
cd batch-shipyard-$SYVERSION;\
SHIPYARD=`pwd`;\
./install.sh -3;\
echo "export PATH=$PATH:$HOME/.local/bin:$SHIPYARD" >> ~/.bashrc
'
echo "# shipyard ###################################################################"

# Install Singularity - Courtesy of Ben Hummerstone
# https://github.com/Azure/azure-quickstart-templates/tree/master/centos-singularity
SIVERSION=2.4.2
wget https://github.com/singularityware/singularity/releases/download/$SIVERSION/singularity-$SIVERSION.tar.gz
tar xvf singularity-$SIVERSION.tar.gz
cd singularity-$SIVERSION
./configure --prefix=/usr/local
make
make install
echo "# singularity ###################################################################"


setup azcli_centos()
{
	rpm --import https://packages.microsoft.com/keys/microsoft.asc
	sh -c 'echo -e "[azure-cli]\nname=Azure CLI\nbaseurl=https://packages.microsoft.com/yumrepos/azure-cli\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/azure-cli.repo'
	yum check-update
	yum install azure-cli

} #-- end of setup_azcli_centos() --#
