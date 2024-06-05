#!/bin/bash
set -eo pipefail

#----------------------------------------------------------
# Fix Error: attempt to perform an operation not allowed by the security policy `@-'
# In file /etc/ImageMagick-6/policy.xml
# Comment this <!-- <policy domain="path" rights="none" pattern="@*"/> -->
#----------------------------------------------------------

# Parameters
while [ -n "$1" ]; do
  case "$1" in
    -r)
      echo "Resize option: On"
      RESIZE="true"
    ;;
    -f)
      echo "Use custom file: $2"
      FILE="$2"
      shift
    ;;
    -d)
      echo "Use custom directory: $2"
      DIR="$2"
      shift
    ;;
    --)
      shift
      break
    ;;
    *)
      echo "Error: $1 Wrong parameter"
      echo "Usage:"
      echo "  -r,    Resize image to primary display resolution"
      echo "  -f,    Use custom file"
      echo "  -d,    Use custom directory"
      echo ""
      echo "Note:"
      echo "   Do not mix [-f] and [-d] options"
      exit
    ;;
  esac
      shift
done

#----------------------------------------------------------

# Get display resolution
#
# Resolution for one display. No recomend to multi displays
#DISPSIZE=$(xdpyinfo | grep -oP "dimensions:\s+\K\S+")
#
# Resolution for primary display
DISPSIZE=$(xrandr -q | grep -oP '^.*primary\s\K\d+x\d+')

# For resize. Ignore Aspect Ratio !, Only Shrink Larger Images >, Only Enlarge Smaller Images <, Fill Area Flag ^
GEOMERTY="$DISPSIZE!"

#----------------------------------------------------------

