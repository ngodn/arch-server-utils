#!/bin/bash
# Server Tools: Windows VM via Docker (dockurr/windows) with KVM + RDP
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Installing Windows VM tool..."

# Ensure docker is available
if ! command -v docker &>/dev/null; then
  warn "Docker is required for Windows VM. Select the Docker component first."
fi

pkg_install docker-compose openbsd-netcat

ensure_dir "$HOME/.local/bin"

cat > "$HOME/.local/bin/omarchy-windows-vm" << 'SCRIPT'
#!/bin/bash
COMPOSE_FILE="$HOME/.config/windows/docker-compose.yml"

check_prerequisites() {
  local DISK_SIZE_GB=${1:-64}
  local REQUIRED_SPACE=$((DISK_SIZE_GB + 10))

  if [[ ! -e /dev/kvm ]]; then
    ARCH=$(uname -m)
    if [[ "$ARCH" == "aarch64" ]]; then
      echo "WARNING: Windows VM requires x86_64 KVM — will not work on aarch64"
      echo "Proceeding with setup, but the VM will not boot on this architecture"
      sudo modprobe kvm 2>/dev/null || true
      return 0 2>/dev/null || exit 0
    fi
    echo "KVM virtualization not available!"
    echo
    echo "Please enable virtualization in BIOS or run:"
    echo "  sudo modprobe kvm-intel  # for Intel CPUs"
    echo "  sudo modprobe kvm-amd    # for AMD CPUs"
    exit 1
  fi

  AVAILABLE_SPACE=$(df "$HOME" | awk 'NR==2 {print int($4/1024/1024)}')
  if (( AVAILABLE_SPACE < REQUIRED_SPACE )); then
    echo "Insufficient disk space!"
    echo "  Available: ${AVAILABLE_SPACE}GB"
    echo "  Required: ${REQUIRED_SPACE}GB (${DISK_SIZE_GB}GB disk + 10GB for Windows image)"
    exit 1
  fi
}

