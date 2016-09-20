export SHELL = sh

RSA_KEY = 425C42BE
PPA = i026e/udev-notify

DIR="$(dirname $(readlink -f "$0"))"
WORKING_DIR = ./debian/my-udev-notify

CONF_PATH = /etc
BIN_PATH = /usr/share/bin
UDEV_RULES_PATH = /etc/udev/rules.d
SOUND_PATH = /usr/share/sounds/my-udev-notify

all:

install:
	[ ! -d "$(WORKING_DIR)" ] || rm -rf "$(WORKING_DIR)"

	mkdir -p "$(WORKING_DIR)/$(BIN_PATH)"
	mkdir -p "$(WORKING_DIR)/$(UDEV_RULES_PATH)"
	mkdir -p "$(WORKING_DIR)/$(SOUND_PATH)"
	mkdir -p "$(WORKING_DIR)/$(CONF_PATH)"

	cp ./src/my-udev-notify "$(WORKING_DIR)/$(BIN_PATH)/"
	cp ./src/99-my-udev-notify.rules "$(WORKING_DIR)/$(UDEV_RULES_PATH)/"

	cp ./sounds/plug_sound.wav "$(WORKING_DIR)/$(SOUND_PATH)/"
	cp ./sounds/unplug_sound.wav "$(WORKING_DIR)/$(SOUND_PATH)/"

	cp -r ./config/my-udev-notify.conf "$(WORKING_DIR)/$(CONF_PATH)/"

	sed -i "s|UDEV_NOTIFY_SCRIPT_PATH|$(BIN_PATH)/my-udev-notify|g" "$(WORKING_DIR)/$(UDEV_RULES_PATH)/99-my-udev-notify.rules"

	sed -i "s|SOUND_PATH_PLUG|$(SOUND_PATH)/plug_sound.wav|g" "$(WORKING_DIR)/$(BIN_PATH)/my-udev-notify"
	sed -i "s|SOUND_PATH_UNPLUG|$(SOUND_PATH)/unplug_sound.wav|g" "$(WORKING_DIR)/$(BIN_PATH)/my-udev-notify"

	sed -i "s|SOUND_PATH_PLUG|$(SOUND_PATH)/plug_sound.wav|g" "$(WORKING_DIR)/$(CONF_PATH)/my-udev-notify.conf"
	sed -i "s|SOUND_PATH_UNPLUG|$(SOUND_PATH)/unplug_sound.wav|g" "$(WORKING_DIR)/$(CONF_PATH)/my-udev-notify.conf"


	chmod --recursive 755 "$(WORKING_DIR)"

debian:
	#dh_make --createorig
	dpkg-source --commit
	debuild -us -uc
	debuild -S -k"$RSA_KEY"
	dput -f ppa:$PPA ../*_source.changes

clean:
	rm -rf "$(WORKING_DIR)"