# Regular colors in shell
C_BLACK='\033[0;30m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_PURPLE='\033[0;35m'
C_CYAN='\033[0;36m'
C_WHITE='\033[0;37m'
C_RES='\033[0m'

#----------------------------------------------------------

# user UID check
if [[ "$UID" == 0 ]]; then
  echo -e "Error:$C_RED Run $0 from not root!$C_RES"
  exit
fi

# ImageMagick path
MAGICK="/usr/bin/convert"
# Check if ImageMagick installed
if [[ ! -f "$MAGICK" ]]; then
  echo -e "Error:$C_RED ImageMagick not installed!$C_RES"
  exit
fi

#----------------------------------------------------------

# Create TMP directory
TEMPDIR="/tmp/wallpapers"
if [[ ! -d "$TEMPDIR" ]]; then
  echo "Create TMP directory"
  mkdir "$TEMPDIR" -p
fi

# Temp files
BGFILE="$TEMPDIR/bg.txt"
BG="$TEMPDIR/bg.png"
NEWWALL="$TEMPDIR/new_tmp_image.png"
TMP_IMAGE="$TEMPDIR/tmp_image.png"

#----------------------------------------------------------

# Default paths
WALLFILE="Default.jpg"
ORIGWALL="/usr/share/kf5/wallpapers/Next/contents/images_dark/$WALLFILE"
HOMEIMAGES="WallPapers"
DEFAULTWALLPAPER="$HOME/$HOMEIMAGES/default.jpg"
WALLPAPER="$HOME/$HOMEIMAGES/Custom.png"

if [[ ! -d "$HOME/$HOMEIMAGES" ]]; then
  echo "Create $HOME/$HOMEIMAGES"
  mkdir "$HOME/$HOMEIMAGES"
fi

#----------------------------------------------------------

# Language: RU, EN
BGLANG="RU"
# Position SystemInfo: Center, East, North, NorthEast, Northwest, South, SouthEast, SouthWest, West
POSITION="SouthEast"
# Some Monospace fonts: Courier-Bold, CourierNew, Ubuntu Mono Bold, DejaVu Sans Mono, FreeMono Bold
FONT="DejaVu-Sans-Mono-Bold"
# Text/font size
FONTSIZE="16"
# Text color: White, Black, Red, Green, Blue, Yellow, Orange ...
FILL="White"
# Background color: none, White, Black, Red, Green, Blue, Yellow, Orange ...
BFILL="none"
STROKEWIDTH="0"
STROKECOLOR="none"

#----------------------------------------------------------

# System info
R_HOSTNAME=$(hostname -f)
R_USERNAME=$USER
R_IPADRS=(`ip -o addr | grep -v "fe80" | awk '!/^[0-9]*: ?lo|link\/ether/ {print $2":"$4}'`)
R_MACADRS=$(ip -o link show | grep -v "lo" | cut -d ' ' -f 2,20)
R_DNSSERVER=$(grep ^nameserver /etc/resolv.conf | awk '{print $2}')
if [[ "$R_DNSSERVER" == "127.0.0.53" ]]; then
  if [[ -f /usr/bin/nmcli ]]; then
    R_DNSSERVER=(`nmcli dev show | grep DNS | awk '{print $2}'`)
  fi
fi
R_GATEWAY=$(ip route | grep default | cut -d' ' -f 3)
R_CPUMODEL=$(cat /proc/cpuinfo | grep "model name" | awk -F":" '{print $2}' | head -1 | sed -e 's/^ *//' -e 's/Intel(R) Core(TM) //')
R_NUMCPU=$(cat /proc/cpuinfo | grep processor | wc -l)
MEMTOTAL=$(grep "MemTotal:" /proc/meminfo | tr -d [\ a-zA-Z:])
SWAPTOTAL=$(grep "SwapTotal:" /proc/meminfo | tr -d [\ a-zA-Z:])
R_MEMGB=$(expr "$MEMTOTAL" / 1000 / 1000)
if [[ -n $SWAPTOTAL ]]; then
    SWAPGB=$(( "$SWAPTOTAL" / 1000 / 1000 ))
    R_SWAPGB="+ $SWAPGB SWAP"
fi

#----------------------------------------------------------

# Get OS version
if [ -f /etc/os-release ]; then
    . /etc/os-release
    R_OS=$NAME
    R_VERSION=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    R_OS=$(lsb_release -si)
    R_VERSION=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    R_OS=$DISTRIB_ID
    R_VERSION=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    R_OS=Debian
    R_VERSION=$(cat /etc/debian_version)
elif [ -f /etc/redhat-release ]; then
    R_OS=$(cat /etc/redhat-release | cut -d' ' -f1)
    R_VERSION=$(cat /etc/redhat-release | cut -d' ' -f3)
else
    R_OS=$(uname -s)
    R_VERSION=$(uname -r)
fi

# Get kernel version
R_KERNEL=$(uname -rm)

#----------------------------------------------------------

# KDE. Get User's wallpaper settings
if [[ $XDG_SESSION_DESKTOP == "KDE" ]]; then
  DEFAULT_IMG_PATH="$HOME/$HOMEIMAGES/contents/images"
  #DEFAULT_IMG_PATH="/usr/share/wallpapers/Next/contents/images"
  KDE_IMG_INDEX=$(awk -F'\\]\\[' '/\[Wallpaper\]\[org\.kde\.image\]\[General\]/ {print $2}' $HOME/.config/plasma-org.kde.plasma.desktop-appletsrc)
  ORIGWALL=$(kreadconfig5 --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" --group 'Containments' --group '1' --group 'Wallpaper' --group 'org.kde.image' --group 'General' --key 'Image' | sed 's|file://||')

  for ki in ${KDE_IMG_INDEX[@]}; do
    KDE_IMG_INDEX_FILE=$(kreadconfig5 --file "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" --group 'Containments' --group $ki --group 'Wallpaper' --group 'org.kde.image' --group 'General' --key 'Image' | sed 's|file://||')
    
    if [[ -f "$KDE_IMG_INDEX_FILE" ]]; then
      echo -e "Current KDE wallpaper $ki: $KDE_IMG_INDEX_FILE"
      echo -e "Image size            $ki:" $(identify -ping -format '%wx%h' $KDE_IMG_INDEX_FILE)
      KDE_CURR_WALLPAPERS+=("$KDE_IMG_INDEX_FILE")
    elif [[ -d "$KDE_IMG_INDEX_FILE" ]]; then
      KDE_IMG_INDEX_FILE="${KDE_IMG_INDEX_FILE}contents/images/$DISPSIZE.jpg"
      if [[ -f "$KDE_IMG_INDEX_FILE" ]]; then
        echo -e "Current KDE wallpaper $ki: $KDE_IMG_INDEX_FILE"
        echo -e "Image size            $ki:" $(identify -ping -format '%wx%h' $KDE_IMG_INDEX_FILE)
        KDE_CURR_WALLPAPERS+=("$KDE_IMG_INDEX_FILE")
      else
        echo -e "$C_RED
        Error: $KDE_IMG_INDEX_FILE File not found!$C_YELLOW
        Set Default wallpaper:$DEFAULTWALLPAPER $C_RES"
        #Set Default wallpaper:$DEFAULT_IMG_PATH/$DISPSIZE.jpg $C_RES"
        KDE_CURR_WALLPAPERS+=("$DEFAULTWALLPAPER")
        #KDE_CURR_WALLPAPERS+=("$DEFAULT_IMG_PATH/$DISPSIZE.jpg")
      fi
    fi

    done

  if [[ -z "$KDE_CURR_WALLPAPERS" ]]; then
    echo -e "Current KDE wallpaper:$C_PURPLE $ORIGWALL $C_RES"
    echo -e "Image size           :" $(identify -ping -format '%wx%h' $ORIGWALL)

    if [[ -z "$ORIGWALL"  ]]; then
      ORIGWALL="$DEFAULT_IMG_PATH/$DISPSIZE.jpg"
    fi

  fi
fi

#----------------------------------------------------------

# Function check path $ORIGWALL
function check_wallpaper () {
  if [[ ! -f "$ORIGWALL" ]]; then
    echo -e "Error:$C_RED File $ORIGWALL not found!$C_RES"
    echo -e "Set file:$C_YELLOW $DEFAULTWALLPAPER $C_RES"
    ORIGWALL="$DEFAULTWALLPAPER"
    #echo -e "Set file:$C_YELLOW $DEFAULT_IMG_PATH/$DISPSIZE.jpg $C_RES"
    #ORIGWALL="$DEFAULT_IMG_PATH/$DISPSIZE.jpg"
  fi
}

#----------------------------------------------------------

# MATE. Get User's wallpaper settings
if [[ $XDG_SESSION_DESKTOP == "mate" ]]; then
  ORIGWALL=$(gsettings get org.mate.background picture-filename | tr -d \')
  echo -e "Current MATE wallpaper:$C_PURPLE $ORIGWALL $C_RES"
  check_wallpaper
  WALLPAPER="$HOME/$HOMEIMAGES/Custom.png"
fi

#----------------------------------------------------------

# FLY. Get User's wallpaper settings
if [[ $XDG_SESSION_DESKTOP == "fly" ]]; then
  ORIGWALL=$(grep -oP "WallPaper=\K.*" $HOME/.fly/theme/current.themerc | tr -d '["]')
  echo -e "Current FLY wallpaper:$C_PURPLE $ORIGWALL $C_RES"
  check_wallpaper
  WALLPAPER="$HOME/$HOMEIMAGES/Custom.png"
fi

#----------------------------------------------------------

# if -f and -d options
if [[ ! -z "$FILE" && ! -z "$DIR" ]]; then
  echo -e "$C_RED
Error: Do not mix [-f] and [-d] options $C_RES"
  exit
fi


# Set custom wallpaper from file
if [ ! -z "$FILE" ]; then
  if [ ! -f "$FILE" ]; then
    echo -e "$C_RED
Error: File not found!$C_YELLOW
Set Default wallpaper:$DEFAULTWALLPAPER $C_RES"
ORIGWALL="$DEFAULTWALLPAPER"
KDE_CURR_WALLPAPERS=("")
    elif [ -f "$FILE" ]; then
      echo -e "Set wallpaper:$C_GREEN $FILE $C_RES"
      ORIGWALL="$FILE"
      ORIGNAME=$(echo $FILE | awk -F'/' '{print $NF}' | sed 's/.\w\w\w$/_new.png/')
      WALLPAPER="$HOME/$HOMEIMAGES/$ORIGNAME"
      KDE_CURR_WALLPAPERS=("")
      echo -e "To wallpaper:$C_GREEN $WALLPAPER $C_RES"
  fi
fi

# Set custom wallpaper from directory
if [ ! -z "$DIR" ]; then
  if [ ! -d "$DIR" ]; then
    echo -e "$C_RED
Error: Directory not exist!$C_YELLOW
Set Default wallpaper:$DEFAULTWALLPAPER $C_RES"
ORIGWALL="$DEFAULTWALLPAPER"
KDE_CURR_WALLPAPERS=("")
  elif [ -d "$DIR" ]; then
    ORIGWALL="$DIR/$DISPSIZE.jpg"
    if [ ! -f "$ORIGWALL" ]; then
      echo -e "$C_RED
Error: File not found!$C_YELLOW
Set Default wallpaper:$DEFAULTWALLPAPER $C_RES"
      ORIGWALL="$DEFAULTWALLPAPER"
    elif [ -f "$ORIGWALL" ]; then
      echo -e "Set wallpaper:$C_GREEN $ORIGWALL $C_RES"
      ORIGNAME=$(echo $ORIGWALL | awk -F'/' '{print $NF}' | sed 's/.\w\w\w$/_new.png/')
      WALLPAPER="$HOME/$HOMEIMAGES/$ORIGNAME"
      KDE_CURR_WALLPAPERS=("")
      echo -e "To wallpaper:$C_GREEN $WALLPAPER $C_RES"
    fi
  fi
fi

#----------------------------------------------------------

# BGINFO text
echo "" > "$BGFILE"

if [[ "$BGLANG" == "RU" ]]; then
  L_HOSTNAME="Имя узла     :"
  L_USERNAME="Пользователь :"
 L_IPADDRESS="IP Адрес     :"
   L_MACADRS="MAC Адрес    :"
   L_GATEWAY="Шлюз         :"
 L_DNSSERVER="DNS Сервер   :"
  L_CPUMODEL="Процессор    :"
  L_MEMTOTAL="ОЗУ (ГБ)     :"
 L_OSVERSION="Версия ОС    :"
    L_KERNEL="Версия ядра  :"
fi

if [[ "$BGLANG" == "EN" ]]; then
  L_HOSTNAME="Hostname       :"
  L_USERNAME="Username       :"
 L_IPADDRESS="IP Address     :"
   L_MACADRS="MAC Address    :"
   L_GATEWAY="Gateway        :"
 L_DNSSERVER="DNS Server     :"
  L_CPUMODEL="Cpu model      :"
  L_MEMTOTAL="RAM (GB)       :"
 L_OSVERSION="OS version     :"
    L_KERNEL="Kernel version :"
fi

# Export to BGFILE
echo "$L_HOSTNAME" "$R_HOSTNAME"             >> "$BGFILE"
echo "$L_USERNAME" "$R_USERNAME"             >> "$BGFILE"
for i in ${R_IPADRS[@]}; do
  echo "$L_IPADDRESS" "$i"                   >> "$BGFILE"
done
echo "$L_MACADRS" "$R_MACADRS"               >> "$BGFILE"
echo "$L_GATEWAY" "$R_GATEWAY"               >> "$BGFILE"
for d in ${R_DNSSERVER[@]}; do
  echo "$L_DNSSERVER" "$d"                   >> "$BGFILE"
done
echo "$L_CPUMODEL" "$R_NUMCPU x $R_CPUMODEL" >> "$BGFILE"
echo "$L_MEMTOTAL" "$R_MEMGB $R_SWAPGB"      >> "$BGFILE"
echo "$L_OSVERSION" "$R_OS $R_VERSION"       >> "$BGFILE"
echo "$L_KERNEL" "$R_KERNEL"                 >> "$BGFILE"
echo "" >> "$BGFILE"
echo "" >> "$BGFILE"
echo "" >> "$BGFILE"
echo "" >> "$BGFILE"

# Generate System info image
echo -e "$C_GREEN Generate System info image$C_RES"
cat "$BGFILE" | convert \
  -font "$FONT" -pointsize "$FONTSIZE" \
  -strokewidth "$STROKEWIDTH" -stroke "$STROKECOLOR" \
  -background "$BFILL" \
  -fill "$FILL" \
  label:@- "$BG" 

#----------------------------------------------------------

# Function update_wallpaper
function update_wallpaper() {
  
  if [[ ! -z $1  ]]; then
    ORIGWALL=$1
  fi
  
  if [[ ! -z $2  ]]; then
    WALLPAPER="$HOME/$HOMEIMAGES/Custom_$2.png"
  fi
  
  # Resize original image to display resolution
  if [[ "$RESIZE" == "true" ]]; then
    echo -e "$C_GREEN Resize original image to display resolution$C_RES"
    convert -resize "$GEOMERTY" -quality 100 "$ORIGWALL" "$TMP_IMAGE"
  else
    TMP_IMAGE="$ORIGWALL"
  fi

  # Composite images
  echo -e "$C_GREEN Composite images$C_RES"
  composite -gravity "$POSITION" "$BG" "$TMP_IMAGE" "$NEWWALL"

  # Copy new image
  echo -e "$C_GREEN Copy new image$C_RES"
  cp "$NEWWALL" "$WALLPAPER"

  echo -e "$C_GREEN Update wallpaper$C_RES"
  # Update wallpaper
}

#----------------------------------------------------------

# KDE setup wallpapers
if [[ "$XDG_SESSION_DESKTOP" == "KDE" ]]; then

  if [[ ! -z $KDE_CURR_WALLPAPERS ]]; then
    kdx=0
    for kimg in ${KDE_CURR_WALLPAPERS[@]}; do
        
      update_wallpaper $kimg $kdx
      
      echo -e "$C_YELLOW Set #$kdx : $WALLPAPER $C_RES"

      # Double change. KDE feature or bug (When path not changed, wallpaper will not change)...
      dbus-send --session --dest=org.kde.plasmashell --type=method_call /PlasmaShell org.kde.PlasmaShell.evaluateScript "string:
      var Desktops = desktops();
          d = Desktops[$kdx];
          d.wallpaperPlugin = \"org.kde.image\";
          d.currentConfigGroup = Array(\"Wallpaper\", \"org.kde.image\", \"General\");
          d.writeConfig(\"Image\", \"file://$TMP_IMAGE\");"

      dbus-send --session --dest=org.kde.plasmashell --type=method_call /PlasmaShell org.kde.PlasmaShell.evaluateScript "string:
      var Desktops = desktops();
          d = Desktops[$kdx];
          d.wallpaperPlugin = \"org.kde.image\";
          d.currentConfigGroup = Array(\"Wallpaper\", \"org.kde.image\", \"General\");
          d.writeConfig(\"Image\", \"file://$WALLPAPER\");"

      kdx=$(( $kdx + 1 ))
    done
  else
      update_wallpaper
      # Double change. KDE feature or bug (When path not changed, wallpaper will not change)...
      dbus-send --session --dest=org.kde.plasmashell --type=method_call /PlasmaShell org.kde.PlasmaShell.evaluateScript "string:
      var Desktops = desktops();
        for ( i = 0; i < Desktops.length; i++ ) {
          d = Desktops[i];
          d.wallpaperPlugin = \"org.kde.image\";
          d.currentConfigGroup = Array(\"Wallpaper\", \"org.kde.image\", \"General\");
          d.writeConfig(\"Image\", \"file://$TMP_IMAGE\");}"

      dbus-send --session --dest=org.kde.plasmashell --type=method_call /PlasmaShell org.kde.PlasmaShell.evaluateScript "string:
      var Desktops = desktops();
        for ( i = 0; i < Desktops.length; i++ ) {
          d = Desktops[i];
          d.wallpaperPlugin = \"org.kde.image\";
          d.currentConfigGroup = Array(\"Wallpaper\", \"org.kde.image\", \"General\");
          d.writeConfig(\"Image\", \"file://$WALLPAPER\");}"
  fi
fi

#----------------------------------------------------------

# MATE setup wallpapers
if [[ "$XDG_SESSION_DESKTOP" == "mate" ]]; then
  update_wallpaper
  gsettings set org.mate.background picture-filename "$WALLPAPER"
fi

#----------------------------------------------------------

# FLY setup wallpapers
if [[ "$XDG_SESSION_DESKTOP" == "fly" ]]; then
  update_wallpaper
  fly-wmfunc FLYWM_UPDATE_VAL WallPaper "$WALLPAPER"
  #Save setting in file
  sed -i "s|WallPaper=.*|WallPaper=$HOME/$HOMEIMAGES/Custom.png|" $HOME/.fly/theme/current.themerc
fi

#----------------------------------------------------------

# Clear TEMPDIR
echo -e "$C_YELLOW Clearing temprorary directory$C_RES"
if [[ ! -d "$TEMPDIR" ]]; then
  exit
else
  rm -Rf "$TEMPDIR"
fi

# Finish
echo -e "$C_CYAN Finish$C_RES"