install_windows() {
  trap "echo ''; echo 'Installation cancelled by user'; exit 1" INT

  check_prerequisites

  mkdir -p "$HOME/.windows"
  mkdir -p "$HOME/.config/windows"

  # Get system resources
  TOTAL_RAM=$(free -h | awk 'NR==2 {print $2}')
  TOTAL_RAM_GB=$(awk 'NR==1 {printf "%d", $2/1024/1024}' /proc/meminfo)
  TOTAL_CORES=$(nproc)

  echo
  echo "System Resources Detected:"
  echo "  Total RAM: $TOTAL_RAM"
  echo "  Total CPU Cores: $TOTAL_CORES"
  echo

  # RAM selection
  echo "How much RAM to allocate? (default: 4G)"
  echo -n "  Options:"
  for size in 2 4 8 16 32 64; do
    (( size <= TOTAL_RAM_GB )) && echo -n " ${size}G"
  done
  echo
  read -rp "  RAM [4G]: " SELECTED_RAM
  [[ -z $SELECTED_RAM ]] && SELECTED_RAM="4G"

  # CPU selection
  read -rp "  CPU cores [2] (1-$TOTAL_CORES): " SELECTED_CORES
  [[ -z $SELECTED_CORES ]] && SELECTED_CORES=2
  if ! [[ $SELECTED_CORES =~ ^[0-9]+$ ]] || (( SELECTED_CORES < 1 )) || (( SELECTED_CORES > TOTAL_CORES )); then
    echo "  Invalid input. Using default: 2 cores"
    SELECTED_CORES=2
  fi

  # Disk selection
  AVAILABLE_SPACE=$(df "$HOME" | awk 'NR==2 {print int($4/1024/1024)}')
  MAX_DISK_GB=$((AVAILABLE_SPACE - 10))

  if (( MAX_DISK_GB < 32 )); then
    echo "Insufficient disk space for Windows VM!"
    echo "  Available: ${AVAILABLE_SPACE}GB"
    echo "  Minimum required: 42GB (32GB disk + 10GB for Windows image)"
    exit 1
  fi

  echo "  How much disk space? (64GB+ recommended)"
  echo -n "  Options:"
  for size in 32 64 128 256 512; do
    (( size <= MAX_DISK_GB )) && echo -n " ${size}G"
  done
  echo
  read -rp "  Disk [64G]: " SELECTED_DISK
  [[ -z $SELECTED_DISK ]] && SELECTED_DISK="64G"

  DISK_SIZE_NUM=$(echo "$SELECTED_DISK" | sed 's/G//')
  check_prerequisites "$DISK_SIZE_NUM"

  # Credentials
  read -rp "  Windows username [docker]: " USERNAME
  [[ -z $USERNAME ]] && USERNAME="docker"

  read -rsp "  Windows password [admin]: " PASSWORD
  echo
  [[ -z $PASSWORD ]] && PASSWORD="admin"

  # Summary
  echo
  echo "┌──────────────────────────────┐"
  echo "│   Windows VM Configuration   │"
  echo "├──────────────────────────────┤"
  echo "│  RAM:       $SELECTED_RAM"
  echo "│  CPU:       $SELECTED_CORES cores"
  echo "│  Disk:      $SELECTED_DISK"
  echo "│  Username:  $USERNAME"
  echo "│  Password:  ****"
  echo "└──────────────────────────────┘"
  echo

  read -rp "Proceed? (y/N): " confirm
  [[ ! $confirm =~ ^[Yy]$ ]] && echo "Cancelled." && exit 1

  mkdir -p "$HOME/Windows"

  cat << EOF | tee "$COMPOSE_FILE" > /dev/null
services:
  windows:
    image: dockurr/windows
    container_name: omarchy-windows
    environment:
      VERSION: "11"
      RAM_SIZE: "$SELECTED_RAM"
      CPU_CORES: "$SELECTED_CORES"
      DISK_SIZE: "$SELECTED_DISK"
      USERNAME: "$USERNAME"
      PASSWORD: "$PASSWORD"
      TZ: "$(timedatectl show -p Timezone --value 2>/dev/null || echo UTC)"
      ARGUMENTS: "-rtc base=localtime,clock=host,driftfix=slew"
    devices:
      - /dev/kvm
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - 127.0.0.1:8006:8006
      - 127.0.0.1:3389:3389/tcp
      - 127.0.0.1:3389:3389/udp
    volumes:
      - \$HOME/.windows:/storage
      - \$HOME/Windows:/shared
    restart: unless-stopped
    stop_grace_period: 2m
EOF

  echo
  echo "Starting Windows VM installation..."
  echo "This will download a Windows 11 image (may take 10-15 minutes)."
  echo

  if ! docker compose -f "$COMPOSE_FILE" up -d 2>&1; then
    echo "Failed to start Windows VM!"
    echo "  Common issues:"
    echo "  - Docker daemon not running: sudo systemctl start docker"
    echo "  - Port already in use: check if another VM is running"
    echo "  - Permission issues: make sure you're in the docker group"
    exit 1
  fi

  echo
  echo "Windows VM is starting up!"
  echo
  echo "Monitor installation at:  http://127.0.0.1:8006"
  echo "Connect via RDP at:       127.0.0.1:3389"
  echo "Shared folder:            ~/Windows"
  echo
  echo "Commands:"
  echo "  omarchy-windows-vm stop     Stop the VM"
  echo "  omarchy-windows-vm status   Check VM status"
  echo "  omarchy-windows-vm remove   Remove VM and data"
  echo
}

remove_windows() {
  read -rp "Remove Windows VM and delete all data? (y/N): " confirm
  [[ ! $confirm =~ ^[Yy]$ ]] && echo "Cancelled." && exit 1

  echo "Removing Windows VM..."
  docker compose -f "$COMPOSE_FILE" down 2>/dev/null || true
  docker rmi dockurr/windows 2>/dev/null || echo "Image already removed"
  rm -rf "$HOME/.config/windows"
  rm -rf "$HOME/.windows"
  echo "Windows VM removed."
}

