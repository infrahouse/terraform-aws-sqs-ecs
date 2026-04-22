# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with
code in this repository.

## First Steps

**Your first tool call in this repository MUST be reading .claude/CODING_STANDARD.md.
Do not read any other files, search, or take any actions until you have read it.**
This contains InfraHouse's comprehensive coding standards for Terraform, Python, and general formatting rules.


## What This Module Does

Terraform module that provisions an SQS queue paired with an ECS service to
run containerized queue consumers. The ECS service auto-scales based on CPU
utilization and SQS backlog depth. EC2 instances (via ASG) host the ECS
tasks, with optional spot instance support.

## Architecture

The root module (`main.tf`) creates the SQS queue, then delegates to two
submodules:

- **`modules/asg`** - EC2 Auto Scaling Group: launch template, instance
  profile, security group, CloudWatch-based CPU scaling. Provides the
  compute capacity for ECS.
- **`modules/ecs`** - ECS cluster, service, task definition, task/execution
  IAM roles, CloudWatch log group, and application auto-scaling (CPU + SQS
  backlog policies).

`locals.tf` contains the core scaling math: it calculates
`tasks_per_instance` from the EC2 instance type's CPU/memory and the task's
resource quotas, then derives ASG and task count min/max values.

`alerts.tf` creates a CloudWatch alarm + SNS topic for SQS message age
monitoring.

## Common Commands

```bash
make bootstrap   # Install Python deps (pytest-infrahouse, infrahouse-core)
make format      # Format Terraform + Python (black) files
make lint        # Check Terraform formatting (runs in pre-commit hook)
make test        # Run pytest suite: pytest -xvvs tests
```

Tests use `pytest-infrahouse` and deploy real AWS infrastructure via
`test_data/sql-ecs/` as the Terraform root. The test assumes an AWS role
(`arn:aws:iam::303467602807:role/sqs-ecs-tester`) and creates actual
resources, so they require AWS credentials and take significant time.

To run a specific test with explicit AWS config:
```bash
pytest -xvvs \
    --aws-region=us-west-2 \
    --test-role-arn="arn:aws:iam::303467602807:role/sqs-ecs-tester" \
    tests/test_module.py
```

Use `--keep-after` to preserve infrastructure after test run (useful for
debugging).

## Versioning

Uses `bump2version` (config in `.bumpversion.cfg`). Version is tracked in
two places: `README.md` (usage example) and `locals.tf` (`module_version`).
Bumping creates a git commit and tag automatically.

## CI/CD

- **CI** (`.github/workflows/terraform-CI.yml`): On PRs, runs `make lint`
  and `make test` against the test AWS account. Terraform version is read
  from `test_data/sql-ecs/.terraform-version`.
- **CD** (`.github/workflows/terraform-CD.yml`): On tag push, publishes
  the module to the InfraHouse registry via `ih-registry upload`.

## Pre-commit Hook

`hooks/pre-commit` runs `make lint` (terraform fmt check). Install with
`make install-hooks`.
