# terraform-openstack-cds

The repository contains Terraform configurations for deploying the vms necessary for testing the OVH CDS application 

In order to run these Terraform configurations you will need to have created an OVH public cloud account, cloud project, Openstack user in the cloud project and downloaded the openrc.sh file for the Openstack user.

You can then source the openrc.sh file you downloaded, provide the password for the Openstack user and run `terraform plan` to test connecting to OVH public cloud.

This Terraform configuration will do the following:
- generate a unique ssh-key for connecting to the deployed vm
- create an openstack network for internal communication between the CDS and postgresql vms
- create an openstack internal subnet for assigning IP addresses to the CDS and postgresql vms
- create an openstack security group to allow TCP 22 (SSH), 2015 (CDS web ui), 8081 (CDS API), 5432 (postgresql only from internal subnet addresses) and ICMP.
- create a 100G blockstorage volume for postgresql data 
- create a cds-postgresql openstack compute instance, install postgresql and configure the database to CDS
- create a cds-engine openstack compute instance, install redis, cds and configure the CDS systemd services

