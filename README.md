# [carvis.cloud](https://carvis.cloud)-terraform

[![lint](https://github.com/project-carvis/carvis-terraform/actions/workflows/terraform-lint.yml/badge.svg)](https://github.com/project-carvis/carvis-terraform/actions/workflows/terraform-lint.yml)

## Overview

[Terraform](https://www.terraform.io/) project to setup required AWS infrastructure for [carvis](https://cavis.cloud), which consists of the following components:

- `remote-state` Terraform remote state backend
- `graphql` AWS AppSync GraphQL API backed by DynamoDB
- `backend` Lambda backend to facility CRUD operations to S3

```tree
├── backend
│   └── main.tf
├── graphql
│   └── main.tf
├── remote-state
│   └── main.tf
└── main.tf
```

## Build

### Create Terraform state backend (S3 & DynamoDB)

```bash
  make state
```

### Update dev environment

```bash
  make dev
```

### Update live environment

```bash
  make live
```
