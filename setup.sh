#!/usr/bin/env bash
set -euo pipefail

COLOR_GREEN="\033[0;32m"
COLOR_CYAN="\033[0;36m"
COLOR_YELLOW="\033[1;33m"
COLOR_RED="\033[0;31m"
COLOR_RESET="\033[0m"

REPO="taodd/linux_profiling_workshop"
RELEASE_TAG="v1.1.0"
IMAGE_ALIAS="perf-noble-base"
IMAGE_META="perf-noble-base.meta"
IMAGE_QCOW2="perf-noble-base.qcow2"
IMAGE_QCOW2_SHA256="6bcd424c6d31f1754bdfede7f5ba1291f3bc1201fafee8bde3326fecfc4fae2e"
IMAGE_VERSION_MARK="profiling workshop ${RELEASE_TAG}"   # in the image description
RELEASE_BASE_URL="https://github.com/${REPO}/releases/download/${RELEASE_TAG}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo -e "${COLOR_CYAN}======================================================================${COLOR_RESET}"
echo -e "${COLOR_CYAN}   Linux Performance Profiling Workshop — Pre-Workshop Setup          ${COLOR_RESET}"
echo -e "${COLOR_CYAN}======================================================================${COLOR_RESET}"
echo ""

# 1. Verify OS, Architecture, and KVM
echo -e "${COLOR_YELLOW}[1/5] Checking host environment and KVM virtualization support...${COLOR_RESET}"
OS_NAME="$(uname -s)"
ARCH_NAME="$(uname -m)"

if [[ "${OS_NAME}" != "Linux" || "${ARCH_NAME}" != "x86_64" ]]; then
    echo -e "${COLOR_RED}[ERROR] This lab requires a Linux x86_64 host (detected: ${OS_NAME} ${ARCH_NAME}).${COLOR_RESET}" >&2
    exit 1
fi

if [[ ! -e /dev/kvm ]]; then
    echo -e "${COLOR_RED}[ERROR] /dev/kvm not found. Please enable KVM hardware virtualization in BIOS/UEFI or VM settings.${COLOR_RESET}" >&2
    exit 1
fi
echo -e "      • Linux x86_64 with /dev/kvm detected."

# 2. Ensure LXD is installed and initialized
echo -e "${COLOR_YELLOW}[2/5] Checking LXD installation and initialization...${COLOR_RESET}"
if ! command -v lxc >/dev/null 2>&1; then
    echo -e "      • LXD not found. Installing LXD via snap..."
    sudo snap install lxd
fi

# The workshop runs lxc without sudo, so the user must be in the 'lxd' group
TARGET_USER="$(id -un)"
if [[ "${EUID}" -eq 0 && -n "${SUDO_USER:-}" ]]; then
    TARGET_USER="${SUDO_USER}"   # run as 'sudo ./setup.sh': add the real user, not root
fi
ADDED_TO_LXD_GROUP=0
if [[ "${TARGET_USER}" != root ]] && ! id -nG "${TARGET_USER}" | grep -qw lxd; then
    if ! getent group lxd >/dev/null; then
        sudo groupadd --system lxd
        sudo snap restart lxd   # so the LXD socket picks up the new group
    fi
    echo -e "      • Adding '${TARGET_USER}' to the 'lxd' group..."
    sudo usermod -aG lxd "${TARGET_USER}"
    ADDED_TO_LXD_GROUP=1
fi

# Use sudo for the rest of this script if this shell hasn't picked up the group yet
LXC_CMD=(lxc)
if ! lxc info >/dev/null 2>&1; then
    if sudo lxc info >/dev/null 2>&1; then
        LXC_CMD=(sudo lxc)
        echo -e "      • Using 'sudo lxc' for now."
    else
        echo -e "${COLOR_RED}[ERROR] Unable to communicate with the LXD daemon.${COLOR_RESET}" >&2
        exit 1
    fi
fi

# Check if LXD default profile has a root disk device configured; if not, initialize LXD
if ! "${LXC_CMD[@]}" profile show default 2>/dev/null | grep -q "type: disk"; then
    echo -e "      • Initializing LXD with default settings..."
    if [[ "${LXC_CMD[0]}" == "sudo" ]]; then
        sudo lxd init --auto
    else
        lxd init --auto || sudo lxd init --auto
    fi
fi
echo -e "      • LXD is installed and initialized."

