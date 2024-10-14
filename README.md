# About github-workflows

Shared reusable workflows for GitHub Actions.

- [Reusable Workflows](#reusable-workflows)
  - [run-terraform](#run-terraform)
  - [run-security-scans](#run-security-scans)
- [Example usage](#example-usage)
  - [Ideal Use of Reusable Workflows](#ideal-use-of-reusable-workflows)
  - [Deploy on workflow dispatch](#deploy-on-workflow-dispatch)
- [Tips and Tricks](#tips-and-tricks)
  - [Using outputs](#using-outputs)
  - [Passing env vars to reusable workflows](#passing-env-vars-to-reusable-workflows)
  - [Passing secrets to reusable workflows](#passing-secrets-to-reusable-workflows)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

---

---

# Reusable Workflows

We currently have 4 reusable workflows (i.e. [run-terraform](#run-terraform) and [run-security-scans (DEPRECATED)](#run-security-scans)) available for use.

See [Ideal Use of Workflows](#ideal-use-of-reusable-workflows) for an example of how to optimally use all 3 workflows together.

See [Tips and Tricks](#tips-and-tricks) for supporting information regarding usage of the reusable workflows.

<br/>

## run-kubectl

Allows running kubectl commands against a Kubernetes cluster. This is useful for doing restarts of deployments for example.


### Features

- Connects to a google cluster as a deploy service account
- Will always use connect gateway
- Runs specified kubectl commands against the cluster

### Requirements

- Your gcp project is set up and given required permissions in skip-core-infrastructure and gcp-service-accounts


### Example

Example usage in `.github/workflows/auto-merge.yml`:
```yaml
name: Restart deployment
on: pull_request_target

jobs:
  sandbox:
    name: restart-app
    uses: kartverket/github-workflows/.github/workflows/run-kubectl.yaml@latest
    with:
      cluster_name: atkv1-dev
      service_account: mygcp-project-deploy@mygcp-project.iam.gserviceaccount.com
      kubernetes_project_id: kube-dev-4329023
      kubernetes_project_number: 43290432893
      namespace: default
      command: |
        restart deployment my-deployment
```
### Inputs

| Key                   | Type             | Required | Description                                                                                                                         |
|-----------------------|------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------|
| cluster_name          | string           | X        | Cluster name. Found with `gcloud container fleet memberships list`                                                                  |
| service_account       | string           | X        | The projects deploy service account in full format.                                                                                 |
| kubernetes_project_id | string           | X        | The kubernetes GCP project id.                                                                                                      |
| project_number        | string           | X        | A 12-digit number used as a unique identifier for the product project.                                                              |
| namespace             | string           | X        | which namespace to execute the command in                                                                                           |
| kubectl_version       | string           | X        | which kubectl version to use. format: v1.30.0. latest stable is default                                                             |
| commands              | multiline string | X        | The kubectl commands you want to run, exclude `kubectl`. example: https://skip.kartverket.no/docs/github-actions/kubectl-fra-github |

## auto-merge-dependabot

Allows auto-merging dependabot PRs that match given patterns. Useful when you are drowning in PRs and have built up trust in a set of dependencies that release often and never break. It's recommended to have a sane CI setup so that anything merged to main at least passes CI tests before going into prod

### Features

- Allows configuring a set of dependencies in a configfile that can be merged
- Each dependency will allow either major, minor or patch updates (only supports semver)
- A bot approves and merges the PR

### Requirements

A few requirements are necessary in order to make this work in addition to the example below. 

1. Legacy branch protection rules are not supported. Your repo needs to use the more modern branch rulesets
2. The Octo STS app needs to be added to the rulesets bypass list so that it can merge the PR
3. A trust file called `.github/chainguard/auto-update.sts.yaml` needs to exist to allow the workflow to get a valid GitHub token

### Example

Example usage in `.github/workflows/auto-merge.yml`:
```yaml
name: Dependabot auto-merge
on: pull_request_target

jobs:
  auto-merge-dependabot:
    permissions:
      id-token: write
      contents: write
      pull-requests: write
    uses: kartverket/github-workflows/.github/workflows/auto-merge-dependabot.yml@<release tag>
```

Example configfile in `.github/auto-update.json`:
```json
[{
  "match": {
    "dependency_name": "hashicorp/google",
    "update_type": "semver:minor"
  }
}, {
  "match": {
    "dependency_name": "hashicorp/google-beta",
    "update_type": "semver:minor"
  }
}]
```

Example STS trust file in `.github/chainguard/auto-update.sts.yaml`:
```yaml
issuer: https://token.actions.githubusercontent.com
subject: repo:kartverket/gcp-service-accounts:pull_request

permissions:
  contents: write
  pull_requests: write
```

### Inputs

The configfile is currently the only input. The configfile at `.github/auto-merge.json` supports the following values:

| Key                        | Type   | Required | Description                                                                                                                                                                                |
|----------------------------|--------|----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `[].match.dependency_name` | string | true     | The name of the dependency as it appears on the Dependabot PR                                                                                                                              |
| `[].match.update_type`     | string | true     | Which changes should be merged. Currently supports `semver:patch`, `semver:minor` and `semver:major`. The type includes all lower tiers, for example `semver:minor` includes patch changes |

## run-terraform

This workflow plans and applies Terraform config to deploy to an environment.

### Features

- Logs in to GCP and Kubernetes automatically with [Workload Identity Federation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- Posts comments with relevant information to Pull Requests
- Runs validate, format and plan to verify deployment follows conventions before running apply
- Posts summaries on relevant steps on the Action pipeline view to improve visibility
- Supports manual approval and delay periods in deploy using [GitHub Environments protection rules](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment#environment-protection-rules)
- Re-uses plan from plan step in apply step to ensure apply always executes the diff generated by plan no matter when it is run
- Prevents deploys running in parallel against the same environment crashing due to failing to acquire state lock
- Allows for the choice of deploying and/or destroying terraform config
- Will only deploy on push or workflow_dispatch event to main by default. Can be configured to deploy on a different branch using the `deploy_on` input.

### Example

```yaml
jobs:
  build:
  # Builds an image of the format <registry>/<repository>:<tag> or <registry>/<repository>@<digest>
  # and pushes it to the github registry.
  # See 'All Workflows Together' section for an example build job.

  dev:
    needs: [build]
    name: Deploy to dev
    permissions:
      # For logging on to Vault, GCP
      id-token: write
      # For writing comments on PR
      pull-requests: write
      # For fetching git repo
      contents: read
      # For accessing repository
      packages: write
    uses: kartverket/github-workflows/.github/workflows/run-terraform.yml@<release tag>
    with:
      runner: ubuntu-latest
      environment: dev
      kubernetes_cluster: atkv1-dev
      terraform_workspace: dev
      terraform_option_1: -var-file=dev.tfvars
      terraform_option_2: -var=image=${{ needs.build.outputs.image_url}}
      terraform_init_option_1: -backend-config=dev.gcs.tfbackend
      working_directory: terraform
      auth_project_number: "123456789123"
      service_account: sa-name@project-dev-123.iam.gserviceaccount.com
      project_id: project-dev-123
      destroy: <optional boolean>
      unlock: <optional LOCK_ID>

  test:
    needs: [build, dev]
    # approximately the same as 'dev' but for the test environment

  prod:
    needs: [build, dev, test]
    # approximately the same as 'dev' but for the prod environment
```

### Inputs

| Key                                 | Type    | Required | Description                                                                                                                                                                                                                                                                                                                   |
|-------------------------------------|---------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| service_account                     | string  | X        | The GCP service account connected to the identity pool that will be used by Terraform. Service account and auth_project_number environment must coincide.                                                                                                                                                                     |
| auth_project_number                 | string  | X        | The GCP Project Number used as the active project. A 12-digit number used as a unique identifier for the project. Used to find workload identity pool. Project number and SA environment must coincide                                                                                                                        |
| workload_identity_provider_override | string  |          | The ID of the provider to use for authentication. Only used for overriding the default workload identity provider based on project number. It should be in the format of `projects/{{project_number}}/locations/global/workloadIdentityPools/{{workload_identity_pool_id}}/providers/{{workload_identity_pool_provider_id}}`. |
| runner                              | string  | X        | The GitHub runner to use when running the deploy. This can for example be `ubuntu-latest`.                                                                                                                                                                                                                                    |
| deploy_on                           | string  |          | Which branch will be the only branch allowed to deploy. This defaults to the main branch so that other branches only run check and plan. Defaults to `refs/heads/main`.                                                                                                                                                       |
| working_directory                   | string  |          | The directory in which to run terraform, i.e. where the Terraform files are placed. The path is relative to the root of the repository.                                                                                                                                                                                       |
| project_id                          | string  |          | The GCP Project ID to use as the "active project" when running Terraform. When deploying to Kubernetes, this must match the project in which the Kubernetes cluster is registered.                                                                                                                                            |
| kubernetes_cluster                  | string  |          | An optional kubernetes cluster to authenticate to. Note that the project_id must match where the cluster is registered.                                                                                                                                                                                                       |
| environment                         | string  |          | The GitHub environment to use when deploying. See [using environments for deployment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) for more info on this.                                                                                                |
| terraform_workspace                 | string  |          | When provided will set a workspace as the active workspace when planning and deploying.                                                                                                                                                                                                                                       |
| terraform_option_X                  | string  |          | An additional terraform option to be passed to plan and apply. For example `-var-file=dev.tfvars` and `-var=<variableName>=<variableValue>`. X may be an integer between 1-3, which allows at most 3 options.                                                                                                                 |
| terraform_init_option_Y             | string  |          | An additional config to be passed to terraform init. For example `-backend-config=dev.gcs.tfbackend`. Y may be an integer between 1-3, which allows at most 3 init options.                                                                                                                                                   |
| add_comment_on_pr                   | boolean |          | Setting this to `false` disables the creation of comments with info of the Terraform run on Pull Requests. When `true` the `pull-request` permission is required to be set to `write`. Defaults to `true`.                                                                                                                    |
| destroy                             | boolean |          | An optional boolean that determines whether terraform will be destroyed. Defaults to 'false'.                                                                                                                                                                                                                                 |
| unlock                              | string  |          | An optional string which runs terraform force-unlock on the provided `LOCK_ID`, if set.                                                                                                                                                                                                                                       |

<br />

## run-security-scans

### _DEPRECATED: THIS WORKFLOW IS DEPRECATED AND WILL NOT RECEIVE FURTHER UPDATES. PLEASE CHECK OUT [Pharos](https://github.com/kartverket/pharos/) FOR SECURITY SCANS_

This workflow runs security scans on a repository.
Note, in order to not limit/interfere with the development process, the scans do not run on draft pull requests.
Additionally, if image_url is not supplied Trivy scan will not be performed (i.e. only TFSec scan will run).

### Features

- Runs TFSec, a static analysis security scanner for your Terraform code. Does not run on draft pull requests.
- Runs Trivy, a comprehensive security scanner. Does not run on draft pull requests.
- Calls the GitHub Security Code Scanning API and fails workflow if there are any _high_ or _critical_ errors.
- The above step can be configured by specifying the `allow_severity_level` input parameter.

### Requirements

- Code Scanning must be appropriately set up in the Github Security tab.
- Note that the image built during your build-job must be pushed to the registry on all but draft PRs for the workflow to work as intended (see example build job below, paying extra attention to lines following `# Note: ...`)

### Example

```yaml
jobs:
  build:
    # Builds an image of the format <registry>/<repository>:<tag> or <registry>/<repository>@<digest>
  # and pushes it to the github registry. This is the image that must be used in all following jobs.
  # See 'All Workflows Together' section for an example build job.

  security-scans:
    needs: [build]
    name: Security Scans
    permissions:
      # For fetching git repo
      contents: read
      # For accessing repository
      packages: write
      # required for authentication to GCP
      id-token: write
      actions: read
      security-events: write
    uses: kartverket/github-workflows/.github/workflows/run-security-scans.yml@<release tag>
    with:
      auth_project_number: "123456789123"
      service_account: sa-name@project-dev-123.iam.gserviceaccount.com
      image_url: <registry>/<repository>:<tag> or <registry>/<repository>@<digest> # the image created by build job
      trivy: true # default true, optional
      tfsec: true # default true, optional
      allow_severity_level: medium

  dev:
    needs: [build]
    # call to run-terraform.yml for dev environment with build image

  test:
    needs: [build, dev]
    # call to run-terraform.yml for test environment with build image

  prod:
    needs: [build, dev, test, security-scans]
    # call to run-terraform.yml for prod environment only after security-scans job, with build image
```

### Inputs

| Key                                 | Type    | Required | Description                                                                                                                                                                                                                                                                                                                   |
|-------------------------------------|---------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| auth_project_number                 | string  | X        | The GCP Project Number used as the active project. A 12-digit number used as a unique identifier for the project. Used to find workload identity pool. This project should be your dev environment project, as this is the environment where the attestors are located                                                        |
| workload_identity_provider_override | string  |          | The ID of the provider to use for authentication. Only used for overriding the default workload identity provider based on project number. It should be in the format of `projects/{{project_number}}/locations/global/workloadIdentityPools/{{workload_identity_pool_id}}/providers/{{workload_identity_pool_provider_id}}`. |
| service_account                     | string  | X        | The GCP service account connected to the identity pool that will be used by Terraform. Should be the dev environment deploy service account                                                                                                                                                                                   |
| image_url                           | string  |          | The Docker image url must be of the form `registry/repository:tag` or `registry/repository@digest` for run-security-scans. It is not required; however, in order to run Trivy and aquire attestations an image_url must be supplied.                                                                                          |
| trivy                               | boolean |          | An optional boolean that determines whether trivy-scan will be run. Defaults to 'true'.                                                                                                                                                                                                                                       |
| tfsec                               | boolean |          | An optional boolean that determines whether tfsec-scan will be run. Defaults to 'true'.                                                                                                                                                                                                                                       |
| allow_severity_level                | string  |          | A string which determines the highest level of severity the security scans can find while still succeeding workflows. Only "medium", "high" and "critical" values are allowed. Note that these values are case sensitive.                                                                                                     |

<br/>

# Example Usage

Below are examples of how to use the reusable workflows for different scenarios

## Ideal Use of Reusable Workflows

The following is an example of how to use run-terraform and run-security-scans together to deploy to dev, test and prod environments.
Note the use of `jobs.<job_id>.needs` to specify the order in which jobs run.
For details on how to use `jobs.<job_id>.outputs` see [Using outputs](#using-outputs).

```yaml
name: "Ideal" workflow

# The workflow runs when (1) there is a push to the 'main' branch or (2) there is a push to a pull request onto main branch
on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main
  workflow_dispatch:

jobs:
  build:
    # Example of how to build an image and supply appropriate inputs to run-security-scans reusable workflow
    # Note outputs derived in the setOutput step and 'tags' set in the meta step
    name: Build Docker Image
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    outputs:
      image_url: ${{ steps.setOutput.outputs.image_url }}
      image_tag_url: ${{ steps.setOutput.outputs.image_tag_url }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v3

      # Sets tag 'latest' for images built on main/master branch and tag 'prebuild-temp' on all other image builds
      - name: Set tag
        id: set-tag
        env:
          BRANCH: ${{ github.ref_name }}
        run: |
          if [[ "$BRANCH" == "main" || "$BRANCH" == "master" ]]; then
            echo "image_tag=latest" >> $GITHUB_OUTPUT
          else
            echo "image_tag=prebuild-temp" >> $GITHUB_OUTPUT
          fi

      # Login against a Docker registry except on draft-PR
      # https://github.com/docker/login-action
      - name: Log into registry ${{ env.REGISTRY }}
        if: github.event.pull_request.draft == false
        uses: docker/login-action@<version>
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      # Extract metadata (tags, labels) for Docker
      # https://github.com/docker/metadata-action
      - name: Extract Docker metadata
        id: meta
        uses: docker/metadata-action@<version>
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          # Note: checkout https://github.com/docker/metadata-action#tags-input for tag format options
          tags: |
            type=sha,format=long
            type=raw,value=${{ steps.set-tag.outputs.image_tag }}

      # Build and push Docker image with Buildx (don't push on PR)
      # https://github.com/docker/build-push-action
      - name: Build and push Docker image
        id: build-docker
        uses: docker/build-push-action@<version>
        with:
          context: .
          # Note: The image must be pushed to registry in all cases except for draft PRs
          push: ${{ !github.event.pull_request.draft }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

      - name: Set output with build values
        id: setOutput
        # Note: The image url is output in both `registry/repository:tag` and `registry/repository@digest` formats
        run: |
          echo "image_url=${{ env.REGISTRY }}/${{ github.repository }}@${{ steps.build-docker.outputs.digest }}" >> $GITHUB_OUTPUT
          echo "image_tag_url=${{ env.REGISTRY }}/${{ github.repository }}:${{ steps.meta.outputs.version }}" >> $GITHUB_OUTPUT

  security-scans:
    needs: [build]
    name: Security Scans
    permissions:
      contents: read
      packages: write
      # required for authentication to GCP
      id-token: write
      actions: read
      security-events: write
    uses: kartverket/github-workflows/.github/workflows/run-security-scans.yml@<release tag>
    with:
      auth_project_number: "123456789123"
      service_account: sa-name@project-dev-123.iam.gserviceaccount.com
      image_url: ${{ needs.build.outputs.image_tag_url}}

  dev:
    needs: [security-scans]
    name: Deploy to dev
    permissions:
      # For logging on to Vault, GCP
      id-token: write
      # For writing comments on PR
      pull-requests: write
      # For fetching git repo
      contents: read
      # For accessing repository
      packages: write
    uses: kartverket/github-workflows/.github/workflows/run-terraform.yml@<release tag>
    with:
      runner: ubuntu-latest
      environment: dev
      kubernetes_cluster: atkv1-dev
      terraform_workspace: dev
      terraform_option_1: -var-file=dev.tfvars
      terraform_option_2: -var=image=${{ needs.build.outputs.image_url}}
      terraform_init_option_1: -backend-config=dev.gcs.tfbackend
      working_directory: terraform
      auth_project_number: "123456789123"
      service_account: sa-name@project-dev-123.iam.gserviceaccount.com
      project_id: project-dev-123

  test:
    needs: [dev]
    name: Deploy to test
    permissions:
      # For logging on to Vault, GCP
      id-token: write
      # For writing comments on PR
      pull-requests: write
      # For fetching git repo
      contents: read
      # For accessing repository
      packages: write
    uses: kartverket/github-workflows/.github/workflows/run-terraform.yml@<release tag>
    with:
      runner: ubuntu-latest
      environment: test
      kubernetes_cluster: atkv1-test
      terraform_workspace: test
      terraform_option_1: -var-file=test.tfvars
      terraform_option_2: -var=image=${{ needs.build.outputs.image_url}}
      terraform_init_option_1: -backend-config=test.gcs.tfbackend
      working_directory: terraform
      auth_project_number: "123456789123"
      service_account: sa-name@project-test-123.iam.gserviceaccount.com
      project_id: project-test-123

  prod:
    needs: [build, dev, test, security-scans]
    name: Deploy to prod
    permissions:
      # For logging on to Vault, GCP
      id-token: write
      # For writing comments on PR
      pull-requests: write
      # For fetching git repo
      contents: read
      # For accessing repository
      packages: write
    uses: kartverket/github-workflows/.github/workflows/run-terraform.yml@<release tag>
    with:
      runner: ubuntu-latest
      environment: prod
      kubernetes_cluster: atkv1-prod
      terraform_workspace: prod
      terraform_option_1: -var-file=prod.tfvars
      terraform_option_2: -var=image=${{ needs.build.outputs.image_url}}
      terraform_init_option_1: -backend-config=prod.gcs.tfbackend
      working_directory: terraform
      auth_project_number: "123456789123"
      service_account: sa-name@project-prod-123.iam.gserviceaccount.com
      project_id: project-prod-123
```

## Deploy on workflow dispatch

If you want to deploy a selected branch to the dev-environment on workflow dispatch.
You will need to take care not to interfere with others working in the same repo/environment.
Note that the `deploy_on` input is set to `${{ github.ref }}` and that the only `on` specified is `workflow_dispatch`

```yaml
name: Deploy to dev on workflow dispatch
on: workflow_dispatch

jobs:
  build:
    # Builds an image of the format <registry>/<repository>:<tag> or <registry>/<repository>@<digest>
    # and pushes it to the github registry. This is the image that must be used in all following jobs.
    # See 'Using outputs' section for suggestions on how to do this.

  security-scans:
    needs: [build]
    # call to run-security-scans.yml with build image

  dev:
    name: Deploy to dev
    needs: [security-scans]
    permissions:
      # For logging on to Vault, GCP
      id-token: write
      # For writing comments on PR
      pull-requests: write
      # For fetching git repo
      contents: read
      # For accessing repository
      packages: write
    uses: kartverket/github-workflows/.github/workflows/run-terraform.yml@<release tag>
    with:
      runner: ubuntu-latest
      environment: dev
      kubernetes_cluster: atkv1-dev
      terraform_workspace: dev
      terraform_option_1: -var-file=dev.tfvars -var=image=${{ needs.build.outputs.image_url}}
      terraform_init_option_1: -backend-config=dev.gcs.tfbackend
      working_directory: terraform
      auth_project_number: "123456789123"
      service_account: sa-name@project-dev-123.iam.gserviceaccount.com
      project_id: project-dev-123
      deploy_on: ${{ github.ref }}
```

<br/>

# Tips and Tricks

Helpful "tips and tricks" for using the reusable workflows can be found below.

## Using needs

If you want jobs to run in a particular order:

> Use `jobs.<job_id>.needs` to identify any jobs that must complete successfully before this job will run. [[2](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idneeds)]

See [Github Doc: jobs.<job_id>.needs](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#jobsjob_idneeds)

## Using outputs

If you want to use outputs from one job in some following job:

> You can use `jobs.<job_id>.outputs` to create a map of outputs for a job. Job outputs are available to all downstream jobs that depend on this job. [[1](https://docs.github.com/en/actions/using-jobs/defining-outputs-for-jobs)]

See [Github Doc: Defining outputs for jobs](https://docs.github.com/en/actions/using-jobs/defining-outputs-for-jobs) for more information.

## Passing env vars to reusable workflows

If you want to use environment variables, passing them to a reusable workflow is
a little tricky as this behavior is not currently supported by GitHub.
This is a [requested feature](https://github.community/t/passing-environment-variables-to-reusable-workflow/230456/4).
The current workaround for this is to use a setup-job to consume env vars and
provide an output that can be mapped to the arguments of the job.

<details>
<summary>Click here to see an example of this</summary>
<code><pre>env:
  AUTH_PROJECT_NUMBER: "123456789123"
  SERVICE_ACCOUNT: sa-name@project-name-123.iam.gserviceaccount.com
  PROJECT_ID: project-name-123
jobs:
  setup-env:
    runs-on: ubuntu-latest
    outputs:
      auth_project_number: ${{ steps.set-output.outputs.auth_project_number }}
      service_account: ${{ steps.set-output.outputs.service_account }}
      project_id: ${{ steps.set-output.outputs.project_id }}
    steps:
      - name: set outputs with default values
        id: set-output
        run: |
          echo "auth_project_number=${{ env.AUTH_PROJECT_NUMBER }}" >> $GITHUB_OUTPUT
          echo "service_account=${{ env.SERVICE_ACCOUNT }}" >> $GITHUB_OUTPUT
          echo "project_id=${{ env.PROJECT_ID }}" >> $GITHUB_OUTPUT
  dev:
    name: Deploy to dev
    needs: setup-env
    permissions:
      id-token: write
      contents: read
      pull-requests: write
      packages: write
    uses: kartverket/github-workflows/.github/workflows/run-terraform.yml@v2.1
    with:
      runner: ubuntu-latest
      environment: dev
      kubernetes_cluster: atkv1-dev
      terraform_workspace: dev
      terraform_option_1: -var-file=dev.tfvars -var=image=<registry>/<repository>:<tag> or <registry>/<repository>@<digest>
      working_directory: terraform
      auth_project_number: ${{ needs.setup-env.outputs.auth_project_number }}
      service_account: ${{ needs.setup-env.outputs.service_account }}
      project_id: ${{ needs.setup-env.outputs.project_id }}</pre></code>
</details>
<br />

## Passing secrets to reusable workflows

Secrets should be administered through Google Secret Manager and thus there is no explicit
support for taking GitHub secrets into the action. GitHub will also stop you
from sending secrets as arguments using the `with` argument, so this will not
work either.

<br />

# Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md).
If you experience and fix an issue that isn't mentioned there, feel free to add it.

<br />

# Contributing

Get in touch with SKIP if you have any contribution suggestions, and feel free to create a pull-request.
