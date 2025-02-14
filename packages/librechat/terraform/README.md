

## Instructions

### 1. Create a bucket for Terraform

Create a bucket and update the `main.tf` file with the name of the bucket to store the Terraform assets.

### 2. Apply the Terraform Config

From the root level run the following commands.

```
terraform init
terraform apply
```

### 3. Adding an Additional PostgreSQL Database

Manual steps are neded to add another psql database. The `litellm` database is created by default and the `rag` database
needs to be manually added. Follow the steps below from within the AWS Console under "Amazon RDS".

1. Adding a new database for the RAG API

Navigate to the query builder in Amazon RDS. Connect to the LiteLLM database to start (`litellm`). Run the command

```
create database rag;
```

2. Enable the vector extension

Connect to the newly created RAG database (`rag`). Run the command

```
CREATE EXTENSION vector;
```

Now the new database should be present with vector datastore capabilities.

### 4. Adding LibreChat Config to EFS Instance

The `librechat.yaml` file needs to be placed into the the EFS instance so that the LibreChat task can run correctly.
The current approach recommended is to make an EC2 instance in the same VPC as the EFS instance, mount the EFS instance,
SCP the file into the EC2 instance, then place the config file into the EFS root directoy.

1. Create an EC2 isntance

Create an EC2 instance you can SSH into in the same VPC as the EFS instance

2. Follow the steps to mount the EFS instance

https://docs.aws.amazon.com/efs/latest/ug/mounting-fs-mount-helper-ec2-linux.html

3. SCP the librechat config to the EC2 instance

4. Place the file in the EFS root directoy


At this point the file should be in the correct place. The LibreChat Fargate task will likely need to be manually
re-deployed for the change to take effect.

### 5. Request Access to Models in AWS Bedrock

Model access is granted on a per-request basis (can request all models at once).

https://us-east-1.console.aws.amazon.com/bedrock/home?region=us-east-1#/modelaccess


### 6. Add Models to LiteLLM

Once the target model is enabled in AWS Bedrock, it can be added in LiteLLM.

1. Navigate to the "Models" page in the admin UI

2. Select add model with the following information

* Provider: Amazon Bedrock
* LiteLLM Model Name(s): Name of the model enabled in AWS bedrock
* Public Model Name: Any appropriate name
* AWS Access Key ID: `os.environ/LITELLM_BEDROCK_ACCESS_ID`
* AWS Secret Access Key: `os.environ/LITELLM_BEDROCK_ACCESS_SECRET`
* AWS Region Name: Region of deployment, typically `us-east-1`

3. Select Add Model

4. LibreChat may need to be restarted for the new model to be visible

### 7. Make New Deployments

With the manual changes, LiteLLM, LibreChat, and the RAG API should be restarted.
Under the "Amazon Elastic Container Service" section. Navigate to the target cluster and
on each task in turn select the task and under "Update" select "Force new deployment" 
