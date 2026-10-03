#!/bin/bash
# creates (first run) and boots an Ubuntu arm64 VM with qemu + hvf on Apple Silicon.
# safe to re-run: skips whatever already exists, and does nothing if the VM is running.
#
#   ssh devvm                    # get in
#   ssh devvm sudo poweroff      # stop
#   rm -rf ~/vms/devvm           # throw it away, next run starts fresh
#
# knobs: VM_NAME VM_CPUS VM_MEM VM_DISK VM_SSH_PORT
set -euxo pipefail

VM_NAME=${VM_NAME:-devvm}
VM_CPUS=${VM_CPUS:-$(($(sysctl -n hw.ncpu) / 2))}
VM_MEM=${VM_MEM:-8G}
VM_DISK=${VM_DISK:-60G}
VM_SSH_PORT=${VM_SSH_PORT:-2222}

VM_DIR=$HOME/vms/$VM_NAME
IMAGE_URL=https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img
BASE_IMAGE=$HOME/vms/noble-server-cloudimg-arm64.img
QEMU_SHARE=$(brew --prefix qemu)/share/qemu

if [ "$(uname -m)" != "arm64" ]; then
	echo "only Apple Silicon is supported" >&2
	exit 1
fi

mkdir -p $VM_DIR

if [ -f $VM_DIR/vm.pid ] && kill -0 "$(cat $VM_DIR/vm.pid)" 2>/dev/null; then
	echo "$VM_NAME already running, ssh $VM_NAME"
	exit 0
fi

echo "fetching ubuntu cloud image.."
if [ ! -f $BASE_IMAGE ]; then
	curl -fL $IMAGE_URL -o $BASE_IMAGE.part
	mv $BASE_IMAGE.part $BASE_IMAGE
fi

echo "creating disk.."
if [ ! -f $VM_DIR/disk.qcow2 ]; then
	# copy-on-write overlay, base image stays untouched and is shared between VMs
	qemu-img create -f qcow2 -F qcow2 -b $BASE_IMAGE $VM_DIR/disk.qcow2 $VM_DISK
fi

echo "creating uefi vars.."
if [ ! -f $VM_DIR/efi-vars.fd ]; then
	# renamed from edk2-arm-vars.fd in newer qemu
	VARS=$QEMU_SHARE/edk2-aarch64-vars.fd
	[ -f $VARS ] || VARS=$QEMU_SHARE/edk2-arm-vars.fd
	cp $VARS $VM_DIR/efi-vars.fd
fi

echo "creating cloud-init seed.."
if [ ! -f $VM_DIR/seed.iso ]; then
	[ -f $HOME/.ssh/id_ed25519.pub ] || ssh-keygen -t ed25519 -N "" -f $HOME/.ssh/id_ed25519

	mkdir -p $VM_DIR/seed
	cat >$VM_DIR/seed/meta-data <<EOF
instance-id: $VM_NAME-$(date +%s)
local-hostname: $VM_NAME
EOF
	cat >$VM_DIR/seed/user-data <<EOF
#cloud-config
users:
  - name: $USER
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - $(cat $HOME/.ssh/id_ed25519.pub)
package_update: true
packages:
  - git
  - curl
  - build-essential
EOF
	hdiutil makehybrid -iso -joliet -default-volume-name cidata -o $VM_DIR/seed.iso $VM_DIR/seed
fi

echo "adding ssh config.."
mkdir -p $HOME/.ssh
touch $HOME/.ssh/config
if ! grep -q "^Host $VM_NAME\$" $HOME/.ssh/config; then
	cat >>$HOME/.ssh/config <<EOF

Host $VM_NAME
	HostName 127.0.0.1
	Port $VM_SSH_PORT
	User $USER
	ForwardAgent yes
	StrictHostKeyChecking no
	UserKnownHostsFile /dev/null
	LogLevel ERROR
EOF
fi

echo "booting $VM_NAME.."
qemu-system-aarch64 \
	-name $VM_NAME \
	-machine virt -accel hvf -cpu host \
	-smp $VM_CPUS -m $VM_MEM \
	-drive if=pflash,format=raw,readonly=on,file=$QEMU_SHARE/edk2-aarch64-code.fd \
	-drive if=pflash,format=raw,file=$VM_DIR/efi-vars.fd \
	-drive if=virtio,format=qcow2,file=$VM_DIR/disk.qcow2 \
	-drive if=virtio,format=raw,readonly=on,file=$VM_DIR/seed.iso \
	-nic user,model=virtio-net-pci,hostfwd=tcp:127.0.0.1:$VM_SSH_PORT-:22 \
	-device virtio-rng-pci \
	-display none \
	-serial file:$VM_DIR/console.log \
	-pidfile $VM_DIR/vm.pid \
	-daemonize

echo "waiting for ssh (first boot takes a minute, see $VM_DIR/console.log).."
for _ in $(seq 120); do
	ssh -o ConnectTimeout=2 $VM_NAME true 2>/dev/null && break
	sleep 2
done
ssh $VM_NAME cloud-init status --wait

echo "$VM_NAME is up, ssh $VM_NAME"
