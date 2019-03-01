#***Steps to scrap all infra and remove InfyWiki:***
ecs-cli compose --file docker-compose.yml down --cluster-config InfyWiki
ecs-cli down --force
#collect all task details in file
aws ecs list-task-definitions | grep task-definition | cut -f2 -d"/" | tr -d "\"" | tr -d "\," > task_list
#echo all tasks
cat task_list
#delete all tasks
while read task; do aws ecs deregister-task-definition --task-definition $task >/dev/null; done < task_list



#delete service steps:
aws ecs update-service --service InfyWiki --cluster "InfyWiki" --task-definition InfyWiki:6 --desired-count 0
aws ecs delete-service --service InfyWiki --cluster "InfyWiki"

ecs-cli compose --file docker-compose.yml --project-name InfyWiki --verbose create

aws ecs create-service --service-name "InfyWiki" --cluster "InfyWiki" --task-definition InfyWiki:11 --load-balancers "loadBalancerName=InfyWiki,containerName=mediawiki,containerPort=443" --desired-count 2 --deployment-configuration "maximumPercent=200,minimumHealthyPercent=50"
