export SHELL = sh

RSA_KEY = 425C42BE
PPA = i026e/udev-notify

DIR="$(dirname $(readlink -f "$0"))"

ifndef DESTDIR
	DESTDIR = "./debian/$(PACKAGE)/"
endif

CONF_PATH = /etc
BIN_PATH = /usr/share/bin
UDEV_RULES_PATH = /etc/udev/rules.d
SOUND_PATH = /usr/share/sounds/my-udev-notify

all:

install:
	[ ! -d "$(DESTDIR)" ] || rm -rf "$(DESTDIR)"

	mkdir -p "$(DESTDIR)/$(BIN_PATH)"
	mkdir -p "$(DESTDIR)/$(UDEV_RULES_PATH)"
	mkdir -p "$(DESTDIR)/$(SOUND_PATH)"
	mkdir -p "$(DESTDIR)/$(CONF_PATH)"

	cp ./src/my-udev-notify "$(DESTDIR)/$(BIN_PATH)/"
	cp ./src/99-my-udev-notify.rules "$(DESTDIR)/$(UDEV_RULES_PATH)/"

	cp ./sounds/plug_sound.wav "$(DESTDIR)/$(SOUND_PATH)/"
	cp ./sounds/unplug_sound.wav "$(DESTDIR)/$(SOUND_PATH)/"

	cp -r ./config/my-udev-notify.conf "$(DESTDIR)/$(CONF_PATH)/"

	sed -i "s|UDEV_NOTIFY_SCRIPT_PATH|$(BIN_PATH)/my-udev-notify|g" "$(DESTDIR)/$(UDEV_RULES_PATH)/99-my-udev-notify.rules"

	sed -i "s|SOUND_PATH_PLUG|$(SOUND_PATH)/plug_sound.wav|g" "$(DESTDIR)/$(BIN_PATH)/my-udev-notify"
	sed -i "s|SOUND_PATH_UNPLUG|$(SOUND_PATH)/unplug_sound.wav|g" "$(DESTDIR)/$(BIN_PATH)/my-udev-notify"

	sed -i "s|SOUND_PATH_PLUG|$(SOUND_PATH)/plug_sound.wav|g" "$(DESTDIR)/$(CONF_PATH)/my-udev-notify.conf"
	sed -i "s|SOUND_PATH_UNPLUG|$(SOUND_PATH)/unplug_sound.wav|g" "$(DESTDIR)/$(CONF_PATH)/my-udev-notify.conf"


	chmod --recursive 755 "$(DESTDIR)"

arch:
	cd ./arch
	makepkg -f

debian:
	#dh_make --createorig
	dpkg-source --commit
	debuild -us -uc
	debuild -S -k"$RSA_KEY"
	dput -f ppa:$PPA ../*_source.changes

clean:
	rm -rf "$(DESTDIR)"
