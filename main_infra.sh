#****AWS CLI Installation steps:****

#**Steps to install pip:**
#curl -O https://bootstrap.pypa.io/get-pip.py
#python get-pip.py --user
#pip --version
#pip install awscli --upgrade --user

#**Steps to install ecs-cli:**
#curl -o /usr/local/bin/ecs-cli https://s3.amazonaws.com/amazon-ecs-cli/ecs-cli-linux-amd64-latest
#chmod +x /usr/local/bin/ecs-cli
#alias ecs-cli="/usr/local/bin/ecs-cli"

#**Configure AWS**
aws configure set default.region ap-south-1
read -s -p "Enter Your access-key: "  ak;printf '\n';
aws configure set aws_access_key_id $ak
read -s -p "Enter Your secret-key: "  sk;printf '\n';
aws configure set aws_secret_access_key $sk

#Check If AWS Configured properly
if [[ $(aws s3 ls) ]]; then
    echo "AWS-CLI Configured properly"
else
    echo "Please Reconfigure AWS-CLI"
fi

#***Steps to build Infra & Bring InfyWiki up:***
ecs-cli configure --cluster InfyWiki --region ap-south-1 --default-launch-type EC2 --config-name InfyWiki
#read -s -p "Enter Your access-key: "  ak;printf '\n';
#read -s -p "Enter Your secret-key: "  sk;printf '\n';
ecs-cli configure profile --access-key $ak --secret-key $sk --profile-name InfyWiki
#***Note:If multiple ecs creds are present you need to empty creds in ~/.ecs/credentials & ~/.ecs/config***
ecs-cli up --force --keypair Hackathon --capability-iam --size 2 --instance-type t2.medium --vpc vpc-38301f50 --security-group sg-094eb8858ea662c53 --subnets subnet-b63f6bde subnet-21318b6d --cluster-config InfyWiki
OR
ecs-cli up --force --keypair Hackathon --capability-iam --size 2 --instance-type t2.medium --azs ap-south-1a,ap-south-1b --cluster-config InfyWiki
#VPC created: vpc-0e350b1878e3ccdd3
#Security Group created: sg-06f9ec3a7ba0b7019
#Subnet created: subnet-0cff8a411f13fd93a
#Subnet created: subnet-0a83e893de6b76fd8
#Cluster creation succeeded.

#wait till resources get generated
sleep 180s;


#Commands to create ELB & Multi-AZ Deployment:
#Create a task definition using compose file
ecs-cli compose --file docker-compose.yml --project-name InfyWiki --verbose create

#Create and configure load balancer
aws elb create-load-balancer --load-balancer-name InfyWiki --listeners Protocol="TCP,LoadBalancerPort=443,InstanceProtocol=TCP,InstancePort=443" --security-group sg-06f9ec3a7ba0b7019 --subnets subnet-0cff8a411f13fd93a subnet-0a83e893de6b76fd8

#Create Service and connect load balancer to it
aws ecs create-service --service-name "InfyWiki" --cluster "InfyWiki" --task-definition InfyWiki:13 --load-balancers "loadBalancerName=InfyWiki,containerName=mediawiki,containerPort=443" --desired-count 2 --deployment-configuration "maximumPercent=200,minimumHealthyPercent=50"
