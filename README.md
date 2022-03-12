# OpenDroneMap build using Terraform in Azure using GitHub workflow actions

Provision virtual machines in Azure to run OpenDroneMap. This can all be ran from GitHub using Actions. No need to install Terraform on a local machine. It uses storage account to manage the Terraform state file.

A typical GitHub action will automatically run when a commit is posted. I opted to change the workflows to manual as I often only run a plan to check code, and more importantly, destroy the entire environment when done. I do not keep anything provisioned or running, aside from the storage account backend. The backend can be destroyed between builds. It is most needed when trying to destroy the environment.

This build also uses ***cloud-init*** to configure the instances, using file `webodm.tpl` and `nodeodm.tpl`. It is important to note that the build will indicate complete but the machine will still need time to download containers and launch. More information on [cloud-init](https://cloud-init.io). This has taken about 5 minutes for all containers to download and launch.

Why Terraform: This provides a fresh clean build for each project. And can easily be decommissioned to save on cloud costs. It allows for testing of software upgrades that may come. In addition, some changes can be made on the fly once provisioned. Port 22 is left closed, but can easily be opened if needed, then simply running the Apply workflow to enable. If changes are made outside of Terraform, i.e. in the web portal, then the Destroy workflow may not work. 

## Setup

### Create Azure Service Principal and Store Account

While possible using the web interface, this approach is a little more straightforward, but does require the installation of Azure CLI. Install Azure CLI per these instructions: (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

#### AZ Login

Assuming you already have a subscription in Azure created, use `az login` to login into Azure. If successful, you are returned with a JSON format.

	az login

This should open a browser for sign on to Azure. After logging in, should see the following output. 
	
```json	
[
  {
    "cloudName": "AzureCloud",
    "homeTenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "id": "xxxxxxxx-XXXX-xxxx-XXXX-xxxxxxxxxxxx",
    "isDefault": true,
    "managedByTenants": [],
    "name": "sub01-prod",
    "state": "Enabled",
    "tenantId": "89axxxxx-53xx-41xx-91xx-cf43xxxxxxxx",
    "user": {
      "name": "you.username@live.com",
      "type": "user"
    }
  }
]
```
#### Create Service Principal

This account will be used from GitHub to interact with Azure. Using AZ CLI, run the following command: 


    az ad sp create-for-rbac --name "[name of service account]" --role Contributor --scopes /subscriptions/[Subscription ID from above or other subscription ID]
	
Output if successful will provide login credentials. This is sensitive information, handle carefully.

```json
{
  "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "clientSecret": "[client secret]",
  "subscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenantId": "89axxxxx-53xx-41xx-91xx-cf43xxxxxxxx",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```
#### Create Storage Account

My preference is to create a separate resource group for the storage account, the create the account. Again, can be faster using CLI.

	az group create -n tfstate-rg -l centralus
	az storage account create -n githubtfstate -g tfstate-rg -l centralus --sku Standard_LRS
 
 
#### Create SSH keys

Use `ssh-keygen` to create a new SSH key. Suggest using a different name other than the default `id_rsa`. This project uses `id_rsa_webodm`. The name of the key is important. If using something other than `id_rsa_webodm` then care must be taken to make sure the name matches throughout the repository and in GitHub.

## GitHub setup

In the repository, navigate to `Settings` - `Secrets` - `Actions`. Create new secrets for the following:
```
- AZURE_AD_CLIENT_ID 	  - upload the clientId
- AZURE_AD_CLIENT_SECRET  - upload the clientSecret
- AZURE_AD_TENANT_ID	  - upload the tenantId
- AZURE_SUBSCRIPTION_ID   - upload the subscriptionId or a different subscription ID
- ID_RSA_WEBODM		  - upload the contents of the public key generated
- STORAGE_ACCOUNT_NAME	  - name of the storage account
```
## Review build

Terraform uses *.tf files to build the environment. File `variables.tf` is where you can adjust the build for your needs. Edit as needed to change the number of servers, the version of the servers and the project information. It is also important to verify the location where this will be provisioned. The `tpl` files are `cloud-init` build files that are executed on the servers. Here you can add packages and make other configuration changes as the servers come up. 

## Execution

In GitHub, navigate to `Actions`.

### Plan

- In the GitHub repo, under Actions, select the `A - Terraform Plan` action, then click `Run Workflow` and select the appropriate branch, then `Run Workflow`.

After a few moments, the workflow will begin. Click on the job to watch progress. If fail, check the error messages. If successful, then ready to move to apply. The run has to be successful, and green before it can move to the next phase.

### Apply

- Once the plan workflow is good, repeat the same process for `B - Terraform Apply`.

Progress of the build can be monitored. When complete, navigate to the completed run, then `terraform_apply`, and expand `Terraform Apply`. Scroll to bottom. There should be found the public IP address of the build.

***Note:*** It will take a few moments before the web interface is accessible as all the docker containers need to be retrieved. I've found that is 5 minutes. If after 5 minutes, then should access the instance using SSH. Since the IP address changes with each build, your local `known_hosts` file can get a little messy. Therefore I typically launch SSH with the command below.

    ssh -q -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ~/.ssh/[yourPrivateKey].pem ubuntu@[AWS public IP address]

### Output

This workflow is simply there if you need to check the IP addresses again. However, since this is pulled from the `terraform.tfstate` file, it won't reflect any changes if made from the AWS console.

### Destroy

- Once jobs are complete and data retrieved, then the environment can be brought down by running the action `X - Terraform Destroy`. If job is successful, then all resources brought up (exception VPC - DHCP options set) will be removed.

### Terraform State Destroy

Sometimes the state file becomes out of sync, probably due to a change outside of Terraform, i.e. using the AWS Dashboard. This will be evident when Destroy workflow fails. Run this workflow to reset everything.

## OpenDroneMap

After 5 minutes, WebODM, ClusterODM and nodeODM nodes should be ready to acesss. Open the `B - Terraform Apply` action, and select `Terraform Apply` until you see `Terraform Output`. Expand this section and you should see IP addresses for the nodes. A public IP address for WebODM, then private IP addresses for ClusterODM and any nodes. 

- [public ip]:8000 WebODM
- [public ip]:8001 ClusterODM (Yes, this is changed from the default port of 10000)

Open a browser to the ClusterODM port and add in the nodes using the private IP address. Use port 3001 for the node that is on the WebODM/ClusterODM server, then port 3000 for the other nodes.

Then open port 8000 to access the WebODM portal, and add the ClusterODM using the private IP address and port 8080.