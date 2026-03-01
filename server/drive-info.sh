#!/bin/bash
# Server Tools: Drive information viewer
[[ -z ${OMARCHY_SERVER_HELPERS:-} ]] && source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"

info "Installing drive info tool..."

ensure_dir "$HOME/.local/bin"

cat > "$HOME/.local/bin/omarchy-drive-info" << 'SCRIPT'
#!/bin/bash
# Display drive information: size, vendor, model, partitions, filesystem

if (( $# == 0 )); then
  echo "Usage: omarchy-drive-info [/dev/drive]"
  echo
  echo "Available drives:"
  lsblk -dpo NAME,SIZE,VENDOR,MODEL 2>/dev/null | head -20
  exit 1
fi

drive="$1"

# Find the root drive in case we are looking at partitions
root_drive=$(lsblk -no PKNAME "$drive" 2>/dev/null | tail -n1)
if [[ -n $root_drive ]]; then
  root_drive="/dev/$root_drive"
else
  root_drive="$drive"
fi

# Get basic disk information
size=$(lsblk -dno SIZE "$drive" 2>/dev/null)
vendor=$(lsblk -dno VENDOR "$root_drive" 2>/dev/null | sed 's/ *$//')
model=$(lsblk -dno MODEL "$root_drive" 2>/dev/null | sed 's/ *$//')

# Combine vendor and model, avoiding duplication
label=""
if [[ -n $vendor && -n $model ]]; then
  if [[ $model == *$vendor* ]]; then
    label="$model"
  else
    label="$vendor $model"
  fi
elif [[ -n $model ]]; then
  label="$model"
elif [[ -n $vendor ]]; then
  label="$vendor"
fi

# Format display string
display="$drive"
[[ -n $size ]] && display="$display ($size)"
[[ -n $label ]] && display="$display - $label"

# Append compact partition summary
part_summary=$(lsblk -nro TYPE,NAME,FSTYPE,MOUNTPOINT "$root_drive" 2>/dev/null | \
  awk '$1=="part" { printf "%s%s%s", s, ($3==""?"unknown":$3), ($4==""?"":"("$4")"); s=", " }')
[[ -n $part_summary ]] && display+=" [$part_summary]"

echo "$display"
SCRIPT

chmod +x "$HOME/.local/bin/omarchy-drive-info"

success "Drive info tool installed (omarchy-drive-info)"