# 3. Check if image is already imported in LXD
echo -e "${COLOR_YELLOW}[3/5] Checking LXD image store for '${IMAGE_ALIAS}'...${COLOR_RESET}"
if "${LXC_CMD[@]}" image list -c l --format csv </dev/null | grep -qx "${IMAGE_ALIAS}" \
    && ! "${LXC_CMD[@]}" image info "${IMAGE_ALIAS}" </dev/null | grep -q "${IMAGE_VERSION_MARK}"; then
    echo -e "      • Removing an older '${IMAGE_ALIAS}' image (this workshop needs ${RELEASE_TAG})..."
    "${LXC_CMD[@]}" image delete "${IMAGE_ALIAS}" </dev/null
fi

if "${LXC_CMD[@]}" image list -c l --format csv </dev/null | grep -qx "${IMAGE_ALIAS}"; then
    echo -e "      • Image '${IMAGE_ALIAS}' (${RELEASE_TAG}) is already imported in LXD."
else
    # 4. Download image files if not already present locally
    echo -e "${COLOR_YELLOW}[4/5] Preparing VM image files ('${IMAGE_META}' + '${IMAGE_QCOW2}')...${COLOR_RESET}"

    download_asset() {
        local filename="$1"
        local url="${RELEASE_BASE_URL}/${filename}"
        echo -e "      • Downloading ${filename} from GitHub Release ${RELEASE_TAG}..."

        if command -v wget >/dev/null 2>&1 && wget --progress=bar:force -O "${filename}.part" "${url}"; then
            mv "${filename}.part" "${filename}"
            return 0
        fi
        rm -f "${filename}.part"

        if command -v curl >/dev/null 2>&1 && curl -fL --progress-bar -o "${filename}.part" "${url}"; then
            mv "${filename}.part" "${filename}"
            return 0
        fi
        rm -f "${filename}.part"

        if command -v gh >/dev/null 2>&1 && gh release download "${RELEASE_TAG}" --repo "${REPO}" -p "${filename}" --clobber; then
            return 0
        fi

        echo -e "${COLOR_RED}[ERROR] Failed to download '${filename}' automatically.${COLOR_RESET}" >&2
        echo -e "        If the repository is private, please download '${filename}' in your browser from:" >&2
        echo -e "        https://github.com/${REPO}/releases/tag/${RELEASE_TAG}" >&2
        echo -e "        Place it in '${SCRIPT_DIR}' and re-run ./setup.sh" >&2
        return 1
    }

    if [[ ! -s "${IMAGE_META}" ]]; then
        download_asset "${IMAGE_META}"
    else
        echo -e "      • Found local '${IMAGE_META}'."
    fi

    qcow2_ok() {
        [[ -s "${IMAGE_QCOW2}" ]] && echo "${IMAGE_QCOW2_SHA256}  ${IMAGE_QCOW2}" | sha256sum -c --status
    }

    if qcow2_ok; then
        echo -e "      • Found local '${IMAGE_QCOW2}' (${RELEASE_TAG})."
    else
        rm -f "${IMAGE_QCOW2}"   # missing, partial, or from an older release
        download_asset "${IMAGE_QCOW2}"
        if ! qcow2_ok; then
            echo -e "${COLOR_RED}[ERROR] '${IMAGE_QCOW2}' checksum mismatch. Delete it and re-run ./setup.sh${COLOR_RESET}" >&2
            exit 1
        fi
    fi

    # 5. Import image into LXD
    echo -e "${COLOR_YELLOW}[5/5] Importing '${IMAGE_ALIAS}' into LXD...${COLOR_RESET}"
    "${LXC_CMD[@]}" image import "${IMAGE_META}" "${IMAGE_QCOW2}" --alias "${IMAGE_ALIAS}" </dev/null
fi

# Ensure setup_lab is executable
if [[ -f "./setup_lab" ]]; then
    chmod +x ./setup_lab
fi

echo ""
echo -e "${COLOR_CYAN}Registered LXD Workshop Image:${COLOR_RESET}"
"${LXC_CMD[@]}" image list "${IMAGE_ALIAS}" </dev/null

echo ""
echo -e "${COLOR_CYAN}======================================================================${COLOR_RESET}"
echo -e "${COLOR_GREEN}[✔] Pre-workshop preparation complete!${COLOR_RESET}"
echo -e "During the live workshop, simply run:"
echo -e "  ${COLOR_YELLOW}./setup_lab${COLOR_RESET}"
if [[ "${ADDED_TO_LXD_GROUP}" -eq 1 || "${LXC_CMD[0]}" == "sudo" ]]; then
    echo ""
    echo -e "${COLOR_YELLOW}[!] '${TARGET_USER}' is now in the 'lxd' group. Log out and back in, then check that${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}    'lxc list' works without sudo.${COLOR_RESET}"
fi
echo -e "${COLOR_CYAN}======================================================================${COLOR_RESET}"
