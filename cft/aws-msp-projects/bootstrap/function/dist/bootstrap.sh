#############################################################################################################
#Linux Bootstrap script to install puppet/ssm/trendMicro agent and register the instance to AWS SSM/Trend
#Last updated by Eric Ho (eric.ho@datacom.com.au) on August 24, 2018
#Below variables are ingested by bootstrap API
#ssmUrl="ssm.demo.hcs.datacom.com.au"
#trendUrl="trend.demo.hcs.datacom.com.au"
#enfore="false"
#############################################################################################################

puppetRepoPkg="";
os="";
ssmAgentPkg="https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm";

if [[ $(/usr/bin/id -u) -ne 0 ]]; then echo You are not running as the root user.  Please try again with root privileges.;
    logger -t You are not running as the root user.  Please try again with root privileges.;
    exit 1;
fi;
 
if !(type lsb_release &>/dev/null); then
    distribution=$(cat /etc/*-release | grep '^NAME' );
    release=$(cat /etc/*-release | grep '^VERSION_ID');
else
    distribution=$(lsb_release -i | grep 'ID');
    release=$(lsb_release -r | grep 'Release');
fi;

if [ -z "$distribution" ]; then
    distribution=$(cat /etc/*-release);
    release=$(cat /etc/*-release);
fi;
releaseVersion=${release//[!0-9.]};

case $distribution in
    *"Amazon"*)
        platform='amzn';
        #if [[ $(uname -r) == *"amzn2"* ]]; then
        #  os="amazon-linux2"
        #  puppetRepoPkg="https://yum.puppet.com/puppet5/puppet5-release-el-6.noarch.rpm";
        #elif [[ $(uname -r) == *"amzn1"* ]]; then
        if [[ $(uname -r) == *"amzn1"* ]]; then
            os="amazon-linux1"
	    puppetRepoPkg="https://yum.puppet.com/puppet5/puppet5-release-el-6.noarch.rpm";
        fi;
        ;;

     *"RedHat"* | *"Red Hat"*)
        platform='RedHat_EL';
        #if [[ $releaseVersion =~ ^6.* ]]; then
	#   puppetRepoPkg="https://yum.puppet.com/puppet5/puppet5-release-el-6.noarch.rpm";
        #elif [[ $releaseVersion =~ ^7.* ]]; then
	if [[ $releaseVersion =~ ^7.* ]]; then
            os="rhel-7"
	    puppetRepoPkg="https://yum.puppet.com/puppet5/puppet5-release-el-7.noarch.rpm";
        fi;
        ;;
esac

if [[ -z "${puppetRepoPkg}" ]]; then
    echo Unsupported platform is detected
    logger -t Unsupported platform is detected
    false
    exit 1
fi


############################################# Puppet Agent Installation ####################################
sudo rpm -Uvh $puppetRepoPkg
sudo yum -y install puppet-agent

############################################# SSM Agent Installation ########################################
#activation='{"ActivationId":"3fc337c1-89cf-4fa7-9307-4c483658f1b0","ActivationCode":"+aMicniKu3GYegdiSq7I"}'
instanceId=$(curl http://169.254.169.254/latest/meta-data/instance-id --silent)
activation=$(curl "https://${ssmUrl}/latest/activate?instanceName=${instanceId}")
activationId=$(echo $activation|sed s/\"//g| sed s/[{}]//g | awk -F, '{ print $1}'|awk -F: '{ print $2 }')
activationCode=$(echo $activation|sed s/\"//g| sed s/[{}]//g | awk -F, '{ print $2}'|awk -F: '{ print $2 }')

#https://aws.amazon.com/premiumsupport/knowledge-center/install-ssm-agent-ec2-linux/
if [[ $platform == 'RedHat_EL' ]]; then
    systemctrl='sudo systemctl'
else 
    systemctrl='sudo'
fi

$systemctrl stop amazon-ssm-agent
sudo yum install -y $ssmAgentPkg
sudo amazon-ssm-agent -register -code ${activationCode} -id ${activationId} -region "ap-southeast-2"
$systemctrl start amazon-ssm-agent

# Retrieve SSM Instance ID
if [[ $platform == 'RedHat_EL' ]]; then
    #$systemctl status amazon-ssm-agent -l |grep instanceID=mi | head -1 | awk '{ print $9}'
    managedInstanceId=$(systemctl status amazon-ssm-agent -l \
        |grep instanceID=mi \
        | head -1 \
        | awk '{ print $9}' \
        | awk -F= '{ print $2 }' \
        | sed s/\]// )
else 
    managedInstanceId=$(sed s/\"//g /var/lib/amazon/ssm/registration \
        |awk -F, '{ print $1 }' \
        |awk -F: '{ print $2 }')
fi

if [[ $enforce == "true" ]]; then
    body="{\"managedInstanceId\":\"${managedInstanceId}\", \"os\":\"${os}-enforce\"}"
else 
    body="{\"managedInstanceId\":\"${managedInstanceId}\", \"os\":\"${os}\"}"
fi

#Restart SSM Agent to make instance online in SSM 
$systemctl restart amazon-ssm-agent

#Apply SSM tag to management instance 
curl --header "Content-Type: application/json" --request POST --data "$body" https://${ssmUrl}/latest/tag

# Download Trend Installation script and Install Trend
if type curl >/dev/null 2>&1; then
    SOURCEURL="https://${trendUrl}:443"
    curl $SOURCEURL/software/deploymentscript/platform/linux/ \
	-o /tmp/DownloadInstallAgentPackage \
	--insecure --silent --tlsv1.2

    if [ -s /tmp/DownloadInstallAgentPackage ]; then
        . /tmp/DownloadInstallAgentPackage
        Download_Install_Agent
    else
        echo "Failed to download the agent installation script."
        logger -t Failed to download the Deep Security Agent installation script
        false
    fi
else 
    echo "Please install CURL before running this script."
    logger -t Please install CURL before running this script
    false
fi

sleep 15

# Activate TrendAgent
/opt/ds_agent/dsa_control -r
/opt/ds_agent/dsa_control -a dsm://${trendUrl}:4120/
# End
