# Troubleshooting
- [Authentication errors](#authentication-errors)
- [Locked terraform workloads](#locked-terraform-workloads)
- [Terraform Destroy](#terraform-destroy)

<br/>

## Authentication errors
Before contacting support, re-read the descriptions of the inputs in the Options sections of README.md and double check that you have specified the corret `project_id`, `auth_project_number`, `service_account`, etc. 

<br/>

## Locked terraform workloads
If you experience having a locked terraform workload, run `terraform force-unlock` by providing the `LOCK_ID` as the `unlock` input in run-terraform.

<br/>

## Terraform Destroy
You can set the `destroy` input in run-terraform to `true` in order to run `terraform destroy`. 