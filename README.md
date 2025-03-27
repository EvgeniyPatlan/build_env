# Percona Products Build Environment

This repository contains Ansible playbooks and a Dockerfile template for setting up build environments for various Percona products.

## Supported Products and Versions

| Product | Versions       | Description                      |
|---------|---------------|----------------------------------|
| PSMDB    | 60, 70, 80    | Percona Server for MongoDB      |
| PS       | 80, 84, 9.X   | Percona Server for MySQL        |
| PXB      | 80, 84, 90    | Percona XtraBackup              |
| PXC      | 80, 84, 9.X   | Percona XtraDB Cluster          |

## Features

- Ansible playbook to install all necessary build dependencies
- Single Dockerfile template that adapts to different products, versions, and platforms
- **Multi-architecture support** for both amd64 and arm64/aarch64
- Supported platforms:
  - Oracle Linux 8
  - Oracle Linux 9
  - Ubuntu 20.04
  - Ubuntu 22.04
  - Ubuntu 24.04
  - Debian 11
  - Debian 12
- Support for FIPS mode builds

## Directory Structure
