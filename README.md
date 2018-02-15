# Delectable Terraform Vault Setup

Based on [Avant's Terraform Setup](https://github.com/avantoss/vault-infra/).

Sets up Vault in a secure manner, with Packer and Teraform. This module:

* Uses only AWS services, so there are no external dependencies or backends to manage
* Stores HA information via DynamoDB, to easily handle node failures
* Uses the S3 storage backend for Vault, with cross-region replication and versioning for recovery and disaster recovery
* Builds AMIs with Packer and Ansible
* Uses ALBs to route only to healthy Vault leaders

This repository can be used in high-availability mode, or single-instance mode, by configuring the autoscaling group parameters.

Note that the Packer configuration is contained in [its own repository](https://github.com/delectable/packer-vault).

**NOTE:** This repository is currently configured such that Vault serves traffic on port 8200 via **HTTP**. Requests to the load balancer are TLS-encrypted over HTTPS, but before deploying this in production, internal traffic beyond the load balancer should be encrypted with a TLS certificate.

## Getting Started

1. Modify `vault.json` in https://github.com/delectable/packer-vault as needed, particularly the `variables` section.
2. Run `packer build vault.json` from within the https://github.com/delectable/packer-vault repository working directory. Note the generated AMI ID in the region that you will be deploying into.
3. Instantiate the `terraform` module:
```
module "vault" {
  source = "github.com/delectable/terraform-aws-vault"

  # Environment
  env            = "${ var.env }"
  region         = "${ var.region }"
  dr_region      = "${ var.dr_region }"
  aws_account_id = "${ var.aws_account_id }"
  tags           = "${ var.tags }"
  tags_asg       = "${ var.tags_asg }"

  # Networking
  vault_dns_address         = "${ var.vault_dns_address }"
  vpc_id                    = "${ var.vpc_id }"
  alb_subnets               = "${ var.alb_subnets }"
  ec2_subnets               = "${ var.ec2_subnets }"
  alb_allowed_ingress_cidrs = "${ var.alb_allowed_ingress_cidrs }"
  alb_allowed_egress_cidrs  = "${ var.alb_allowed_egress_cidrs }"

  # ALB
  alb_certificate_arn = "${ var.alb_certificate_arn }"
  alb_internal        = false

  # EC2
  ami_id               = "AMI_ID_FROM_STEP_2"
  instance_type        = "${ var.instance_type }"
  ssh_key_name         = "${ var.ssh_key_name }"
  asg_min_size         = "${ var.asg_min_size }"
  asg_max_size         = "${ var.asg_max_size }"
  asg_desired_capacity = "${ var.asg_desired_capacity }"

  # S3
  vault_resources_bucket_name = "${ var.vault_resources_bucket_name }"
  vault_data_bucket_name      = "${ var.vault_data_bucket_name }"

  # DynamoDB
  dynamodb_table_name = "${ var.dynamodb_table_name }"
}
```
4. Run `terraform plan`, followed by `terraform apply`.
5. Temporarily, manually, attach an SSH security group to Vault instances, SSH into one of them, and become root. Run `vault init` to initialize Vault.
6. (Optional) Copy all of the unseal keys and the root key locally, and then to the correct folders in S3, via the CLI:
```
aws s3 cp root_key.txt s3://BUCKET_NAME/resources/root_key/root_key.txt --sse AES256
aws s3 cp unseal_key_one.txt s3://BUCKET_NAME/resources/unseal_keys/unseal_key_one.txt --sse AES256
aws s3 cp unseal_key_two.txt s3://BUCKET_NAME/resources/unseal_keys/unseal_key_two.txt --sse AES256
aws s3 cp unseal_key_three.txt s3://BUCKET_NAME/resources/unseal_keys/unseal_key_three.txt --sse AES256
aws s3 cp unseal_key_four.txt s3://BUCKET_NAME/resources/unseal_keys/unseal_key_four.txt --sse AES256
aws s3 cp unseal_key_five.txt s3://BUCKET_NAME/resources/unseal_keys/unseal_key_five.txt --sse AES256
```
7. Unseal Vault with three of the five keys: `vault unseal UNSEAL_KEY`.
8. Clear your history and exit the SSH session: `cat /dev/null > ~/.bash_history && history -c && exit`.
9. Remove the temporary SSH security group.
10. Assign a DNS CNAME to the ALB, making sure that it matches the SSL certificate being used.

## Packer Architecture

The Packer builder in https://github.com/delectable/packer-vault uses Ansible to download and install Vault on an Ubuntu AMI, following relevant recommendations in Hashicorp's [Production Hardening](https://www.vaultproject.io/guides/production.html) guide. In particular, it:

* Creates a `vault` service user
* Installs `vault` after verifying its checksum
* Adds a `vault` systemd service.

Secrets are only maintained in S3, and are pulled into the running instance on boot. This eliminates the attack surface of baking secrets into the AMI.

### Upgrading Vault

Vault can be upgraded by modifying `vault_version` and `vault_version_checksum` to match the newest available version, then rebuilding the Packer image. Once the Packer image is rebuilt, modify the AMI used in Terraform variables, and apply the changes. Note that when running with fewer than 3 or 5 Vault instances, this might cause momentary downtime.

## Terraform Architecture

This module sets up two S3 buckets: one for Vault data (secret storage), and one for Vault resources necessary to bootstrap a node. Access to these buckets is limited to the necessary IAM roles, using principle of least-access. For example, Vault instances have read/write access to the data bucket, but read access only to specific paths in the resources bucket, and no write access to it.

~~By default, an ASG is created with a desired capacity of 3, allowing for 2 AZ failures to be handled automatically.~~ **NOTE:** We are currently deploying Vault in a single instance, which increases failure risk.

### S3 Storage Backend

We use S3 as the storage backend due to its reliability, scalability, and simplicity. In addition to AWS's high SLA for data reliability, we use cross-region replication to virtually eliminate any chance of data loss.

Notably, we do not use encrypted buckets to allow cross-region replication to work (it does not support encrypted objects). This is acceptable, as Vault encrypts all data before ever writing it to S3.

### S3 Resources Bucket

A second S3 bucket is utilized to store all Vault resources, including access logs, SSL certificates (if needed), unseal keys, the root key, the SSH key (if desired), and the Vault configuration file. This bucket stores all secrets necessary to get Vault bootstrapped.

If a SSL certificate is used here, it is important that it be issued only for the exact domain that Vault is exposed on. If the SSH key for Vault instance(s) is stored in this bucket, it should be one that is only used for these particular instances. Furthermore, while this bucket is a convenient place to store the root and unseal keys, we **strongly** recommend distributing them to trusted individuals or groups, rather than storing them all in one place.

### DynamoDB HA Backend

S3 does not support locking, therefore it can not manage a high-availability Vault setup. DynamoDB, with the `ha_storage` option, can be used to manage HA and still use S3 as the storage backend. Vault is configured in this deployment to manage the Dynamo table on its own.

### Failure Modes

#### Node Failure

**NOTE: This only applies if running in high availability**

If a node fails or seals for any reason, the simplest means of remediation is to simply terminate the instance. The ASG will create a new instance that can be manually unsealed.

#### Availability Zone Failure

**NOTE: This only applies if running in high availability**

In the event of an AZ failure Vault should automatically fail over to a backup node. The primary will start failing health checks, a new leader will be chosen and its health checks will start passing, and traffic will be routed to the new leader. This should all occur automatically in less than 60 seconds. Since an AZ failure will likely seal the old Vault leader you will need to terminate the failed node and unseal the new node that the ASG created in order to remain highly available.

#### Region Failure

In the event of a region failure, the best option is usually to wait until AWS resolves the issue. If the failure is persistent and impacting business operations significant, you can fall over to the Disaster Recovery region. No secret data should be lost between the two regions, due to S3 and cross-region replication.

### Secret Version Recovery

Because we use S3 with versioning enabled it is possible (but not simple) to recover an old version of a secret. This should only be used in extreme circumstances, and requires Vault downtime:

1. Seal and stop all Vault services
2. In S3, navigate to the secret and restore to the desired previous version
3. Start and unseal all Vault services

Downtime is required because the Vault service maintains a cache that could overwrite any version recovery when it is flushed to the backend.

### Access Logs

Access logs are enabled on the ALB and S3 resources bucket. Logs are placed in the `logs/` directory of the resources bucket for analysis by other services. By default, these logs are not replicated between regions.

### Telemetry

Datadog is installed on the Vault nodes, and [dogstatsd](https://www.vaultproject.io/docs/configuration/telemetry.html#dogstatsd) is enabled in the Vault configuration.

## Further Considerations

### Vault Logging

Logging of access to Vault is handled through [Audit Backends](https://www.vaultproject.io/docs/audit/index.html).
