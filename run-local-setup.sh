#!/usr/bin/env bash

# Script to run Ansible locally to set up Percona product build dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/ansible"

# Default values
FIPS_MODE=0
VERBOSITY=""
PRODUCT=""
VERSION=""

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "Ansible is not installed. Installing..."
    if command -v apt-get &> /dev/null; then
        sudo apt-get update
        sudo apt-get install -y ansible
    elif command -v yum &> /dev/null; then
        sudo yum install -y epel-release
        sudo yum install -y ansible
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y ansible
    else
        echo "Could not install Ansible. Please install it manually."
        exit 1
    fi
fi

function usage() {
    echo "Usage: $0 --product PRODUCT --version VERSION [OPTIONS]"
    echo "Set up local environment for building Percona products"
    echo ""
    echo "Required options:"
    echo "  --product PRODUCT     Product to set up (PSMDB, PS, PXB, PXC)"
    echo "  --version VERSION     Product version (e.g., 60, 70, 80, 9.X)"
    echo ""
    echo "Other options:"
    echo "  --fips                Enable FIPS mode"
    echo "  -v, --verbose         Increase verbosity level"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Supported product versions:"
    echo "  PSMDB: 60, 70, 80"
    echo "  PS: 80, 84, 9.X"
    echo "  PXB: 80, 84, 90"
    echo "  PXC: 80, 84, 9.X"
    echo ""
    echo "Example: $0 --product PSMDB --version 70"
    exit 1
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --product)
            PRODUCT="$2"
            shift 2
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --fips)
            FIPS_MODE=1
            shift
            ;;
        -v|--verbose)
            VERBOSITY="-v"
            shift
            ;;
        -vv)
            VERBOSITY="-vv"
            shift
            ;;
        -vvv)
            VERBOSITY="-vvv"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$PRODUCT" ] || [ -z "$VERSION" ]; then
    echo "Error: Product and version must be specified."
    usage
fi

# Validate product
case "$PRODUCT" in
    PSMDB)
        case "$VERSION" in
            60|70|80) ;;
            *) echo "Error: Invalid version for PSMDB. Supported versions: 60, 70, 80"; exit 1 ;;
        esac
        ;;
    PS)
        case "$VERSION" in
            80|84|9.X) ;;
            *) echo "Error: Invalid version for PS. Supported versions: 80, 84, 9.X"; exit 1 ;;
        esac
        ;;
    PXB)
        case "$VERSION" in
            80|84|90) ;;
            *) echo "Error: Invalid version for PXB. Supported versions: 80, 84, 90"; exit 1 ;;
        esac
        ;;
    PXC)
        case "$VERSION" in
            80|84|9.X) ;;
            *) echo "Error: Invalid version for PXC. Supported versions: 80, 84, 9.X"; exit 1 ;;
        esac
        ;;
    *)
        echo "Error: Invalid product. Supported products: PSMDB, PS, PXB, PXC"
        usage
        ;;
esac

echo "Setting up build environment for $PRODUCT-$VERSION"
echo "FIPS mode: $FIPS_MODE"

# Run the Ansible playbook
ansible-playbook product-dependencies.yml -e "fipsmode=$FIPS_MODE" -e "product=$PRODUCT" -e "version=$VERSION" $VERBOSITY

echo "Setup completed successfully!"
