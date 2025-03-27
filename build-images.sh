#!/usr/bin/env bash

# Script to build multi-architecture Docker images for Percona products build environments
# Uses a template Dockerfile and adapts it for different platforms

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_NAMESPACE=${DOCKER_NAMESPACE:-"percona/build-env"}
FIPS_MODE=0
PLATFORMS=()
PRODUCT=""
VERSION=""
BUILD_ALL_PLATFORMS=1
PUSH=0
KEEP_DOCKERFILE=0
ARCHITECTURES=("linux/amd64" "linux/arm64")
BUILDX_DRIVER="docker-container"
LOAD_LOCAL=0
DOCKER_USERNAME=""
DOCKER_PASSWORD=""

# Define platform configurations
declare -A BASE_IMAGES
BASE_IMAGES=(
    ["ol8"]="oraclelinux:8"
    ["ol9"]="oraclelinux:9"
    ["ubuntu2004"]="ubuntu:20.04"
    ["ubuntu2204"]="ubuntu:22.04"
    ["ubuntu2404"]="ubuntu:24.04"
    ["debian11"]="debian:11"
    ["debian12"]="debian:12"
)

declare -A OS_NAMES
OS_NAMES=(
    ["ol8"]="Oracle Linux 8"
    ["ol9"]="Oracle Linux 9"
    ["ubuntu2004"]="Ubuntu 20.04"
    ["ubuntu2204"]="Ubuntu 22.04"
    ["ubuntu2404"]="Ubuntu 24.04"
    ["debian11"]="Debian 11"
    ["debian12"]="Debian 12"
)

