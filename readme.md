# DEPI DevOps Workshop

A small Flask app used to practice a complete DevOps workflow: automated tests, Docker, Terraform, Ansible, CI quality gates, a container registry, continuous deployment to AWS EC2, hardening and rollback.

## Pipeline overview

```
Pull request   ->  checkout -> Python -> install -> pytest
Merge to main  ->  pytest -> SonarQube scan -> build & push image (GHCR) -> deploy to EC2 (Ansible + Compose) -> smoke test
```

| Area | Tools |
|---|---|
| Application | Python, Flask, pytest |
| Containers | Docker, Docker Compose |
| Infrastructure | Terraform (AWS EC2, security group) |
| Configuration | Ansible |
| CI/CD | GitHub Actions |
| Code quality | SonarQube |
| Registry | GitHub Container Registry (GHCR) |

## Project structure

```
DEPI-DEVOPS-WORKSHOP/
├── .github/
│   ├── workflows/
│   │   └── ci.yml                  # CI + publish + deploy
│   └── pull_request_template.md
├── ansible/
│   ├── inventory.ini
│   ├── playbook.yml                # bootstrap: install Docker + Compose
│   └── deploy.yml                  # deploy the SHA-tagged image + smoke test
├── app/
│   └── main.py
├── infra/
│   ├── modules/
│   │   └── ec2/                    # reusable EC2 module
│   └── envs/
│       └── dev/                    # dev environment
├── sonarqube/
│   ├── compose.yaml                # local SonarQube server (Docker Compose)
│   └── .env.example
├── tests/
│   └── test_app.py
├── .dockerignore
├── .gitignore
├── compose.yaml                    # the Flask app
├── Dockerfile
├── README.md
├── requirements.txt
└── sonar-project.properties
```

## Application

| Endpoint | Description |
|---|---|
| `GET /` | Returns a welcome message |
| `GET /health` | Returns the health status (HTTP 500 when `BREAK_HEALTH=1`, used for the failure demo) |

### Run locally

```bash
pip install -r requirements.txt
python app/main.py
```

Open http://localhost:5000

### Run the tests

```bash
python -m pytest tests/
```

## Docker

```bash
docker build -t depi-flask-app .
docker run -p 5001:5000 depi-flask-app
```

Open http://localhost:5001

- The container runs as a non-root user (`appuser`).
- The image defines a `HEALTHCHECK` that calls `/health`.
- `.dockerignore` keeps tests, caches and Git files out of the image.
- Dependencies are pinned in `requirements.txt`.

## Docker Compose

```bash
docker compose up -d --build   # start
docker compose ps              # status should become "healthy"
docker compose down            # stop
```

`compose.yaml` sets a restart policy (`unless-stopped`), maps port 5001 to 5000, and defines a healthcheck.

## Infrastructure with Terraform

Creates an Ubuntu EC2 server and a security group, and prints the public IP. The Ubuntu AMI is found with a data source, so the latest image is always used. The code is a reusable module (`infra/modules/ec2`) plus a `dev` environment (`infra/envs/dev`) that supplies the values.

**Prerequisites**

- Terraform and the AWS CLI are installed, and `aws configure` is done.
- An SSH key pair already exists in AWS, in the same region as `aws_region`.

**Set your values** in `infra/envs/dev/terraform.tfvars` (not committed):

| Variable | Meaning |
|---|---|
| `key_name` | Name of the existing AWS key pair, without `.pem` |
| `my_ip` | Your public IP with `/32`, for example `203.0.113.25/32` |
| `aws_region` | Region of the key pair (default set in `variables.tf`) |

**Run**

```bash
cd infra/envs/dev
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform output public_ip
```

**Security group**

| Port | Open to | Why |
|---|---|---|
| 22 (SSH) | `0.0.0.0/0`, key login only | GitHub-hosted runners have changing IPs, so CD needs SSH reachable. Workshop only, see the production note below. |
| 5000 (app) | nobody | The container is bound to `127.0.0.1`. Access is through SSH or a reverse proxy. |

State files, `.terraform/`, `terraform.tfvars` and `.pem` keys are never committed.

## Server setup with Ansible

`ansible/playbook.yml` installs Docker Engine and the Compose plugin, makes sure the Docker service is enabled, adds the user to the `docker` group, and creates the deployment directory `/opt/app`. It uses variables, a handler (restart Docker only when it was just installed) and idempotent modules.

Ansible needs Linux, so on Windows run it from WSL.

```bash
cd ansible
# put the server IP in inventory.ini first
ansible web -i inventory.ini -m ping
ansible-playbook -i inventory.ini playbook.yml
ansible-playbook -i inventory.ini playbook.yml   # second run: changed=0
```

## CI quality gates

`.github/workflows/ci.yml` runs on every pull request to `main` and on every push to `main`.

| Job / step | Pull request | Push to main |
|---|---|---|
| Checkout, set up Python, install, pytest | yes | yes |
| SonarQube scan | no | yes |
| Publish image to GHCR | no | yes |
| Deploy to EC2 | no | yes |

**SonarQube**

- The scan uses the secrets `SONAR_TOKEN` and `SONAR_HOST_URL`. The server URL must be reachable from GitHub (`localhost` does not work, because the runner is a different machine).
- `sonar-project.properties` defines the project key, the source folders and `sonar.qualitygate.wait=true`, so the job fails when the quality gate is red.
- The Community edition analyzes only the `main` branch, so the scan runs after the merge.
- A local server can be started with `docker compose up -d` inside `sonarqube/`.

**If SonarQube is unavailable, the pipeline fails closed.** The scan step fails, so the image is not published and nothing is deployed. The job is re-run when the server is back. An emergency override is allowed only for an admin and must be recorded with a reason.

## Container registry (GHCR)

