# terraform-openstack-cds

The repository contains Terraform configurations for deploying the vms necessary for testing the OVH CDS application 

In order to run these Terraform configurations you will need to have created an OVH public cloud account, cloud project, Openstack user in the cloud project and downloaded the openrc.sh file for the Openstack user.

You can then source the openrc.sh file you downloaded, provide the password for the Openstack user and run `terraform plan` to test connecting to OVH public cloud.

This Terraform configuration will do the following:
- generate a unique ssh-key for connecting to the deployed vms
- create an openstack network for internal communication between the CDS and postgresql vms
- create an openstack internal subnet for assigning IP addresses to the CDS and postgresql vms (10.240.0.0/24)
- create an openstack security group to allow TCP 22 (SSH), 2015 (CDS web ui), 8081 (CDS API), 5432 (postgresql only from internal subnet addresses) and ICMP.
- create a 100G blockstorage volume for postgresql data 
- create a cds-postgresql openstack compute instance, install postgresql and configure the database to CDS (internal address of 10.240.0.90)
- create a cds-engine openstack compute instance, install redis, cds and configure the CDS systemd services (internal address of 10.240.0.91)
- add the public IP addresses of cds-postgresql and cds-engine into /etc/hosts (the python openstack client must be installed for this to work - 'pip install python-openstackclient') 

In order to provide seemless SSH access using the /etc/hosts entries the following lines can be added to ~/.ssh/config:

```
Host cds-postgresql
Hostname cds-postgresql
User ubuntu
Port 22
IdentityFile ~/.ssh/id_rsa-terraform_cds
StrictHostKeyChecking no
UserKnownHostsFile /dev/null

Host cds-engine
Hostname cds-engine
User ubuntu
Port 22
IdentityFile ~/.ssh/id_rsa-terraform_cds
StrictHostKeyChecking no
UserKnownHostsFile /dev/null
```
