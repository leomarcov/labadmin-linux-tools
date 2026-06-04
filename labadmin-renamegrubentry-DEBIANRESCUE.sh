#!/usr/bin/env bash
#===================================================================================
# RENAME GRUB ENTRY TO DEBIANRESCUE
#         FILE: labadmin-renamegrubentry-DEBIANRESCUE.sh
#
#  DESCRIPTION: Rename second partition (gpt2) to DEBIAN RESCUE 
#
#       AUTHOR: Leonardo Marco (labadmin@leonardomarco.com)
#	   LICENSE: GNU General Public License v3.0
#      VERSION: 2026.06
#      CREATED: 2026.06.01
#===================================================================================

echo "LABADMIN: Renaming /boot/grub/grub.cfg menuentry sda2 to: DEBIAN RESCUE"
mel=$(cat -n /boot/grub/grub.cfg | sed -n '/menuentry.*{$/,/}$/p' | grep -E "menuentry\b|set root=.*gpt2" | grep gpt2 -B1 | grep menuentry | awk '{print $1}' | head -1)
[ "$mel" -eq "$mel" ] &>/dev/null || { echo "sda2 menuentry line not found"; exit 1; }
sed  -i "${mel} s/'[^']*'/'DEBIAN RESCUE'/" /boot/grub/grub.cfg