After the checks pass on `main`, the workflow logs in with the automatic `GITHUB_TOKEN` and pushes two tags:

- `ghcr.io/youssef-mohammed317/depi-devops-workshop:<first 7 characters of the commit SHA>`
- `ghcr.io/youssef-mohammed317/depi-devops-workshop:latest`

The SHA tag is immutable, so deployments always use it. `latest` is only a convenience. The package is public, so no login is needed to pull it:

```bash
docker pull ghcr.io/youssef-mohammed317/depi-devops-workshop:<sha7>
```

## Continuous deployment to EC2

The `deploy` job runs after the image is published. It installs Ansible, writes the SSH key from a secret, and runs `ansible/deploy.yml`:

1. Logs in to GHCR on the server (only when a token is provided).
2. Writes `/opt/app/docker-compose.yml` that uses the SHA-tagged image.
3. Runs `docker compose pull` and `docker compose up -d` to recreate the service.
4. Calls `/health` on the server (smoke test), retrying for about 30 seconds.
5. If the smoke test fails, prints the container logs and fails the workflow.

**Repository secrets**

| Secret | Value |
|---|---|
| `SONAR_TOKEN` | SonarQube token |
| `SONAR_HOST_URL` | URL of the SonarQube server, reachable from GitHub |
| `EC2_HOST` | Public IP of the EC2 server |
| `EC2_SSH_KEY` | Full contents of the private key (`.pem`) |

The registry credential is the automatic `GITHUB_TOKEN`, so no extra secret is needed.

**Production note.** A long-lived SSH key and an open SSH port are acceptable only for this workshop. In production, use OIDC (short-lived credentials, no stored keys) together with AWS Systems Manager (SSM), so port 22 can stay closed.

## Hardening and recovery

### Hardening

- The app port is bound to `127.0.0.1` on the server, so the app is not exposed publicly.
- The container runs with a read-only filesystem (`/tmp` is a tmpfs), all Linux capabilities dropped (`cap_drop: ALL`) and `no-new-privileges`.
- The container runs as a non-root user, and Flask debug mode is off.

### Reverse proxy and TLS design (not implemented, no domain available)

```
Internet --HTTPS 443--> Nginx or an AWS load balancer (TLS certificate)
                            --HTTP--> app container (private network, port not published)
```

Only ports 80 and 443 would be open in the security group, and port 80 would redirect to 443. The certificate would come from Let's Encrypt (Nginx) or AWS Certificate Manager (load balancer).

### Failed rollout simulation

Setting `BREAK_HEALTH=1` makes `/health` return HTTP 500. Deploying with it fails the smoke test, prints the container logs, and ends the playbook with an error:

```bash
cd ansible
export IMAGE_NAME=ghcr.io/youssef-mohammed317/depi-devops-workshop
export IMAGE_TAG=<sha7>
ansible-playbook -i inventory.ini deploy.yml -e break_health=1
```

### Rollback to the last known-good image

1. Find the last known-good SHA: the tag of the previous healthy deployment, shown on the GHCR package page or in an older successful workflow run.
2. Deploy that tag again:

```bash
export IMAGE_TAG=<known-good-sha7>
ansible-playbook -i inventory.ini deploy.yml
```

3. Confirm with `ssh ... "docker ps"` that the image tag is the old SHA and the status is `healthy`.

Alternative: in the GitHub Actions tab, open an older successful run on `main` and choose **Re-run all jobs**. It rebuilds and redeploys that commit.

Last known-good SHA at the time of writing: `9f0592c`.

## Verification checklist

| Check | Command or place | Expected |
|---|---|---|
| Tests | `python -m pytest tests/` | all pass |
| Terraform | `terraform validate` | configuration is valid |
| Ansible idempotence | run `playbook.yml` twice | second run `changed=0` |
| Pipeline | GitHub Actions tab | all jobs green on `main` |
| Running version | `ssh ... "docker ps"` | image tag equals the commit SHA, status `healthy` |
| Hardening | `docker inspect app-web-1 --format '{{.HostConfig.ReadonlyRootfs}} {{.HostConfig.CapDrop}}'` | `true [ALL]` |
| No public port | `curl http://<ec2-ip>:5000/health` from outside | fails or times out |

## Troubleshooting

| Problem | Cause and fix |
|---|---|
| Browser refuses port 6000 (`ERR_UNSAFE_PORT`) | Browsers block some ports. Use 5001 or 8080. |
| `ports are not available` | The host port is taken. Pick another host port or stop the other container. |
| `InvalidKeyPair.NotFound` | The key pair is in a different region than `aws_region`. |
| SSH `Connection timed out` | The server is still starting, or the security group does not allow your IP. |
| SSH `UNPROTECTED PRIVATE KEY FILE` (Windows) | Run `icacls <key> /inheritance:r` then `icacls <key> /grant:r "$($env:USERNAME):(R)"`. |
| SonarQube `Failed to query server version` | `SONAR_HOST_URL` is not reachable from GitHub (for example `localhost`). |
| `publish` or `deploy` job skipped | An earlier job failed. Open it and fix that first. |
| Ansible not found on Windows | Ansible runs on Linux. Use WSL. |

## Contributing and Git workflow

- Work on a branch and open a Pull Request. A PR template is filled in automatically.
- Run the tests before opening the PR, and merge only when the check is green.
- Never commit secrets, `.env`, `.pem` files, `terraform.tfvars` or Terraform state.
- The `main` branch is protected, so direct pushes are blocked.

## Cleanup

When the work is finished and evidence is saved:

```bash
cd infra/envs/dev
terraform destroy          # removes the EC2 server and the security group
```

Then stop local services (`docker compose down` in `sonarqube/`), delete local copies of the `.pem` key, and revoke tokens that are no longer needed.