#!/bin/bash

# Google Cloud SDK is installed on the Virtual Machine to run this script
# Virtual Machine is authenticated to access GCS

set -e

sudo dnf install -y dnf-utils #deprecated in RHEL9

# Download Packages 
curl -o wget.rpm https://<path>/wget-1.21.1-8.el9.x86_64.rpm
curl -o qualys.rpm https://<path>/QualysCloudAgent7.1.0.37.rpm
curl -o sentinelone.rpm https://<path>/SentinelAgent_linux_x86_64_v24_3_3_6.rpm
curl -o unzip.rpm https://<path>/unzip-6.0-58.el9.x86_64.rpm
sudo yum install -y ./wget.rpm

wget -O Dynatrace-OneAgent-Linux-x86-1.313.52.20250602-150703.sh "https://flu19434.live.dynatrace.com/api/v1/deployment/installer/agent/unix/default/latest?arch=x86" --header="Authorization: Api-Token ${DYNATRACE_REG_TOKEN}"

sudo bash Dynatrace-OneAgent-Linux-x86-1.313.52.20250602-150703.sh

sudo systemctl stop oneagent

cat <<EOF | sudo tee /etc/systemd/system/dynatrace-hostname-reset.service
[Unit]
Description=Reset Dynatrace OneAgent Hostname
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/opt/dynatrace/oneagent/agent/tools/oneagentctl --set-host-name="" --restart-service
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable dynatrace-hostname-reset.service
# Set variables
BUCKET_NAME="bkt-goldenimage"
PACKAGE_PATH="POC.zip"
LOCAL_DIR="/tmp/packages"

# Create local directory
mkdir -p $LOCAL_DIR

# Download packages from GCS
gsutil cp gs://$BUCKET_NAME/$PACKAGE_PATH $LOCAL_DIR/ || {
  echo "Error downloading from GCS";
  exit 1;
}

sudo yum install -y ./unzip.rpm

# install the Qualys Agent
echo "Installing Qualys Agent"
sudo yum install -y ./qualys.rpm || {
  echo "Error installing Qualys Agent"
  exit 1;
}

# configure agent with Activation ID and Customer ID
echo "Configuring Qualys Agent"
timeout 60 sudo /usr/local/qualys/cloud-agent/bin/qualys-cloud-agent.sh ActivationId="${QUALYS_AGENT_ACTIVATION_ID}" CustomerId="${QUALYS_AGENT_CUSTOMER_ID}" ServerUri="${QUALYS_AGENT_SERVER_URI}" || {
  echo "Error configuring Qualys Agent"
  exit 1;
}

# install SentinelOne agent
echo "Installing SentinelOne Agent"
sudo rpm -ivh --nodigest --nofiledigest sentinelone.rpm || {
  echo "Error installing Sentinelone Agent"
  exit 1;
}

# set token and activate Agent
echo "Activating SentinelOne Agent"
sudo /opt/sentinelone/bin/sentinelctl management token set "${SENTINELONE_AGENT_TOKEN}"
sudo /opt/sentinelone/bin/sentinelctl control start

# Unzip the packages
unzip $LOCAL_DIR/POC.zip -d $LOCAL_DIR/ || {
  echo "Error unzipping $LOCAL_DIR/POC.zip";
  exit 1;
}

# Change to the directory
cd $LOCAL_DIR/POC || {
  echo "Error changing directory to $LOCAL_DIR/POC";
  exit 1;
}
# Move the certificates to the appropriate directory
sudo cp Root_CA.cer /etc/pki/ca-trust/source/anchors/
sudo cp CA.cer /etc/pki/ca-trust/source/anchors/
sudo cp Root_Certificate.cer /etc/pki/ca-trust/source/anchors/
sudo cp Issuing_Certificate.cer /etc/pki/ca-trust/source/anchors/

# Update the Certificates
sudo update-ca-trust || {
  echo "Error updating certificates trust"
  exit 1;
}

#install Ops Agent
echo "Installing Ops Agent"
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
sudo bash add-google-cloud-ops-agent-repo.sh --also-install

# install kshell ruby bind-utils 
sudo dnf install -y ksh ruby bind-utils

#install Kerberos packages
sudo dnf install -y krb5-workstation krb5-libs sssd-proxy

# Cribl - install & set path
sudo dnf install -y rsyslog

echo " - '# siem'" | sudo tee -a /etc/rsyslog.conf
echo " - 'auth.info;authpriv.info;daemon.info;kern.info  @<url_path>:9516'" | sudo tee -a /etc/rsyslog.conf
echo " - 'user.info;*.emerg;local4.info;local7.info      @<url_path>:9516'" | sudo tee -a /etc/rsyslog.conf

cat /etc/rsyslog.conf

# Enable Kerberos Authentiaction
sudo authselect select sssd --force

# after reboot remove old kernel packages
sudo dnf install -y dnf-plugins-core
which package-cleanup

# remove old kernel packages
sudo dnf list installed kernel*
sudo dnf remove --oldinstallonly --setopt installonly_limit=2 kernel -y
echo "Finished cleanup old kernerls"
sudo dnf list installed kernel* 

# Clean up
cd $LOCAL_DIR
if [ -f "POC.zip" ]; then
  rm -rf POC.zip || {
    echo "Warning: Failed to remove POC.zip";
  }
else
  echo "POC.zip not found, skipping removal"
fi

echo "Packages installation completed successfully!"
