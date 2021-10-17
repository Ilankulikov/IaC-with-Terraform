### Week 5 Project

# IaC with Terraform

__In this project I have created an infrastructure for the Weight Tracker application
using Microsoft Azure and Terraform.__

Project environment:
![week-4-project-env]()


>To implement this infrastructure Ive used all as described in the picture above.

>This project includes 1 module for the virtual machines.

>You can find documentation for each resource in the source code.

## Note
__For this project I have created VM images one for the application__
__The application vm image already contains the Node Weight Tracker app which you can find here:__
>https://github.com/Ilankulikov/bootcamp-app
Please read the requirements of the application.

**_In addition the vm contains a script I wrote for setting up .env file,Okta application redirect URIs using Okta API and finally initialize the database and running the application as a service using pm2_** 

__In this project Ive used Azure Database for PostgreSQL servers.__

## Deployment
__To deploy the environment you can create your own .tfvars file.__
__This file must include the following:__

>app_vm_image_id = "Resource ID of the application image"<br/>
app_vm_size      = "Size of the application virtual machine"<br/>
db_vm_size       = "Size of the database virtual machine"<br/>
username         = "Virtual machine username"<br/>
password         = "Virtual machine password"<br/>
pg_user          = "Postgres SQL user name"<br/>
pg_database      = "Postgres SQL database name"<br/>
pg_password      = "Postgres SQL password"<br/>


__or insert the variables interactively.__

__To deploy the enviroment follow these steps in the terminal:__

1 . To initialize Terraform working directory run
> "terraform init"

2 . To deploy the enviroment:

>2.1. If you are using .tfvars file run:

    terraform apply -var-file="FILE_NAME.tfvars"

>2.2. If you want to enter values interactively just run
    terraform apply 

>Note: add optional flag "-auto-approve" to automatically approve the plan.

__for example:__

    terraform apply -var-file="FILE_NAME.tfvars" -auto-approve



>To remove whole enviroment run:

    terraform destroy

>If you are used .tfvars file run:

    terraform destroy -var-file="FILE_NAME.tfvars" 