declare -A INSTALL_BASIC_DEPS
INSTALL_BASIC_DEPS=(
    ["ol8"]="RUN dnf -y update && \\
    dnf -y install epel-release && \\
    dnf -y install ansible python3 sudo python3-pip curl which git && \\
    dnf clean all"
    
    ["ol9"]="RUN dnf -y update && \\
    dnf -y install python3 sudo python3-pip curl which git && \\
    dnf -y install epel-release && \\
    dnf -y install ansible && \\
    dnf clean all"
    
    ["ubuntu2004"]="RUN apt-get update && \\
    apt-get install -y \\
        python3 \\
        python3-pip \\
        sudo \\
        curl \\
        software-properties-common \\
        lsb-release \\
        git \\
        wget && \\
    apt-add-repository --yes --update ppa:ansible/ansible && \\
    apt-get install -y ansible && \\
    apt-get clean && \\
    rm -rf /var/lib/apt/lists/*"
    
    ["ubuntu2204"]="RUN apt-get update && \\
    apt-get install -y \\
        python3 \\
        python3-pip \\
        sudo \\
        curl \\
        software-properties-common \\
        lsb-release \\
        git \\
        wget && \\
    apt-add-repository --yes --update ppa:ansible/ansible && \\
    apt-get install -y ansible && \\
    apt-get clean && \\
    rm -rf /var/lib/apt/lists/*"
    
    ["ubuntu2404"]="RUN apt-get update && \\
    apt-get install -y \\
        python3 \\
        python3-pip \\
        sudo \\
        curl \\
        software-properties-common \\
        lsb-release \\
        git \\
        wget && \\
    apt-add-repository --yes --update ppa:ansible/ansible && \\
    apt-get install -y ansible && \\
    apt-get clean && \\
    rm -rf /var/lib/apt/lists/*"
    
    ["debian11"]="RUN apt-get update && \\
    apt-get install -y \\
        python3 \\
        python3-pip \\
        sudo \\
        curl \\
        gnupg2 \\
        lsb-release \\
        git \\
        wget && \\
    echo \"deb http://ppa.launchpad.net/ansible/ansible/ubuntu focal main\" > /etc/apt/sources.list.d/ansible.list && \\
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367 && \\
    apt-get update && \\
    apt-get install -y ansible && \\
    apt-get clean && \\
    rm -rf /var/lib/apt/lists/*"
    
    ["debian12"]="RUN apt-get update && \\
    apt-get install -y \\
        python3 \\
        python3-pip \\
        sudo \\
        curl \\
        gnupg2 \\
        lsb-release \\
        git \\
        wget && \\
    echo \"deb http://ppa.launchpad.net/ansible/ansible/ubuntu jammy main\" > /etc/apt/sources.list.d/ansible.list && \\
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 93C4A3FD7BB9C367 && \\
    apt-get update && \\
    apt-get install -y ansible && \\
    apt-get clean && \\
    rm -rf /var/lib/apt/lists/*"
)

# Define supported products and versions
declare -A SUPPORTED_PRODUCTS
SUPPORTED_PRODUCTS=(
    ["PSMDB"]="60 70 80"
    ["PS"]="80 84 9X"
    ["PXB"]="80 84 90"
    ["PXC"]="80 84 9X"
)

function usage() {
    echo "Usage: $0 [OPTIONS] [PLATFORMS...]"
    echo "Build multi-architecture Docker images for Percona products build environments"
    echo ""
    echo "Options:"
    echo "  --product PRODUCT     Specify product (required)"
    echo "  --version VERSION     Specify version (required)"
    echo "  --fips                Build with FIPS mode enabled"
    echo "  --namespace NAME      Set Docker namespace (default: percona/build-env)"
    echo "  --push                Push images after building"
    echo "  --docker-username USER  Docker Hub username for pushing (required with --push)"
    echo "  --docker-password PASS  Docker Hub password for pushing (required with --push)"
    echo "  --keep-dockerfile     Keep generated Dockerfiles"
    echo "  --arch ARCH           Specify architectures to build (comma-separated, default: linux/amd64,linux/arm64)"
    echo "  --load                Load images into local Docker (single arch only)"
    echo "  --help                Show this help message"
    echo ""
    echo "Supported Products and Versions:"
    for product in "${!SUPPORTED_PRODUCTS[@]}"; do
        echo "  $product: ${SUPPORTED_PRODUCTS[$product]}"
    done
    echo ""
    echo "Platforms:"
    echo "  ol8                   Oracle Linux 8"
    echo "  ol9                   Oracle Linux 9"
    echo "  ubuntu2004            Ubuntu 20.04"
    echo "  ubuntu2204            Ubuntu 22.04" 
    echo "  ubuntu2404            Ubuntu 24.04"
    echo "  debian11              Debian 11"
    echo "  debian12              Debian 12"
    echo ""
    echo "If no platforms are specified, all will be built."
    echo ""
    echo "Examples:"
    echo "  $0 --product PSMDB --version 60 --push ol8 ubuntu2204"
    echo "  $0 --product PS --version 80 --fips --push"
    echo "  $0 --product PXC --version 9X --arch linux/amd64 --load ol9"
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
        --namespace)
            DOCKER_NAMESPACE="$2"
            shift 2
            ;;
        --push)
            PUSH=1
            shift
            ;;
        --docker-username)
            DOCKER_USERNAME="$2"
            shift 2
            ;;
        --docker-password)
            DOCKER_PASSWORD="$2"
            shift 2
            ;;
        --keep-dockerfile)
            KEEP_DOCKERFILE=1
            shift
            ;;
        --arch)
            IFS=',' read -ra ARCHITECTURES <<< "$2"
            shift 2
            ;;
        --load)
            LOAD_LOCAL=1
            shift
            ;;
        --help)
            usage
            ;;
        ol8|ol9|ubuntu2004|ubuntu2204|ubuntu2404|debian11|debian12)
            PLATFORMS+=("$1")
            BUILD_ALL_PLATFORMS=0
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate product and version
if [ -z "$PRODUCT" ] || [ -z "$VERSION" ]; then
    echo "Error: Product and version must be specified."
    usage
fi

# Check if product is supported
if [[ ! "${!SUPPORTED_PRODUCTS[@]}" =~ "$PRODUCT" ]]; then
    echo "Error: Unsupported product '$PRODUCT'."
    usage
fi

# Check if version is supported for the product
if [[ ! " ${SUPPORTED_PRODUCTS[$PRODUCT]} " =~ " $VERSION " ]]; then
    echo "Error: Unsupported version '$VERSION' for product '$PRODUCT'."
    usage
fi

# Convert product to lowercase for playbook paths
PRODUCT_LC=$(echo "$PRODUCT" | tr '[:upper:]' '[:lower:]')

# If no platforms specified, build all
if [ "$BUILD_ALL_PLATFORMS" -eq 1 ]; then
    PLATFORMS=("ol8" "ol9" "ubuntu2004" "ubuntu2204" "ubuntu2404" "debian11" "debian12")
fi

# Validate Docker Hub credentials if pushing
if [ "$PUSH" -eq 1 ]; then
    if [ -z "$DOCKER_USERNAME" ] || [ -z "$DOCKER_PASSWORD" ]; then
        # Check if already logged in
        if ! docker info | grep -q "Username"; then
            echo "Error: Docker Hub username and password required for pushing."
            echo "Please provide --docker-username and --docker-password options"
            echo "Or login manually with 'docker login' before running this script."
            exit 1
        else
            echo "Using existing Docker Hub authentication."
        fi
    else
        echo "Logging in to Docker Hub as $DOCKER_USERNAME..."
        echo "$DOCKER_PASSWORD" | docker login --username "$DOCKER_USERNAME" --password-stdin
    fi
fi

echo "Building Docker images for $PRODUCT-$VERSION build environments"
echo "Docker namespace: $DOCKER_NAMESPACE"
echo "FIPS mode: $FIPS_MODE"
echo "Platforms: ${PLATFORMS[*]}"
echo "Architectures: ${ARCHITECTURES[*]}"
echo ""

# Check if template exists
TEMPLATE_FILE="$SCRIPT_DIR/Dockerfile.template"
if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file $TEMPLATE_FILE not found!"
    exit 1
fi

# Check if playbook exists
PLAYBOOK_PATH="$SCRIPT_DIR/ansible/$PRODUCT_LC/${PRODUCT_LC}_${VERSION}_setup.yml"
if [ ! -f "$PLAYBOOK_PATH" ]; then
    echo "Error: Playbook file $PLAYBOOK_PATH not found!"
    echo "Please create the playbook for $PRODUCT_LC version $VERSION first."
    exit 1
fi

# Create a build directory
BUILD_DIR="$SCRIPT_DIR/docker-build"
mkdir -p "$BUILD_DIR"

# Setup buildx for multi-arch builds
BUILDER_NAME="percona-multiarch-builder"

# Check if the builder already exists
if ! docker buildx inspect "$BUILDER_NAME" &>/dev/null; then
    echo "Creating new buildx builder: $BUILDER_NAME"
    docker buildx create --driver "$BUILDX_DRIVER" --name "$BUILDER_NAME" --use || {
        echo "Fallback: creating default builder"
        docker buildx create --driver "$BUILDX_DRIVER" --use
    }
else
    echo "Using existing buildx builder: $BUILDER_NAME"
    docker buildx use "$BUILDER_NAME" || true
fi

# Ensure the builder is running
docker buildx inspect --bootstrap

# If load is requested, verify we're only building for the current architecture
if [ "$LOAD_LOCAL" -eq 1 ]; then
    if [ ${#ARCHITECTURES[@]} -gt 1 ]; then
        echo "Error: --load option can only be used with a single architecture."
        echo "Please specify --arch with a single architecture, e.g., --arch linux/amd64"
        exit 1
    fi
fi

# Build each Docker image
for platform in "${PLATFORMS[@]}"; do
    # Check if platform is supported
    if [[ -z "${BASE_IMAGES[$platform]}" ]]; then
        echo "Error: Unknown platform $platform"
        continue
    fi
    
    # Create image tags
    product_tag="${PRODUCT}-${VERSION}"
    image_name="${DOCKER_NAMESPACE}:${product_tag}-${platform}"
    if [ "$FIPS_MODE" -eq 1 ]; then
        image_name="${image_name}-fips"
    fi
    
    echo "Building $image_name for architectures: ${ARCHITECTURES[*]}"
    
    # Create platform-specific Dockerfile from template
    platform_dockerfile="$BUILD_DIR/Dockerfile.${product_tag}-${platform}"
    
    # Replace placeholders in template
    cp "$TEMPLATE_FILE" "$platform_dockerfile"
    sed -i "s|{{BASE_IMAGE}}|${BASE_IMAGES[$platform]}|g" "$platform_dockerfile"
    sed -i "s|{{OS_NAME}}|${OS_NAMES[$platform]}|g" "$platform_dockerfile"
    sed -i "s|{{INSTALL_BASIC_DEPS}}|${INSTALL_BASIC_DEPS[$platform]}|g" "$platform_dockerfile"
    sed -i "s|{{PRODUCT}}|${PRODUCT}|g" "$platform_dockerfile"
    sed -i "s|{{VERSION}}|${VERSION}|g" "$platform_dockerfile"
    sed -i "s|{{PRODUCT_LC}}|${PRODUCT_LC}|g" "$platform_dockerfile"
    
    # Build command options
    build_args=()
    build_args+=(--build-arg "FIPS_MODE=$FIPS_MODE")
    build_args+=(--build-arg "PRODUCT=$PRODUCT")
    build_args+=(--build-arg "VERSION=$VERSION")
    
    # Architecture platforms string
    platforms_arg=""
    for arch in "${ARCHITECTURES[@]}"; do
        if [ -z "$platforms_arg" ]; then
            platforms_arg="$arch"
        else
            platforms_arg="$platforms_arg,$arch"
        fi
    done
    
    # Action based on options
    if [ "$PUSH" -eq 1 ]; then
        echo "Building and pushing multi-arch image: $image_name"
        build_args+=(--push)
    elif [ "$LOAD_LOCAL" -eq 1 ]; then
        echo "Building and loading into local Docker: $image_name"
        build_args+=(--load)
    else
        echo "Building without pushing or loading: $image_name"
        build_args+=(--output=type=image,push=false)
    fi
    
    # Build the multi-arch image
    docker buildx build \
        --platform "$platforms_arg" \
        "${build_args[@]}" \
        -t "$image_name" \
        -f "$platform_dockerfile" \
        "$SCRIPT_DIR"
    
    echo "Successfully built $image_name"
    
    # Also tag as latest for this product-version combination (if not FIPS)
    if [ "$PUSH" -eq 1 ] && [ "$FIPS_MODE" -eq 0 ]; then
        latest_tag="${DOCKER_NAMESPACE}:${product_tag}-latest"
        echo "Tagging and pushing as: $latest_tag"
        
        docker buildx build \
            --platform "$platforms_arg" \
            "${build_args[@]}" \
            -t "$latest_tag" \
            -f "$platform_dockerfile" \
            "$SCRIPT_DIR"
    fi
    
    # Cleanup
    if [ "$KEEP_DOCKERFILE" -eq 0 ]; then
        rm -f "$platform_dockerfile"
    fi
    
    echo ""
done

# Cleanup build directory if empty and not keeping Dockerfiles
if [ "$KEEP_DOCKERFILE" -eq 0 ]; then
    rmdir --ignore-fail-on-non-empty "$BUILD_DIR"
fi

# If we logged in within this script, log out for security
if [ -n "$DOCKER_USERNAME" ] && [ -n "$DOCKER_PASSWORD" ]; then
    echo "Logging out from Docker Hub..."
    docker logout
fi

echo "All Docker images for $PRODUCT-$VERSION built successfully!"
EOF

# Create run-local-setup.sh script
cat > run-local-setup.sh << 'EOF'
#!/usr/bin/env bash

# Script to run Ansible locally to set up Percona product build dependencies

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    echo "  --version VERSION     Product version (e.g., 60, 70, 80, 84, 9X)"
    echo ""
    echo "Other options:"
    echo "  --fips                Enable FIPS mode"
    echo "  -v, --verbose         Increase verbosity level"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Supported product versions:"
    echo "  PSMDB: 60, 70, 80"
    echo "  PS: 80, 84, 9X"
    echo "  PXB: 80, 84, 90"
    echo "  PXC: 80, 84, 9X"
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

# Convert product to lowercase for directory matching
PRODUCT_LC=$(echo "$PRODUCT" | tr '[:upper:]' '[:lower:]')

# Find the appropriate playbook
PLAYBOOK="$SCRIPT_DIR/ansible/$PRODUCT_LC/${PRODUCT_LC}_${VERSION}_setup.yml"

if [ ! -f "$PLAYBOOK" ]; then
    echo "Error: No playbook found for $PRODUCT version $VERSION"
    echo "Expected playbook path: $PLAYBOOK"
    exit 1
fi

echo "Setting up build environment for $PRODUCT-$VERSION"
echo "FIPS mode: $FIPS_MODE"
echo "Using playbook: $PLAYBOOK"

# Run the Ansible playbook
ansible-playbook -i "$SCRIPT_DIR/ansible/config/hosts" "$PLAYBOOK" -e "fipsmode=$FIPS_MODE" $VERBOSITY

echo "Setup completed successfully!"
