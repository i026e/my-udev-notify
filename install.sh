#!/bin/bash


PLACEHOLDER="\$UDEV_NOTIFY_SCRIPT_PATH"
UDEV_FILE="/etc/udev/rules.d/99-my-udev-notify.rules"


DIR="$(dirname $(readlink -f "$0"))"
SCRIPT_PATH="$DIR/my-udev-notify.sh"
echo $SCRIPT_PATH



echo "Deleting $UDEV_FILE"
sudo rm "$UDEV_FILE"


echo "Copying new rules to $UDEV_FILE"
echo "#################"
sed  "s|$PLACEHOLDER|$SCRIPT_PATH|g" <"./stuff/my-udev-notify.rules" | sudo tee "$UDEV_FILE"
echo "#################"

#sudo rm "/etc/udev/rules.d/my-udev-notify.rules"
#sudo cp "./stuff/my-udev-notify.rules" "/etc/udev/rules.d/my-udev-notify.rules"
