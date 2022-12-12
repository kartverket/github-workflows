# Troubleshooting
- [Locked terraform workloads](#locked-terraform-workloads)
- [Terraform Destroy](#terraform-destroy)

# Authentication errors
- Re-read the descriptions of the inputs in the Options section of README.md and tripple check that you have specified the corret project_id, auth_project_number, service_account, etc..

# Locked terraform workloads
If you experience having a locked terraform workload, run terraform force-unlockl by providing the `LOCK_ID` as the `unlock` input in run-terraform.

# Terraform Destroy
You can set the `destroy` input in run-terraform to `true` in order to run terraform destroy. 