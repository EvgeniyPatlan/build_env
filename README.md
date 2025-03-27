# Percona Products Build Environment

A repository containing Ansible playbooks and Dockerfile templates for setting up build environments for various Percona products.

## Supported Products

| Product | Name                       | Versions    |
|---------|----------------------------|-------------|
| PSMDB    | Percona Server for MongoDB | 60, 70, 80  |
| PS       | Percona Server for MySQL   | 80, 84, 9X  |
| PXB      | Percona XtraBackup         | 80, 84, 90  |
| PXC      | Percona XtraDB Cluster     | 80, 84, 9X  |

## Features

- Ansible playbooks for installing all necessary build dependencies
- Single Dockerfile template adaptable to different products, versions, and platforms
- Multi-architecture support (amd64 and arm64/aarch64)
- FIPS mode builds support

## Supported Platforms

- Oracle Linux 8/9
- Ubuntu 20.04/22.04/24.04
- Debian 11/12

## Directory Structure

```
percona-build-env/
├── ansible/                   # Ansible playbooks and configuration
│   ├── common/                # Common task files
│   ├── config/                # Ansible config and hosts file
│   ├── psmdb/                 # MongoDB-specific playbooks
│   ├── ps/                    # MySQL-specific playbooks
│   ├── pxb/                   # XtraBackup-specific playbooks
│   └── pxc/                   # XtraDB Cluster-specific playbooks
├── Dockerfile.template        # Template Dockerfile for all products/platforms
├── build-images.sh            # Script to build Docker images
├── run-local-setup.sh         # Script to run Ansible locally
└── README.md                  # Documentation
```

## Usage

### Local Setup (Using Ansible)

```bash
# Clone the repository
git clone https://github.com/EvgeniyPatlan/build_env.git
cd build_env

# Run the local setup script for a specific product and version
./run-local-setup.sh --product PSMDB --version 70

# With FIPS mode enabled
./run-local-setup.sh --product PSMDB --version 70 --fips
```

### Docker Images

#### Building Multi-Architecture Images

```bash
# Build all images for a specific product
./build-images.sh --product PSMDB --version 70 --push

# Build for specific platforms
./build-images.sh --product PSMDB --version 70 --push ol8 ubuntu2204

# With FIPS mode enabled
./build-images.sh --product PS --version 80 --push --fips

# Build for a specific architecture only
./build-images.sh --product PXC --version 9X --push --arch linux/amd64

# Load the image into your local Docker (single architecture only)
./build-images.sh --product PXB --version 80 --load --arch linux/amd64 ol8
```

#### Pushing Images to Docker Hub

**Option 1: Using command-line credentials**
```bash
./build-images.sh --product PSMDB --version 70 --push --docker-username YOUR_USERNAME --docker-password YOUR_PASSWORD
```

**Option 2: Using pre-existing Docker login**
```bash
# Login first
docker login

# Then build and push
./build-images.sh --product PSMDB --version 70 --push
```

**Option 3: Using environment variables**
```bash
export DOCKER_USERNAME=YOUR_USERNAME
export DOCKER_PASSWORD=YOUR_PASSWORD
./build-images.sh --product PSMDB --version 70 --push
```

### Using the Multi-Architecture Docker Images

```bash
# Pull the image - Docker will automatically select the right architecture
docker pull percona/build-env:PSMDB-70-ol8

# Run a container
docker run -it --rm percona/build-env:PSMDB-70-ol8

# Inside the container
cd /home/builder/build
git clone https://github.com/percona/percona-server-mongodb.git
cd percona-server-mongodb
# Run your build commands here, skipping the dependency installation
./build_script.sh --install_deps=0 --build_rpm=1 ...
```

## Image Tags Format

Images are tagged using the following format:
```
percona/build-env:<PRODUCT>-<VERSION>-<OS>[-fips]
```

Examples:
- `percona/build-env:PSMDB-70-ol8` - PSMDB 7.0 on Oracle Linux 8
- `percona/build-env:PS-80-ubuntu2204` - PS 8.0 on Ubuntu 22.04
- `percona/build-env:PXC-9X-debian12-fips` - PXC 9.X on Debian 12 with FIPS mode

Additionally, a `-latest` tag is created for each product-version combination:
- `percona/build-env:PSMDB-70-latest`

## Adding New Product Versions

To add support for a new product version:

1. Create a new playbook in the corresponding product directory:
   ```bash
   cp ansible/psmdb/psmdb_70_setup.yml ansible/psmdb/psmdb_80_setup.yml
   ```
2. Update the playbook content to match the requirements for the new version
3. Update the `SUPPORTED_PRODUCTS` array in `build-images.sh` if needed

## Requirements

### For Docker Multi-Architecture Builds

- Docker Engine 19.03 or newer with buildx plugin
- Docker Hub account or private registry for pushing multi-arch images
- qemu-user-static for cross-platform emulation (installed automatically by buildx)

To enable buildx if needed:
```bash
# Enable experimental features
export DOCKER_CLI_EXPERIMENTAL=enabled
# Setup qemu for arm64 emulation
docker run --privileged --rm tonistiigi/binfmt --install arm64
```
