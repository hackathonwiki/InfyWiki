#!/bin/bash
#yum install -y mysql;
#****AWS CLI Installation steps:****
#**Steps to install pip:**
#curl -O https://bootstrap.pypa.io/get-pip.py
#python get-pip.py --user
#pip --version
#pip install awscli --upgrade --user
#**Steps to install ecs-cli:**
curl -o /usr/local/bin/ecs-cli https://s3.amazonaws.com/amazon-ecs-cli/ecs-cli-linux-amd64-latest
chmod +x /usr/local/bin/ecs-cli
alias ecs-cli="/usr/local/bin/ecs-cli"
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

#***Configure Profile***
ecs-cli configure --cluster InfyWiki --region ap-south-1 --default-launch-type EC2 --config-name InfyWiki
#read -s -p "Enter Your access-key: "  ak;printf '\n';
#read -s -p "Enter Your secret-key: "  sk;printf '\n';
ecs-cli configure profile --access-key $ak --secret-key $sk --profile-name InfyWiki


#*** Create DB Instance ***
echo "Deleting Existing DB Instance instance.It will take approximately 4 Mins..."
aws rds delete-db-instance --db-instance-identifier hackathon --delete-automated-backups --skip-final-snapshot 2>/dev/null;
#sleep 240;

aws rds create-db-instance --db-instance-identifier hackathon --db-instance-class db.t2.micro --engine mariadb --allocated-storage 20    --master-username bn_mediawiki --master-user-password bn_mediawiki --backup-retention-period 0
echo "Creating Fresh RDS MariaDB database Instance and restoring our Source Database.It will take approximately 5 mins..."
sleep 300;

db=$(aws rds describe-db-instances | grep "Address" | grep -i Hackathon | cut -f2 -d":" | tr -d "\"" | tr -d "\,")
echo "This is our DB Endpoint name: $db"
mysql -h $db -P 3306 -u bn_mediawiki -pbn_mediawiki -e "drop database bitnami_mediawiki;"
mysql -h $db -P 3306 -u bn_mediawiki -pbn_mediawiki -e "create database bitnami_mediawiki;"
echo "Copying Source DB from S3 and Restoring it on RDS instance"
#aws s3 cp s3://infywiki/Hackathon/bitnami_mediawiki.sql .
#mysql -h $db -P 3306 -u bn_mediawiki -pbn_mediawiki bitnami_mediawiki< bitnami_mediawiki.sql
#aws s3 cp s3://infywiki/Hackathon/docker-compose.yml .
#aws s3 cp s3://infywiki/Hackathon/ecs-params.yml .
#sed -i "/- MARIADB_HOST=/c\      - MARIADB_HOST=$(echo ${db//[[:blank:]]/})" docker-compose.yml;
read -p "Enter Your github username: "  usew;user=$(echo $usew | sed s/\@/\%40/g);printf '\n'
read -s -p "Enter Your github password: "  pasw;pass=$(echo $pasw | sed s/\@/\%40/g);printf '\n'
git clone https://$user:$pass@github.com/spdoc/InfyWiki.git
sed -i "/\$wgDBserver/c\$wgDBserver = \"$(echo ${db//[[:blank:]]/})\";" InfyWiki/app/LocalSettings1.php
cd InfyWiki/;git add app/LocalSettings1.php;cd ..;
cd InfyWiki/;git commit -m "Updated Localsettings";cd ..;
cd InfyWiki/;git push;cd ..;
cp -r InfyWiki/yml/* .;
cp -r InfyWiki/db/* .;
mysql -h $db -P 3306 -u bn_mediawiki -pbn_mediawiki bitnami_mediawiki< bitnami_mediawiki.sql
rm -rf InfyWiki/;
sed -i "/- MARIADB_HOST=/c\      - MARIADB_HOST=$(echo ${db//[[:blank:]]/})" docker-compose.yml;
echo "****DB Restoration is complete****"

#***Create Cluster***
#***Note:If multiple ecs creds are present you need to empty creds in ~/.ecs/credentials & ~/.ecs/config***
#ecs-cli up --force --keypair Hackathon --capability-iam --size 2 --instance-type t2.medium --vpc vpc-38301f50 --security-group sg-094eb8858ea662c53 --subnets subnet-b63f6bde subnet-21318b6d --cluster-config InfyWiki
#OR
echo "Lets Create Stack... It may take upto 5 minutes..."
ecs-cli up --force --keypair Hackathon --capability-iam --size 2 --instance-type t2.micro --azs ap-south-1a,ap-south-1b --cluster-config InfyWiki > clusterdetails
#wait till resources get generated
sleep 120s;
echo "Stack creation completed"
sleep 5s;
SG=$(grep Security clusterdetails | cut -f2 -d":" | tr -d ' ')
SN1=$(grep Subnet clusterdetails | cut -f2 -d":" | tr -d ' ' | awk 'NR==1{print $1}')
SN2=$(grep Subnet clusterdetails | cut -f2 -d":" | tr -d ' ' | awk 'NR==2{print $1}')


#Create a task definition using compose file
#aws s3 cp s3://infywiki/Hackathon/docker-compose.yml .
ecs-cli compose --file docker-compose.yml --project-name InfyWiki --verbose create > Taskdetails
TD=$(grep -r InfyWiki: Taskdetails | cut -f5 -d"=" | tr -d "\"" | tr -d "\,")
echo "creating task definition"
sleep 5;

#Create and configure load balancer
aws elb create-load-balancer --load-balancer-name InfyWiki --listeners "Protocol=TCP,LoadBalancerPort=443,InstanceProtocol=TCP,InstancePort=443" "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --security-group $SG --subnets $SN1 $SN2 > ELBdetails
aws elb configure-health-check --load-balancer-name InfyWiki --health-check Target=TCP:443,Interval=30,UnhealthyThreshold=8,HealthyThreshold=2,Timeout=20
echo "Creating Load Balancer"
sleep 5;
aws logs create-log-group --log-group-name InfyWiki_app
aws logs create-log-group --log-group-name InfyWiki_Jenkins
#Create Service and connect load balancer to it
aws ecs create-service --service-name "InfyWiki" --cluster "InfyWiki" --task-definition $TD --load-balancers "loadBalancerName=InfyWiki,containerName=mediawiki,containerPort=443" --desired-count 2 --deployment-configuration "maximumPercent=200,minimumHealthyPercent=50"
aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 443 --cidr 0.0.0.0/0
aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 8080 --cidr 0.0.0.0/0

echo "Creating Infywiki Service on ECS Cluster and attaching ELB to web containers"
sleep 180;
echo "Please find your Load Balancer details given below and Open webapp with https://LOAD-BALANCER-NAME:443"
ELB=$(aws elb describe-load-balancers --load-balancer-name InfyWiki | grep DNS | cut -f2 -d":" | tr -d "\"" | tr -d "\ " | tr -d "\,")
echo "Please find your Load Balancer details given below and Open webapp this URL: https://$ELB:443"
#rm -rf bitnami_mediawiki.sql clusterdetails docker-compose.yml ecs-params.yml ELBdetails Taskdetails;

printf "Security-Group= $SG\nSubnet1= $SN1\nSubnet2= $SN2\nDB endpoint= $db\nCurrent task-definition= $TD\nELB Details= $ELB\n\nPlease access your webapp using following link: https://$ELB:443\n\n" > details

cat details;
