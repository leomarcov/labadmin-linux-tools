echo "LABADMIN: Renaming /boot/grub/grub.cfg menuentry sda2 to: DEBIAN RESCUE"
mel=$(cat -n /boot/grub/grub.cfg | sed -n '/menuentry.*{$/,/}$/p' | grep -E "menuentry\b|set root=.*gpt2" | grep gpt2 -B1 | grep menuentry | awk '{print $1}' | head -1)
[ "$mel" -eq "$mel" ] &>/dev/null || { echo "sda2 menuentry line not found"; exit 1; }
sed  -i "${mel} s/'[^']*'/'DEBIAN RESCUE'/" /boot/grub/grub.cfg
