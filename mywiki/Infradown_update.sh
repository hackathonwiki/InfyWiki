#delete service steps:
aws rds delete-db-instance --db-instance-identifier hackathon --delete-automated-backups --skip-final-snapshot;
aws ecs update-service --service InfyWiki --cluster "InfyWiki" --desired-count 0;
aws ecs delete-service --service InfyWiki --cluster "InfyWiki";
aws elb delete-load-balancer --load-balancer-name InfyWiki;
#collect all task details in file
aws ecs list-task-definitions | grep task-definition | cut -f2 -d"/" | tr -d "\"" | tr -d "\," > task_list;
#echo all tasks
cat task_list;
#delete all tasks
while read task; do aws ecs deregister-task-definition --task-definition $task >/dev/null; done < task_list;
rm -rf task_list;
alias ecs-cli="/usr/local/bin/ecs-cli"
ecs-cli down --force;
sleep 300;

#Update or scale service
#aws s3 cp s3://infywiki/Hackathon/docker-compose.yml .
#ecs-cli compose --file docker-compose.yml --project-name InfyWiki --verbose create > Taskdetails
#TD=$(grep -r InfyWiki: Taskdetails | cut -f5 -d"=" | tr -d "\"" | tr -d "\,")
#aws ecs update-service --service InfyWiki --cluster "InfyWiki" --desired-count 0
#aws ecs delete-service --service InfyWiki --cluster "InfyWiki"
#aws ecs create-service --service-name "InfyWiki" --cluster "InfyWiki" --task-definition $TD --load-balancers "loadBalancerName=InfyWiki,containerName=mediawiki,containerPort=443" --desired-count 2 --deployment-configuration "maximumPercent=200,minimumHealthyPercent=50"

#aws elb register-instances-with-load-balancer --load-balancer-name InfyWiki --instances 
