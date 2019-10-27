#!/usr/bin/env bash

# Some of this code copied shamelessly from the pi-hole basic-install.sh script found
# at https://install.pi-hole.net

# Parse the output of udevadm, looking for the device associated with a touchscreen
function get_touchscreen_dev()
{
local IFS=$'\n'
local NEWDEV=".BLOCK"

for i in $(udevadm info --export-db | sed -e "s/^$/${NEWDEV}/") ; do
    [[ $i == *"ID_INPUT_TOUCHSCREEN"* ]] && _DEVID=${i}
    [[ $i == *DEVNAME=* ]] && _DEVNAME=${i#*=}

    if [[ "$i" == "$NEWDEV" ]] ; then
        if [[ "$_DEVNAME" != "" && "$_DEVID" != "" ]] ; then
            echo $_DEVNAME
            return
        fi
        unset _DEVNAME
        unset _DEVID
    fi
done
}

# This is a file used for the colorized output
coltable=/opt/pihole/COL_TABLE

# If the color table file exists,
if [[ -f "${coltable}" ]]; then
    # source it
    source ${coltable}
# Otherwise,
else
    # Set these values so the installer can still run in color
    COL_NC='\e[0m' # No Color
    COL_LIGHT_GREEN='\e[1;32m'
    COL_LIGHT_RED='\e[1;31m'
    TICK="[${COL_LIGHT_GREEN}✓${COL_NC}]"
    CROSS="[${COL_LIGHT_RED}✗${COL_NC}]"
    INFO="[i]"
    # shellcheck disable=SC2034
    DONE="${COL_LIGHT_GREEN} done!${COL_NC}"
    OVER="\\r\\033[K"
fi

# Check if we are running on a real terminal and find the rows and columns
# If there is no real terminal, we will default to 80x24
if [ -t 0 ] ; then
  screen_size=$(stty size)
else
  screen_size="24 80"
fi
# Set rows variable to contain first number
printf -v rows '%d' "${screen_size%% *}"
# Set columns variable to contain second number
printf -v columns '%d' "${screen_size##* }"

# Divide by two so the dialogs take up half of the screen, which looks nice.
r=$(( rows / 2 ))
c=$(( columns / 2 ))
# Unless the screen is tiny
r=$(( r < 20 ? 20 : r ))
c=$(( c < 70 ? 70 : c ))

# interface_filename;off_value;on_value
TOUCHSCREEN_BACKLIGHT_INTERFACES=$(cat << EOM
/sys/class/backlight/rpi_backlight/bl_power;1;0
/sys/class/backlight/soc:backlight/bl_power;1;0
EOM
)

TOUCHSCREEN_INPUT_DEVICES=$(cat << EOM
/dev/input/touchscreen
/dev/input/event0
EOM
)

PIHOLE_FILES=$(cat <<EOM
/etc/pihole/setupVars.conf
/usr/local/bin/pihole
/opt/pihole/version.sh
EOM
)

PHAD_FILES=$(cat <<EOM
phad
phad.conf
templates/main.j2
EOM
)

REQUIREMENTS="jinja2>==2.10 requests>==2.19"

for i in ${PIHOLE_FILES} ; do
    if [ ! -f $i ] ; then
        printf "  %b %s\\n" "${CROSS}" "File $i not found\\n"
        printf "  %b %bPi-hole's basic installer installs this file as part of its setup.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "      This file does not exist, which means Pi-hole is not installed or has\\n"
        printf "      been installed in a custom location. This phad installer script assumes\\n"
        printf "      that Pi-hole was installed with default settings. Please see the phad\\n"
        printf "      README file for instructions on installing phad manually.\\n"
        exit 1
    fi
done

grep -q -i phad ${HOME}/.bashrc
if [[ $? -eq 0 ]] ; then
    printf "  %b %s\\n" "${CROSS}" "phad already configured to run"
    printf "      Referenes to phad exist in ${HOME}/.bashrc.\\n"
    printf "      For this reason the installer refuses to run. Please see the\\n"
    printf "      README file for instructions on installing phad manually.\\n"
    exit 1
fi

# -e option instructs bash to immediately exit if any command [1] has a non-zero exit status
# We do not want users to end up with a partially working install, so we exit the script
# instead of continuing the installation with something broken
set -e

PHAD_DIR="${HOME}/phad"
mkdir -p $PHAD_DIR

if [ ! -d $PHAD_DIR ] ; then
    printf "  %b %s\\n" "${CROSS}" "Directory $PHAD_DIR not found"
    printf "  %b %bphad installs into this directory but this installer was unable to create it. Aborting.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
    exit 1
fi

cd $PHAD_DIR

for i in ${PHAD_FILES} ; do
    if [ -f "$i" ] ; then
        printf "  %b %s\\n" "${CROSS}" "phad file $i exists"
        printf "  %b %bphad appears to already be installed in $PHAD_DIR. Aborting.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        exit 1
    fi
done

printf "  %b %bChecking for touchscreen backlight interface%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
for i in ${TOUCHSCREEN_BACKLIGHT_INTERFACES}; do
    TS_FILE="$(cut -d ';' -f1 <<< "${i}")"
    TS_OFF="$(cut -d ';' -f2 <<< "${i}")"
    TS_ON="$(cut -d ';' -f3 <<< "${i}")"
    if [[ -f "${TS_FILE}" && "${BACKLIGHT_FILE}" == "" ]] ; then
        if whiptail --title "Touchscreen backlight interface" --yesno "A potential interface for your touchscreen backlight has been found at ${TS_FILE}. Would you like to test this in order to enable touchscreen blanking? If you choose 'yes' then this installer will attempt to make the LCD display go blank for 5 seconds and then turn it on again. Would you like to do this?" ${r} ${c}; then
            [ -w ${TS_FILE} ] || REQUIRE_SUDO=1

            printf "Attempting to blank LCD display in "
            for i in $(seq 5 -1 1) ; do printf "${i}... " ; sleep 1 ; done
            printf "\\n"

            if [ "$REQUIRE_SUDO" == "1" ] ; then
                sudo sh -c "echo '${TS_OFF}' > ${TS_FILE}"
            else
                echo "${TS_OFF}" > ${TS_FILE}
            fi

            for i in $(seq 5 -1 1) ; do printf "${i}... " ; sleep 1 ; done
            printf "\\n"

            if [ "$REQUIRE_SUDO" == "1" ] ; then
                sudo sh -c "echo '${TS_ON}' > ${TS_FILE}"
            else
                echo "${TS_ON}" > ${TS_FILE}
            fi

            if whiptail --defaultno --title "Touchscreen backlight interface" --yesno "Did your touchscreen go blank?" ${r} ${c}; then
                BACKLIGHT_FILE=${TS_FILE}
		BACKLIGHT_CMD_OFF=${TS_OFF}
		BACKLIGHT_CMD_ON=${TS_ON}
                printf "\\n"
                printf "  %b %s\\n" "${TICK}" "Found touchscreen backlight interface: ${BACKLIGHT_FILE}"
                printf "\\n"
            fi
        fi
    fi
done

ts_dev=$(get_touchscreen_dev)
RE='^[0-9]*$'
T="x"

if [ "$ts_dev" != "" ] ; then
    if whiptail --title "Touchscreen interface" --yesno "A touch interfface was found at ${ts_dev}. Would you like phad to wake up when you touch the touchscreen?" ${r} ${c}; then
        TOUCHSCREEN_DEV=${ts_dev}
        REQUIREMENTS="$REQUIREMENTS evdev>==1.0.0"
	while ! [[ $T =~  $RE ]] ; do
		T=$(whiptail --title "Touchscreen timeout" --inputbox "How many seconds after tapping on the display should phad blank the screen again?" ${r} ${c} 10 3>&1 1>&2 2>&3) 
	done
	[ "$T" != "" ] && MAIN_TIMEOUT=$T
    fi
fi

if [[ "$TOUCHSCREEN_DEV" == "" ]] ; then
    T="x"
    while ! [[ $T =~  $RE ]] ; do
        T=$(whiptail --title "Display cycle time" --inputbox "How many seconds shold phad wait between switching its display?" ${r} ${c} 20 3>&1 1>&2 2>&3)
    done
    [ "$T" != "" ] && TEMPLATE_TIMEOUT="-s $T"
fi

declare -a TEMPLATE_LIST=()
if [[ "TOUCHSCREEN_DEV" != "" && "$BACKLIGHT_FILE" == "" ]] ; then
    TEMPLATE_LIST+=("blank.j2" "A blank screen to simulate turning off the display" ON)
fi

TEMPLATE_LIST+=("main.j2" "The main phad summary screen" ON)
TEMPLATE_LIST+=("top_ads.j2" "A list of the top ads blocked by your Pi-Hole" ON)
TEMPLATE_LIST+=("top_clients.j2" "A list of the top clients using your Pi-Hole" ON)
TEMPLATE_LIST+=("top_domains.j2" "A list of the top domains resolved by your Pi-Hole" ON)
TEMPLATE_LIST+=("network.j2" "A summary of your Pi-Hole's network settings" ON)

L=${#TEMPLATE_LIST[@]} 
N=$(( L / 3 ))

while [[ "$TL" == "" ]] ; do
    TL=$(whiptail --title "Select pages phad should cycle between" --checklist "Select the templates that phad should cycle between" ${r} ${c} $N "${TEMPLATE_LIST[@]}" 3>&1 1>&2 2>&3)
done
TEMPLATES=$(echo $TL | sed -e 's/"//g' -e 's/ /,/'g)

printf "  %b %bInstalling python dependencies:%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
for i in ${REQUIREMENTS} ; do
    printf "      - %s\\n" "${i}"
done
pip install -q ${REQUIREMENTS}
printf "  %b %s\\n" "${TICK}" "Installed python dependencies"

DL_URL=$(curl --silent "https://api.github.com/repos/bpennypacker/phad/releases/latest" | grep tarball_url | sed -e 's/^.*\: "//' -e 's/".*$//')
printf "\\n"
printf "  %b %bDownloading phad from %s%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${DL_URL}" "${COL_NC}"
curl --silent -L $DL_URL | tar xz --strip-components=1
printf "  %b %s\\n" "${TICK}" "Successfully downloaded phad"

for i in ${PHAD_FILES} ; do
    if [ ! -f "$i" ] ; then
        printf "  %b %s\\n" "${CROSS}" "phad file $i not found"
        printf "  %b %bphad appears to have failed to download properly.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
        printf "      Check that $DL_URL is valid.\\n"
        printf "      If that URL is valid then remove the current phad directory and.\\n"
        printf "      try running this installer again.\\n"
        exit 1
    fi
done

CMD=" "

if [[ "$BACKLIGHT_FILE" != "" ]] ; then
    F=$(echo $BACKLIGHT_FILE | sed -e s'/\//\\\//g')
    CMD="$CMD -e s/^file_location=.*$/file_location=$F/"
    CMD="$CMD -e s/^on_value=.*$/on_value=$BACKLIGHT_CMD_ON/"
    CMD="$CMD -e s/^off_value=.*$/off_value=$BACKLIGHT_CMD_OFF/"
    CMD="$CMD -e s/^enabled=.*$/enabled=True/"
    if [[ "$REQUIRE_SUDO" == "" ]] ; then
        CMD="$CMD -e s/^use_sudo=.*$/use_sudo=False/"
    else
        CMD="$CMD -e s/^use_sudo=.*$/use_sudo=True/"
    fi
else
    CMD="$CMD -e s/^enabled=.*$/enabled=False/"
fi

if [[ "$TOUCHSCREEN_DEV" != "" ]] ; then
    F=$(echo $TOUCHSCREEN_DEV | sed -e s'/\//\\\//g')
    CMD="$CMD -e s/^input_device=.*$/input_device=$F/"
else
    CMD="$CMD -e s/^input_device=/#input_device=/"
fi

CMD="$CMD -e s/^templates=.*$/templates=$TEMPLATES/"
 
if [[ "$MAIN_TIMEOUT" != "" ]] ; then
  CMD="$CMD -e s/^main_timeout=.*$/main_timeout=$MAIN_TIMEOUT/"
else
  CMD="$CMD -e s/^enable_main_timeout=.*$/enable_main_timeout=False/"
fi

cp ${HOME}/phad.conf.test phad.conf
mv phad.conf phad.conf.original
cat phad.conf.original | sed $CMD > phad.conf

printf "  %b %s\\n" "${TICK}" "Customized phad.conf"

BASH_TXT=$(cat << EOM
if [ "\$TERM" == "linux" ] ; then
  cd ${PHAD_DIR}
  while :
  do
    ./phad ${TEMPLATE_TIMEOUT} 2>/dev/null
    sleep 10
  done
fi
EOM
)

BASHRC=${HOME}/.bashrc
IFS=$'\n'

if whiptail --defaultno --title "Start phad automatically" --yesno "Would you like phad to start up automatically by adding it to the pi users .bashrc file?" ${r} ${c}; then
    echo "" >> $BASHRC
    echo "# Start phad" >> $BASHRC
    for i in ${BASH_TXT} ; do
        echo ${i} >> $BASHRC
    done

    if whiptail --defaultno --title "Reboot?" --yesno "Your Raspberry Pi needs to be rebooted for phad to start. Reboot now?" ${r} ${c}; then
        sudo reboot
    else
        printf "  %b %s\\n" "${TICK}" "phad installation complete"
    fi
else
    printf "  %b %s\\n" "${TICK}" "phad installation complete"
    printf "  %b %bphad has not been configured to start automatically.%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "  %b %bTo start phad add something like this to your .bashrc file:%b\\n" "${INFO}" "${COL_LIGHT_RED}" "${COL_NC}"
    printf "\\n"
    for i in ${BASH_TXT} ; do
        printf "    %s\\n" "$i"
    done
fi
