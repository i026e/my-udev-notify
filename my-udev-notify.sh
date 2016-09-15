#!/bin/bash

# thanks:
#     - to guys from linux.org.ru;
#     - to 'iptable' user from ##linux at irc.freenode.net.

# test command:
#     sudo /bin/bash my-udev-notify -a add -p 'test_path' -b '555' -d '777'

# get path to this script
DIR="$(dirname $(readlink -f "$0"))"

# set default options {{{

# file for storing list of currently plugged devices
devlist_file="/var/tmp/udev-notify-devices"

# servers="localhost:4567 localhost:3456"
servers=
show_notifications=true
play_sounds=true

#canberra gtk sound
plug_sound="$DIR/sounds/plug_sound.wav"
unplug_sound="$DIR/sounds/unplug_sound.wav"
# }}}

# read config file {{{
{
   if [ -r /etc/my-udev-notify.conf ]; then
      . /etc/my-udev-notify.conf
   fi
   #if [ -r ~/.my-udev-notify.conf ]; then
      #. ~/.my-udev-notify.conf
   #fi
}
# }}}

# retrieve options from command line {{{

# action: "add" or "remove"
action=

# dev_path: path like /devices/pci0000:00/0000:00:1d.0/usb5/5-1
dev_path=

# bus number and device number:
# they are needed since device is also stored at /dev/bus/usb/<bus_num>/<dev_num>
bus_num=
dev_num=

while getopts a:p:b:d: opt; do
  case $opt in
  a)
      action=$OPTARG
      ;;
  p)
      dev_path=$OPTARG
      ;;
  b)
      bus_num=$OPTARG
      ;;
  d)
      dev_num=$OPTARG
      ;;
  esac
done

shift $((OPTIND - 1))
# }}}

show_visual_notification()
{
   # TODO: wait for 'iptable' user from ##linux to say how to do it better
   #       or, at least it's better to use 'who' command instead of 'w',
   #       because 'who' echoes display number like (:0), and echoes nothing if no display,
   #       which is more convenient to parse.

   local header=$1
   local text=$2

   text=`echo "$text" | sed 's/###/\n/g'`

   declare -a logged_users=(` who | grep "(.*)" | sed 's/^\s*\(\S\+\).*(\(.*\))/\1 \2/g' | uniq | sort`)

   if [[ ${#logged_users[@]} == 0 ]]; then
      # it seems 'who' doesn't echo displays, so let's assume :0 (better than nothing)
      declare -a logged_users=(`who | awk '{print $1" :0"}' | uniq | sort`)
   fi

   for (( i=0; i<${#logged_users[@]}; i=($i + 2) )); do
      cur_user=${logged_users[$i + 0]}
      cur_display=${logged_users[$i + 1]}

      export DISPLAY=$cur_display
      su $cur_user -c "notify-send '$header' '$text'"
   done
}

network_notification()
{
    local server=$1
    local header=$2
    local text=$3

    msg="${header}###${text}"
    arr=$(echo $server | tr ":" "\n")
    host=${arr[0]}
    port=${arr[1]}
    echo "$msg" | nc -q 0 $host $port
}


# notification for plugged device {{{
notify_plugged()
{
   local dev_title=$1

   if [[ $show_notifications == true ]]; then
      #notify-send "device plugged" "$dev_title" &
      show_visual_notification "device plugged" "$dev_title"
   fi
   if [[ $play_sounds == true ]]; then
      /usr/bin/aplay "$plug_sound"
   fi
   for server in $servers; do
       network_notification "$server" "plugged" "$dev_title"
   done
}
# }}}

# notification for unplugged device {{{
notify_unplugged()
{
   local dev_title=$1

   if [[ $show_notifications == true ]]; then
      #notify-send "device unplugged" "$dev_title" &
      show_visual_notification "device unplugged" "$dev_title"
   fi
   if [[ $play_sounds == true ]]; then
      /usr/bin/aplay "$unplug_sound"
   fi
   for server in $servers; do
       network_notification "$server" "unplugged" "$dev_title"
   done
}
# }}}

{
   # we need for lock our $devlist_file
   exec 200>/var/lock/.udev-notify-devices.exclusivelock
   flock -x -w 10 200 || exit 1
   case $action in

      "reboot" )
         rm $devlist_file
         ;;

      "add" )
         # ------------------- PLUG -------------------

         if [[ "$bus_num" != "" && "$dev_num" != "" ]]; then

            # make bus_num and dev_num have leading zeros
            bus_num=`printf %03d $bus_num`
            dev_num=`printf %03d $dev_num`

            # Retrieve device title. Currently it's done just by lsusb and grep.
            # Not so good: if one day lsusb change its output format, this script
            # might stop working.
            dev_title=`lsusb -D /dev/bus/usb/$bus_num/$dev_num | grep '^Device:\|bInterfaceClass\|bInterfaceSubClass\|bInterfaceProtocol'|sed 's/^\s*\([a-zA-Z]\+\):*\s*[0-9]*\s*/<b>\1:<\/b> /' | awk 1 ORS='###'`

            # Sometimes we might have the same device attached to different bus_num or dev_num:
            # in this case, we just modify bus_num and dev_num to the current ones.
            # At least, it often happens on reboot: during previous session, user plugged/unplugged
            # devices, and dev_num is increased every time. But after reboot numbers are reset,
            # so with this substitution we won't have duplicates in our devlist.
            escaped_dev_path=`echo "$dev_path" | sed 's/[\/&*.^$]/\\\&/g'`
            sed -i "s#^\([0-9]\{3\}:\)\{2\}\($escaped_dev_path\)#$bus_num:$dev_num:$dev_path#" $devlist_file

            # udev often generates many events for the same device
            # (I still don't know how to write udev rule to prevent it)
            # so we need to check if this device is already stored in our devlist file
            existing_dev_on_bus_cnt=`cat $devlist_file | grep "^$bus_num:$dev_num:" | awk 'END {print NR}'`

            if [[ $existing_dev_on_bus_cnt == 0 ]]; then
               # this device isn't stored yet in the devlist, so let's write it there.
               echo "$bus_num:$dev_num:$dev_path title=\"$dev_title\"" >> $devlist_file

               # and, finally, notify the user.
               notify_plugged "$dev_title"
            fi
         fi
         ;;

      "remove" )
         # ------------------- UNPLUG -------------------

         # Unfortunately, udev doesn't emit bus_num and dev_num for "remove" events,
         # and there's even no vendor_id and product_id.
         # But it emits dev_path. So we have to maintain our own plugged devices list.
         # Now we retrieve stored device title from our devlist by its dev_path.
         dev_title=`cat $devlist_file | grep "$dev_path " | sed 's/.*title=\"\(.*\)\".*/\1/g'`

         # remove that device from list (since it was just unplugged)
         cat $devlist_file | grep -v "$dev_path " > ${devlist_file}_tmp
         mv ${devlist_file}_tmp $devlist_file

         # if we have found title, then notify user, after all.
         if [[ "$dev_title" != "" ]]; then
            notify_unplugged "$dev_title"
         fi
         ;;

   esac

   #unlock $devlist_file
   flock -u 200
}



