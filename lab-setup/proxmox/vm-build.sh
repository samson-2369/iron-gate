#!/bin/bash
# iron-gate Proxmox VM build script
# Run as root on the Proxmox host (YOUR_PROXMOX_IP)
set -e

UBIMG="/var/lib/vz/template/iso/jammy-server-cloudimg-amd64.img"
KALI_IMG="/tmp/kali-cloud.qcow2"
SSHKEY_FILE="/tmp/iron_gate.pub"
GW="10.0.0.1"
DNS="8.8.8.8"
# Set VM_PASSWORD env var before running: export VM_PASSWORD=your_password
PASS="${VM_PASSWORD:-changeme}"

check_prereqs() {
  [ -f "$UBIMG" ] || { echo "ERROR: Ubuntu 22.04 cloud image not found at $UBIMG"; exit 1; }
  [ -f "$KALI_IMG" ] || { echo "ERROR: Kali cloud image not found at $KALI_IMG"; exit 1; }
  [ -f "$SSHKEY_FILE" ] || { echo "ERROR: SSH public key not found at $SSHKEY_FILE"; exit 1; }
}

create_vm() {
  local VMID=$1 NAME=$2 RAM=$3 DISK=$4 IP=$5 USER=$6 IMG=$7

  echo "[*] Creating VM $VMID: $NAME ($IP)"

  qm create $VMID \
    --name "$NAME" \
    --memory $RAM \
    --cores 1 \
    --net0 virtio,bridge=vmbr0 \
    --ostype l26 \
    --scsihw virtio-scsi-pci \
    --cpu host \
    --onboot 0

  qm importdisk $VMID "$IMG" local-lvm --format raw 2>&1 | tail -1

  qm set $VMID \
    --scsi0 "local-lvm:vm-${VMID}-disk-0,discard=on" \
    --ide2 local-lvm:cloudinit \
    --boot order=scsi0 \
    --serial0 socket \
    --vga serial0

  qm set $VMID \
    --ciuser "$USER" \
    --cipassword "$PASS" \
    --sshkeys "$SSHKEY_FILE" \
    --ipconfig0 "ip=${IP}/24,gw=${GW}" \
    --nameserver "$DNS" \
    --searchdomain "iron-gate.lab"

  qm resize $VMID scsi0 $DISK
  echo "[+] $NAME ready"
}

check_prereqs

create_vm 301 "iron-gate-api"      2048 20G 10.0.0.100 ubuntu "$UBIMG"
create_vm 302 "iron-gate-attacker" 2048 25G 10.0.0.101 kali   "$KALI_IMG"
create_vm 303 "iron-gate-monitor"  3072 25G 10.0.0.102 ubuntu "$UBIMG"
create_vm 304 "iron-gate-ot"       2048 15G 10.0.0.103 ubuntu "$UBIMG"

echo ""
echo "[*] Starting VMs..."
for VMID in 301 302 303 304; do
  qm start $VMID
  sleep 3
done

echo "[+] Done. Allow 2 minutes for cloud-init to complete."
echo ""
echo "    ssh -i ~/.ssh/iron_gate ubuntu@10.0.0.100  # iron-gate-api"
echo "    ssh -i ~/.ssh/iron_gate kali@10.0.0.101    # iron-gate-attacker"
echo "    ssh -i ~/.ssh/iron_gate ubuntu@10.0.0.102  # iron-gate-monitor"
echo "    ssh -i ~/.ssh/iron_gate ubuntu@10.0.0.103  # iron-gate-ot"
