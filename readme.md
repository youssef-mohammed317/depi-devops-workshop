# DEPI DevOps Workshop

A small Flask app used to practice a full DevOps workflow: tests, Docker, Terraform, Ansible, CI quality gates, a container registry, and deployment to AWS EC2.

## Pipeline overview

```
Pull request  ->  tests (pytest)
Merge to main ->  tests -> SonarQube scan -> build & push image to GHCR -> deploy to EC2 -> smoke test
```

## Project structure

```
DEPI-DEVOPS-WORKSHOP/
├── .github/
│   ├── workflows/
│   │   └── ci.yml
│   └── pull_request_template.md
├── ansible/
│   ├── inventory.ini
│   ├── playbook.yml        # bootstrap: install Docker + Compose
│   └── deploy.yml          # deploy the SHA-tagged image
├── app/
│   └── main.py
├── infra/
│   ├── modules/
│   │   └── ec2/
│   └── environments/
│       └── dev/
├── tests/
│   └── test_app.py
├── .dockerignore
├── .env.example
├── .gitignore
├── docker-compose.yaml
├── Dockerfile
├── README.md
├── requirements.txt
└── sonar-project.properties
```

## Endpoints

- `GET /` returns a welcome message
- `GET /health` returns the health status

## Run locally

```bash
pip install -r requirements.txt
python app/main.py
```

Then open http://localhost:5000

## Run tests

```bash
python -m pytest tests/
```

## Run with Docker

```bash
docker build -t depi-flask-app .
docker run -p 5001:5000 depi-flask-app
```

Then open http://localhost:5001

- The container runs as a non-root user (`appuser`).
- The image has a `HEALTHCHECK` that calls `/health`.
- `.dockerignore` keeps tests, caches and Git files out of the image.

## Run with Docker Compose

```bash
docker compose up -d --build   # start
docker compose ps              # check that it is healthy
docker compose down            # stop
```

The Compose file sets a restart policy (`unless-stopped`), maps port 5001 to 5000, and defines a healthcheck.

## Infrastructure with Terraform (AWS EC2)

Creates an Ubuntu EC2 server (latest Ubuntu 22.04 AMI found with a data source), a security group, and prints the public IP. The code is split into a reusable module (`infra/modules/ec2`) and a `dev` environment that uses it.

**Before you start**

- Terraform and the AWS CLI are installed, and `aws configure` is done.
- An SSH key pair already exists in AWS, in the same region as `aws_region`.

**Set your values** in `infra/environments/dev/terraform.tfvars`:

| Variable | Meaning |
|---|---|
| `key_name` | Name of the existing AWS key pair (without `.pem`) |
| `my_ip` | Your public IP with `/32`, for example `203.0.113.25/32` |

**Run**

```bash
cd infra/environments/dev
terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
terraform output public_ip
```

**Security**

- SSH and the app port are open to `my_ip` only.
- The `.pem` key, `*.tfstate`, `.terraform/` and `terraform.tfvars` are not committed (see `.gitignore`).

Clean up when you are done: `terraform destroy`.

## Server setup with Ansible

Installs Docker Engine and the Compose plugin on the new server, enables the Docker service, and creates the deployment directory `/opt/app`. Ansible needs Linux, so on Windows run it from WSL.

1. Put the server's public IP in `ansible/inventory.ini`.
2. Run:

```bash
cd ansible
ansible web -i inventory.ini -m ping
ansible-playbook -i inventory.ini playbook.yml
ansible-playbook -i inventory.ini playbook.yml   # second run
```

The playbook uses variables, a handler (restart Docker only when it was just installed), and idempotent modules. The second run should report `changed=0`.

## CI quality gates

The workflow `.github/workflows/ci.yml` runs on every pull request to `main` and on every push to `main`.

| Step | Pull request | Push to main |
|---|---|---|
| Checkout, set up Python, install, pytest | yes | yes |
| SonarQube scan | no | yes |
| Publish image to GHCR | no | yes |
| Deploy to EC2 | no | yes |

**SonarQube**

- The scan uses the repository secrets `SONAR_TOKEN` and `SONAR_HOST_URL`.
- `sonar-project.properties` sets the project key, the source folders, and `sonar.qualitygate.wait=true`, so the job fails if the quality gate is red.
- SonarQube Community edition analyzes only the `main` branch, which is why the scan does not run on pull requests.

**If SonarQube is unavailable:** the pipeline fails closed. The scan step fails, so the image is not published and nothing is deployed. Re-run the job when SonarQube is back. An admin may override only in an emergency, and the reason must be recorded.

## Publish to GitHub Container Registry

After the checks pass on `main`, the workflow logs in to GHCR with the automatic `GITHUB_TOKEN` and pushes the image with two tags:

- `ghcr.io/youssef-mohammed317/depi-devops-workshop:<first 7 characters of the commit SHA>`
- `ghcr.io/youssef-mohammed317/depi-devops-workshop:latest`

The SHA tag is immutable, so deployments use it. `latest` is only a convenience. The package is public, so it can be pulled without logging in:

```bash
docker pull ghcr.io/youssef-mohammed317/depi-devops-workshop:<sha7>
```

## Deploy to EC2

After the image is published, the `deploy` job runs `ansible/deploy.yml` on the server over SSH:

1. Logs in to GHCR on the server.
2. Writes a `docker-compose.yml` that uses the SHA-tagged image.
3. Runs `docker compose pull` and `docker compose up -d`.
4. Calls `/health` on the server (smoke test). If it fails, the job prints the container logs and fails.

**Repository secrets**

| Secret | Value |
|---|---|
| `SONAR_TOKEN` | SonarQube token |
| `SONAR_HOST_URL` | URL of the SonarQube server |
| `EC2_HOST` | Public IP of the EC2 server |
| `EC2_SSH_KEY` | Contents of the private key (`.pem`) |

The registry credential is the automatic `GITHUB_TOKEN`, so no extra secret is needed.

**Production note:** a long-lived SSH key and an open SSH port are only acceptable for this workshop. In production, use OIDC (short-lived credentials, no stored keys) with AWS Systems Manager (SSM), so port 22 can stay closed.

## Contributing

- Open a Pull Request for every change. A PR template is filled in automatically.
- Run the tests before opening the PR.
- Never commit secrets, `.env`, `.pem` files or Terraform state.
- The `main` branch is protected, so direct pushes are blocked.