launch_windows() {
  if [[ ! -f $COMPOSE_FILE ]]; then
    echo "Windows VM not configured. Run: omarchy-windows-vm install"
    exit 1
  fi

  CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' omarchy-windows 2>/dev/null)

  if [[ $CONTAINER_STATUS != "running" ]]; then
    echo "Starting Windows VM..."
    if ! docker compose -f "$COMPOSE_FILE" up -d 2>&1; then
      echo "Failed to start Windows VM!"
      exit 1
    fi

    echo "Waiting for Windows VM to boot..."
    WAIT_COUNT=0
    until docker logs omarchy-windows 2>&1 | grep -qi "windows started successfully"; do
      sleep 2
      WAIT_COUNT=$((WAIT_COUNT + 1))
      if (( WAIT_COUNT > 60 )); then
        echo "Timeout: Windows VM failed to start within 2 minutes"
        echo "  Check logs: docker logs omarchy-windows"
        exit 1
      fi
    done
  fi

  echo
  echo "Windows VM is running!"
  echo "  Web interface:  http://127.0.0.1:8006"
  echo "  RDP:            127.0.0.1:3389"
  echo

  # Connect via RDP if freerdp is installed
  if command -v xfreerdp3 &>/dev/null; then
    WIN_USER=$(grep "USERNAME:" "$COMPOSE_FILE" | sed 's/.*USERNAME: "\(.*\)"/\1/')
    WIN_PASS=$(grep "PASSWORD:" "$COMPOSE_FILE" | sed 's/.*PASSWORD: "\(.*\)"/\1/')
    [[ -z $WIN_USER ]] && WIN_USER="docker"
    [[ -z $WIN_PASS ]] && WIN_PASS="admin"

    echo "Connecting via RDP..."
    xfreerdp3 /u:"$WIN_USER" /p:"$WIN_PASS" /v:127.0.0.1:3389 /sound /clipboard /cert:ignore /dynamic-resolution /gfx:AVC444
  else
    echo "Install freerdp to connect via RDP, or use the web interface."
  fi
}

stop_windows() {
  if [[ ! -f $COMPOSE_FILE ]]; then
    echo "Windows VM not configured."
    exit 1
  fi

  echo "Stopping Windows VM..."
  docker compose -f "$COMPOSE_FILE" down
  echo "Windows VM stopped."
}

status_windows() {
  if [[ ! -f $COMPOSE_FILE ]]; then
    echo "Windows VM not configured."
    echo "To set up: omarchy-windows-vm install"
    exit 1
  fi

  CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' omarchy-windows 2>/dev/null)

  if [[ -z $CONTAINER_STATUS ]]; then
    echo "Windows VM container not found."
    echo "To start: omarchy-windows-vm launch"
  elif [[ $CONTAINER_STATUS == "running" ]]; then
    echo "Windows VM: RUNNING"
    echo "  Web interface:  http://127.0.0.1:8006"
    echo "  RDP:            127.0.0.1:3389"
    echo
    echo "  omarchy-windows-vm launch   Connect via RDP"
    echo "  omarchy-windows-vm stop     Stop the VM"
  else
    echo "Windows VM: $CONTAINER_STATUS"
    echo "To start: omarchy-windows-vm launch"
  fi
}

case "${1:-help}" in
  install) install_windows ;;
  remove) remove_windows ;;
  launch|start) launch_windows ;;
  stop|down) stop_windows ;;
  status) status_windows ;;
  help|--help|-h)
    echo "Usage: omarchy-windows-vm [command]"
    echo
    echo "Commands:"
    echo "  install    Install and configure Windows VM"
    echo "  launch     Start VM and connect via RDP"
    echo "  stop       Stop the running VM"
    echo "  status     Show VM status"
    echo "  remove     Remove VM and all data"
    ;;
  *)
    echo "Unknown command: $1" >&2
    echo "Run 'omarchy-windows-vm help' for usage." >&2
    exit 1
    ;;
esac
SCRIPT

chmod +x "$HOME/.local/bin/omarchy-windows-vm"

success "Windows VM tool installed (omarchy-windows-vm install|launch|stop|status|remove)"
