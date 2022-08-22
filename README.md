# github-workflows

Shared reusable workflows for GitHub Actions

## run-terraform

This workflow plans and applies Terraform config to deploy to an environment.

### Features

- Logs in to GCP, Kubernetes and Vault automatically with [Workload Identity Federation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- Posts comments with relevant information to Pull Requests
- Runs validate, format and plan to verify deployment follows conventions before running apply
- Posts summaries on relevant steps on the Action pipeline view to improve visibility
- Supports manual approval and delay periods in deploy using  [GitHub Environments protection rules](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#environment-protection-rules)
- Re-uses plan from plan step in apply step to ensure apply always executes the diff generated by plan no matter when it is run
- Prevents deploys running in parallel against the same environment crashing due to failing to aquire state lock
- Performs binary attestation on the image if proivided. Note that for an image to be used in the test and prod environments (i.e. test and prod kubernetes clusters) it will need to be attested in this manner.

### Example

```yaml
jobs:
  dev:
    name: Deploy to dev
    permissions:
      # For logging on to Vault, GCP
      id-token: write
      # For writing comments on PR
      pull-requests: write
      # For fetching git repo
      contents: read
    uses: kartverket/github-workflows/.github/workflows/run-terraform.yml@v2.6
    with:
      runner: atkv1-dev
      environment: dev
      kubernetes_cluster: atkv1-dev
      terraform_workspace: dev
      terraform_options: -var-file=dev.tfvars
      working_directory: terraform
      workload_identity_provider: X
      service_account: X
      project_id: X
      image_url: <registry>/<repository>:<tag>
      bucket: X
```

### Passing env vars to run-terraform

Passing environment variables to reusable workflows is not supported by GitHub.
This is a [requested feature](https://github.community/t/passing-environment-variables-to-reusable-workflow/230456/4).
The current workaround for this is to use a setup-job to consume env vars and
provide an output that can be mapped to the arguments of the job.

<details>
<summary>Click here to see an example of this</summary>
<code><pre>env:
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
    uses: kartverket/github-workflows/.github/workflows/run-terraform.yml@v2.1
    with:
      runner: atkv1-dev
      environment: dev
      kubernetes_cluster: atkv1-dev
      terraform_workspace: dev
      terraform_options: -var-file=dev.tfvars
      working_directory: terraform
      workload_identity_provider: ${{ needs.setup-env.outputs.workload_identity_provider }}
      service_account: ${{ needs.setup-env.outputs.service_account }}
      project_id: ${{ needs.setup-env.outputs.project_id }}</pre></code>
</details>

### Passing secrets to run-terraform

Secrets should be administered through vault and thus there is no explicit
support for taking GitHub secrets into the action. GitHub will also stop you
from sending secrets as arguments using the `with` argument, so this will not
work either.

Use the [vault_generic_secret](https://registry.terraform.io/providers/hashicorp/vault/latest/docs/data-sources/generic_secret)
Terraform data source along with the `vault_role` argument to run-terraform to
fetch secrets required at deploy-time.

Each repo needs its own unique `vault_role`. Contact SKIP if you do not have
this role.

### Options

| Key                        | Type    | Required | Description                                                                                                                                                                                                                    |
|----------------------------|---------|----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| workload_identity_provider | string  | X        | The ID of the provider to use for authentication. It should be in the format of `projects/{{project}}/locations/global/workloadIdentityPools/{{workload_identity_pool_id}}/providers/{{workload_identity_pool_provider_id}}`.  |
| service_account            | string  | X        | The GCP service account connected to the identity pool that will be used by Terraform.                                                                                                                                         |
| runner                     | string  | X        | The GitHub runner to use when running the deploy. This can for example be `atkv1-dev`.                                                                                                                                         |
| deploy_on                  | string  |          | Which branch will be the only branch allowed to deploy. This defaults to the main branch so that other branches only run check and plan. Defaults to `refs/head/main`.                                                         |
| working_directory          | string  |          | The directory in which to run terraform, i.e. where the Terraform files are placed. The path is relative to the root of the repository.                                                                                        |
| project_id                 | string  |          | The GCP Project ID to use as the "active project" when running Terraform. When deploying to Kubernetes, this must match the project in which the Kubernetes cluster is registered.                                             |
| kubernetes_cluster         | string  |          | An optional kubernetes cluster to authenticate to. Note that the project_id must match where the cluster is registered.                                                                                                        |
| environment                | string  |          | The GitHub environment to use when deploying. See [using environments for deployment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) for more info on this. |
| vault_role                 | string  |          | Required when using vault in terraform. Enables fetching jwt and logging in to vault for the terraform provider to work.                                                                                                       |
| terraform_workspace        | string  |          | When provided will set a workspace as the active workspace when planning and deploying.                                                                                                                                        |
| terraform_options          | string  |          | Any additional terraform options to be passed to plan and apply. For example `-var-file=dev.tfvars`                                                                                                                            |
| add_comment_on_pr          | boolean |          | Setting this to `false` disables the creation of comments with info of the Terraform run on Pull Requests. When `true` the `pull-request` permission is required to be set to `write`. Defaults to `true`.                     |
| image_url                  | string |          | An optional parameter; however, it is required for binary attestation. The Docker image url must be of the form registry/repository:tag                                                                                                                            |
| bucket                  | string |          | An optional Cloud Storage bucket.                                                                                                                             |

## post-build-attest

This workflow performs binary attestation on a built image. 
Note the format of the image_url parameter. 

### Features

- Logs in to GCP automatically with [Workload Identity Federation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- Performs binary attestation on the image. Attests (1) that the image was built in context of Kartverket and (2) that the image is on main/master branch.

### Example

```yaml
jobs:
  build: 
    ...

  auth-attest:
    needs: [build]
    name: Authentication and Attestation
    permissions:
      contents: read
      packages: write
      # required for authentication to GCP
      id-token: write
      actions: read
      security-events: write
      statuses: write
    uses: kartverket/github-workflows/.github/workflows/post-build-attest.yml@v2.6
    with:
      workload_identity_provider: projects/214581028419/locations/global/workloadIdentityPools/github-runner-deploy-pool/providers/github-provider
      service_account: github-runner-deploy@skip-dev-7d22.iam.gserviceaccount.com
      image_url: ${{needs.build.outputs.image_url}}
```

### Options

| Key                        | Type   | Required | Description                                                                                                                                                                                                                    |
|----------------------------|--------|----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| workload_identity_provider | string | X        | The ID of the provider to use for authentication. It should be in the format of `projects/{{project}}/locations/global/workloadIdentityPools/{{workload_identity_pool_id}}/providers/{{workload_identity_pool_provider_id}}`   |
| service_account            | string | X        | The GCP service account connected to the identity pool that will be used by Terraform.                                                                                                                                         |
| image_url                  | string |          | The Docker image url must be of the form registry/repository@digest.                                                                                                                            |

## run-trivy
TBA
