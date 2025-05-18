#!/bin/bash

# Default values
AUTO_DOWNLOAD=0
AUTO_YES=0
DEP_DIR=""
SKIP_TXT=0
ITERATIONS="8"

usage() {
    echo "Usage: $0 [-d] [-y] [-o output_directory] [-n] [-h] <main-package>"
    echo ""
    echo "Options:"
    echo "  -d or -y            Automatically downloads packages without prompting"
    echo "  -o <directory>      Set custom output directory"
    echo "  -n                  Do not generate the package list text file"
    echo "  -h                  Show this help message and exit"
    echo ""
    exit 0
}

# Parse arguments
while getopts ":dyo:nh" opt; do
    case $opt in
        d) AUTO_DOWNLOAD=1 ;;
        y) AUTO_YES=1 ;;
        o) DEP_DIR="$OPTARG" ;;
        n) SKIP_TXT=1 ;;
        h) usage ;;
        *) usage ;;
    esac
done

shift $((OPTIND -1))

# Check if main package argument is provided
if [ -z "$1" ]; then
    usage
fi
MAIN_PACKAGE="$1"

# Validate custom output directory if provided
if [ -n "$DEP_DIR" ]; then
    # Ensure base output directory exists
    if [ ! -d "$DEP_DIR" ]; then
        echo "Creating base output directory: $DEP_DIR"
        mkdir -p "$DEP_DIR" || { echo "Failed to create directory $DEP_DIR"; exit 1; }
    fi
    # Now set DEP_DIR to include the app-depends folder
    DEP_DIR="${DEP_DIR}/${MAIN_PACKAGE}-depends"
else
    # Default output directory in home folder
    DEP_DIR="/home/$USER/${MAIN_PACKAGE}-depends"
fi



detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${ID,,}"
    elif [ -f /etc/redhat-release ]; then
        DISTRO_ID="rhel"
    elif [ -f /etc/arch-release ]; then
        DISTRO_ID="arch"
    elif [ -f /etc/SuSE-release ]; then
        DISTRO_ID="opensuse"
    else
        DISTRO_ID="unknown"
    fi

    case "$DISTRO_ID" in
        debian|ubuntu|linuxmint|pop)
            echo "Detected: Debian-based system"
            ;;
        rhel|fedora|centos|rocky|almalinux)
            echo "Detected: Red Hat-based system"
            ;;
        arch)
            echo "Detected: Arch-based system"
            ;;
        opensuse|suse)
            echo "Detected: openSUSE-based system"
            ;;
        *)
            echo "Distribution: Unknown or unsupported"
            exit 1
            ;;
    esac
}

# Run distro detection
detect_distro

DEPENDENCIES=("$MAIN_PACKAGE")
FOUND_PACKAGES=()
LIST_FILE="/home/$USER/${MAIN_PACKAGE}-complete-package-list.txt"

