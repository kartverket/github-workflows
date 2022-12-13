# Troubleshooting
- [Authentication errors](#authentication-errors)
- [Locked terraform workloads](#locked-terraform-workloads)
- [Terraform Destroy](#terraform-destroy)

# Authentication errors
- Re-read the descriptions of the inputs in the Options section of README.md and triple check that you have specified the correct project_id, auth_project_number, service_account, etc..
<br/>
If the problem still persists, something might be wrong with the Connect Gateway, which might cause trouble for logging in. Please contact the SKIP team if this is the case.

# Locked terraform workloads
If you experience having a locked terraform workload, run terraform force-unlockl by providing the `LOCK_ID` as the `unlock` input in run-terraform.

## Authentication errors
Before contacting support, re-read the descriptions of the inputs in the Options sections of README.md and double check that you have specified the corret `project_id`, `auth_project_number`, `service_account`, etc. 

# Terraform Destroy
You can set the `destroy` input in run-terraform to `true` in order to run terraform destroy where the apply step usually is. This will destroy **all** the infrastructure in your working folder, so do not use this without understanding the implications.

<br/>

## Locked terraform workloads
If you experience having a locked terraform workload, run `terraform force-unlock` by providing the `LOCK_ID` as the `unlock` input in run-terraform.

<br/>

## Terraform Destroy
You can set the `destroy` input in run-terraform to `true` in order to run `terraform destroy`. 