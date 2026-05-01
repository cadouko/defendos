#!/usr/bin/env bash
# DefendOS – archiso profile definition
# shellcheck disable=SC2034

iso_name="defendos"
iso_label="DefendOS_$(date +%Y%m)"
iso_publisher="DefendOS Project <https://github.com/defendos/defendos>"
iso_application="DefendOS – Cybersecurity Live OS"
iso_version="1.0.0"
install_dir="arch"
buildmodes=('iso')
bootmodes=('uefi-x64.grub.esp')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')
bootstrap_tarball_compression=('zstd' '-T0' '--ultra' '-22')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/usr/local/bin/defendos-gui"]="0:0:755"
  ["/usr/local/bin/defendos-welcome"]="0:0:755"
  ["/usr/local/bin/tool-launcher"]="0:0:755"
  ["/etc/sudoers.d/live"]="0:0:440"
  ["/opt/defendos"]="0:0:755"
)
