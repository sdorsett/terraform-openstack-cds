# terraform-openstack-cds

The repository contains Terraform configurations for deploying the vms necessary for testing the OVH CDS application 

In order to run these Terraform configurations you will need to have created an OVH public cloud account, cloud project, Openstack user in the cloud project and downloaded the openrc.sh file for the Openstack user.

You can then source the openrc.sh file you downloaded, provide the password for the Openstack user and run `terraform plan` to test connecting to OVH public cloud.

