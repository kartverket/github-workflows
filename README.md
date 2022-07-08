# github-workflows
Shared reusable workflows for GitHub Actions

## run-terraform
This workflow plans and runs terraform to deploy to Kartverket. 

The code extract below shows two job, one which enables us to reuse variables, and one which enables us to run terraform through the reusable workflow. 
Note that the setup-env job is required in order to pass values into the reusable workflow, since reusable workflows do not yet support environment variables.
```yaml
env:
  WORKLOAD_IDENTITY_FEDERATION_PROVIDER: X
  WORKLOAD_IDENTITY_FEDERATION_SERVICE_ACCOUNT: X
  PROJECT_ID: X

jobs:
  setup-env:
    runs-on: ubuntu-latest
    outputs:
      workload_identity_provider: ${{ steps.set-output.outputs.workload_identity_provider }}
      service_account: ${{ steps.set-output.outputs.service_account }}
      project_id: ${{ steps.set-output.outputs.project_id }}
    steps:
      - name: set outputs with default values
        id: set-output
        run: |    
          echo "::set-output name=workload_identity_provider::${{ env.WORKLOAD_IDENTITY_FEDERATION_PROVIDER }}"
          echo "::set-output name=service_account::${{ env.WORKLOAD_IDENTITY_FEDERATION_SERVICE_ACCOUNT }}"
          echo "::set-output name=project_id::${{ env.PROJECT_ID }}"

 dev:
    name: Deploy to dev
    needs: setup-env

    permissions: 
      id-token: write
      contents: read
      
    uses: kartverket/github-workflows/.github/workflows/run-terraform.yml@main
    with:
      runner: atkv1-dev
      environment: dev
      terraform_workspace: dev
      terraform_options: -var-file=dev.tfvars
      working_directory: terraform
      workload_identity_provider: ${{ needs.setup-env.outputs.workload_identity_provider }}
      service_account: ${{ needs.setup-env.outputs.service_account }}
      project_id: ${{ needs.setup-env.outputs.project_id }}
```