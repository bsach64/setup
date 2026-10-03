#!/bin/bash
# installs/uninstalls an Ubuntu arm64 VM (qemu + hvf) on Apple Silicon.
# use vm to turn it on and off once installed.
#
#   ./setup-vm.sh install        # fetch image, create disk, seed, ssh config, vm on PATH
#   ./setup-vm.sh uninstall      # stop the VM and throw it away
#
# install is safe to re-run: skips whatever already exists.
#
# knobs: VM_NAME VM_DISK VM_SSH_PORT
set -euxo pipefail

VM_NAME=${VM_NAME:-dev}
VM_DISK=${VM_DISK:-250G}
VM_SSH_PORT=${VM_SSH_PORT:-2222}

VM_DIR=$HOME/vms/$VM_NAME
IMAGE_URL=https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-arm64.img
BASE_IMAGE=$HOME/vms/noble-server-cloudimg-arm64.img
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

install() {
	if [ "$(uname -m)" != "arm64" ]; then
		echo "only Apple Silicon is supported" >&2
		exit 1
	fi

	QEMU_SHARE=$(brew --prefix qemu)/share/qemu
	mkdir -p $VM_DIR

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

	echo "adding vm to PATH.."
	# ~/.local/bin is on PATH via .zshrc
	mkdir -p $HOME/.local/bin
	ln -sf $SCRIPT_DIR/vm $HOME/.local/bin/vm

	echo "$VM_NAME installed, start it with vm on"
}

uninstall() {
	echo "stopping $VM_NAME.."
	if [ -f $VM_DIR/vm.pid ] && kill -0 "$(cat $VM_DIR/vm.pid)" 2>/dev/null; then
		$SCRIPT_DIR/vm off
	fi

	echo "removing $VM_DIR.."
	rm -rf $VM_DIR

	echo "removing ssh config.."
	if [ -f $HOME/.ssh/config ]; then
		# drop the Host block and its indented lines
		awk -v host="Host $VM_NAME" '
			$0 == host { skip = 1; next }
			skip && /^[ \t]/ { next }
			{ skip = 0; print }
		' $HOME/.ssh/config >$HOME/.ssh/config.tmp
		# cat instead of mv so a symlinked config stays a symlink
		cat $HOME/.ssh/config.tmp >$HOME/.ssh/config
		rm $HOME/.ssh/config.tmp
	fi

	echo "removing vm from PATH.."
	rm -f $HOME/.local/bin/vm

	# base image is shared between VMs, so it stays
	echo "$VM_NAME uninstalled, base image kept at $BASE_IMAGE"
}

case "${1:-}" in
install) install ;;
uninstall) uninstall ;;
*)
	echo "usage: $0 install|uninstall" >&2
	exit 1
	;;
esac