# Resolve dependencies
echo "Resolving dependencies for $MAIN_PACKAGE..."
for ((i=1; i<=ITERATIONS; i++)); do
    echo -ne "Iteration $i...\r"
    NEW_DEPENDENCIES=()

    for PKG in "${DEPENDENCIES[@]}"; do
        if [[ " ${FOUND_PACKAGES[*]} " == *" $PKG "* ]] || [[ "$PKG" == *"<"*">"* ]]; then
            continue
        fi

        case "$DISTRO_ID" in
            debian|ubuntu|linuxmint|pop)
                DEPS=$(apt-cache depends "$PKG" 2>/dev/null | grep "Depends:" | cut -c 12- | grep -vE "^(dpkg|libc6)$" | sort -u)
                ;;
            rhel|fedora|centos|rocky|almalinux)
                DEPS=$(repoquery --requires --resolve "$PKG" 2>/dev/null | awk '{print $1}' | sort -u)
                ;;
            arch)
                DEPS=$(pactree -u "$PKG" 2>/dev/null | tail -n +2 | awk '{print $2}' | sort -u)
                ;;
            opensuse|suse)
                DEPS=$(zypper info --requires "$PKG" 2>/dev/null | grep -E 'Requires' | cut -d: -f2 | awk '{print $1}' | sort -u)
                ;;
            *)
                echo "Dependency resolution unsupported for this distribution."
                exit 1
                ;;
        esac

        FOUND_PACKAGES+=("$PKG")

        for DEP in $DEPS; do
            if [[ "$DEP" == *"<"*">"* ]]; then
                continue
            fi
            if [[ ! " ${FOUND_PACKAGES[*]} " =~ " $DEP " ]]; then
                NEW_DEPENDENCIES+=("$DEP")
            fi
        done
    done

    if [ ${#NEW_DEPENDENCIES[@]} -eq 0 ]; then
        echo "No further dependencies found."
        break
    fi

    DEPENDENCIES=($(printf "%s\n" "${NEW_DEPENDENCIES[@]}" | sort -u))
done

FINAL_LIST=($(printf "%s\n" "${FOUND_PACKAGES[@]}" | sort -u))

if [ $SKIP_TXT -eq 0 ]; then
    printf "%s\n" "${FINAL_LIST[@]}" > "$LIST_FILE"
    echo ""
    echo "Complete package list generated:"
    echo "  $LIST_FILE"
fi

echo "Total packages: ${#FINAL_LIST[@]}"

# Determine download directory
if [ -z "$DEP_DIR" ]; then
    DEP_DIR="/home/$USER/${MAIN_PACKAGE}-depends"
fi

# Confirm or auto download
if [[ $AUTO_DOWNLOAD -eq 1 || $AUTO_YES -eq 1 ]]; then
    CONFIRM="y"
else
    read -rp "Proceed to download these packages into '$DEP_DIR'? [y/N]: " CONFIRM
fi

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Download cancelled."
    exit 0
fi

mkdir -p "$DEP_DIR" || { echo "Failed to create directory $DEP_DIR"; exit 1; }
cd "$DEP_DIR" || { echo "Failed to enter directory $DEP_DIR"; exit 1; }

TOTAL=${#FINAL_LIST[@]}
COUNT=0

echo ""
echo "Downloading packages..."

for PKG in "${FINAL_LIST[@]}"; do
    case "$DISTRO_ID" in
        debian|ubuntu|linuxmint|pop)
            if apt-get download "$PKG" >/dev/null 2>&1; then :; else echo "Warning: Failed to download $PKG"; fi
            ;;
        rhel|fedora|centos|rocky|almalinux)
            if dnf download "$PKG" --resolve >/dev/null 2>&1; then :; else echo "Warning: Failed to download $PKG"; fi
            ;;
        arch)
            if pacman -Sw --noconfirm "$PKG" >/dev/null 2>&1; then :; else echo "Warning: Failed to download $PKG"; fi
            ;;
        opensuse|suse)
            if zypper download "$PKG" >/dev/null 2>&1; then :; else echo "Warning: Failed to download $PKG"; fi
            ;;
        *)
            echo "Unsupported distro for downloading."
            exit 1
            ;;
    esac

    COUNT=$((COUNT + 1))
    PERCENT=$((COUNT * 100 / TOTAL))
    BAR_LENGTH=60
    PKG_DISPLAY=$(echo "$PKG                                        ")
    FILLED_LENGTH=$((PERCENT * BAR_LENGTH / 100))
    BAR=$(printf "%${FILLED_LENGTH}s" | tr ' ' '#')
    EMPTY=$(printf "%$((BAR_LENGTH - FILLED_LENGTH))s")
    printf "\r[%s%s] %d%% (%d/%d) %s" "$BAR" "$EMPTY" "$PERCENT" "$COUNT" "$TOTAL" "$PKG_DISPLAY"
done

echo ""
echo ""
echo "All available packages downloaded to '$DEP_DIR'."
