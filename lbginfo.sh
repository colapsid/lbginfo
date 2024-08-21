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
    -p)
      echo "Pango option: On"
      PANGO="true"
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
      echo "  -p,    Use pango extension"
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
  echo -e "$C_RED""Error: Run $0 from not root! $C_RES"
  exit
fi

# ImageMagick path
MAGICK="/usr/bin/convert"
# Check if ImageMagick installed
if [[ ! -f "$MAGICK" ]]; then
  echo -e "$C_RED""Error: ImageMagick not installed! $C_RES"
  exit
fi

# If Pango support
if [[ "$PANGO" == "true" ]]; then
  IS_PANGO=$(convert -list format | grep -i Pango | awk '{print $3}')
  if [[ $IS_PANGO == "---" ]] || [[ -z $IS_PANGO ]]; then
    echo -e "$C_YELLOW""Warning: Pango may not supported $C_RES"
  else
    echo -e "$C_GREEN""Pango supported ! $C_RES"
    PANGO_OK='true'
  fi
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
TMP_IMAGE="$TEMPDIR/tmp_image.png"

#----------------------------------------------------------

# Default paths
WALLFILE="Default.jpg"
ORIGWALL="/usr/share/kf5/wallpapers/Next/contents/images_dark/$WALLFILE"
HOMEIMAGES="WallPapers"
DEFAULTWALLPAPER="$HOME/$HOMEIMAGES/default.jpg"
WALLPAPER="$HOME/$HOMEIMAGES/Custom.png"
NEWWALL="$HOME/$HOMEIMAGES/Custom_temp.png"

if [[ ! -d "$HOME/$HOMEIMAGES" ]]; then
  echo "Create $HOME/$HOMEIMAGES"
  mkdir "$HOME/$HOMEIMAGES"
fi

#----------------------------------------------------------

# Language: RU, EN
BGLANG="EN"
# Position SystemInfo: Center, East, North, NorthEast, Northwest, South, SouthEast, SouthWest, West
POSITION="SouthEast"
# Some Monospace fonts: DejaVu-Sans-Mono-Bold, Courier-Bold, CourierNew, Ubuntu Mono Bold, DejaVu Sans Mono, FreeMono Bold
FONT="DejaVu-Sans-Mono-Bold"
FONT_P="DejaVu Sans Mono"  # For Pango
# Text/font size
FONTSIZE="16"
FONTSIZE_P="14" # For Pango
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
R_IPADRS=$(ip -o addr | grep -v "fe80" | awk '!/^[0-9]*: ?lo|link\/ether/ {print $2": "$4}')
R_MACADRS=$(ip -o link show | grep -v "lo" | cut -d ' ' -f 2,20)
R_DNSSERVER=$(grep ^nameserver /etc/resolv.conf | awk '{print $2}')
if [[ "$R_DNSSERVER" == "127.0.0.53" ]]; then
  if [[ -f /usr/bin/nmcli ]]; then
    R_DNSSERVER=(`nmcli dev show | grep DNS | awk '{print $2}'`)
  fi
elif [[ "$R_DNSSERVER" == "127.0.0.1" ]]; then
  if [[ -f /etc/resolv.conf.dnsmasq ]]; then
    R_DNSSERVER=$(grep ^nameserver /etc/resolv.conf.dnsmasq | awk '{print $2}')
  fi
fi
R_GATEWAY=$(ip route | grep default | cut -d' ' -f 3 | head -n1)
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
if [[ $XDG_SESSION_DESKTOP == "KDE" ]] || [[ $XDG_SESSION_DESKTOP == "plasma" ]]; then
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
      KDE_IMG_INDEX_DIR="${KDE_IMG_INDEX_FILE}contents/images/"
      KDE_IMG_INDEX_FILE="${KDE_IMG_INDEX_FILE}contents/images/$DISPSIZE.jpg"
      if [[ -f "$KDE_IMG_INDEX_FILE" ]]; then
        echo -e "Current KDE wallpaper $ki: $KDE_IMG_INDEX_FILE"
        echo -e "Image size            $ki:" $(identify -ping -format '%wx%h' $KDE_IMG_INDEX_FILE)
        KDE_CURR_WALLPAPERS+=("$KDE_IMG_INDEX_FILE")
      else
        echo -e "$C_RED
Error: $KDE_IMG_INDEX_FILE File not found!$C_YELLOW
Try to set and resize from dir:$KDE_IMG_INDEX_DIR $C_RES"
        #Set Default wallpaper:$DEFAULT_IMG_PATH/$DISPSIZE.jpg $C_RES"
        #KDE_CURR_WALLPAPERS+=("$DEFAULT_IMG_PATH/$DISPSIZE.jpg")

        RESIZE="true"
        WPLS=($(ls -1 $KDE_IMG_INDEX_DIR))
        WPLS+=("$DISPSIZE.jpg")

        IFS=$'\n' WPSorted=($(sort <<<"${WPLS[*]}"))
        unset IFS

        n=0
        for img in ${WPSorted[@]}; do
          if [[ $img == "$DISPSIZE.jpg" ]]; then

            if [[ -n ${WPSorted[$n+1]} ]]; then
              echo "Current: $img" "Next: ${WPSorted[$n+1]}"
              KDE_CURR_WALLPAPERS+=(${KDE_IMG_INDEX_DIR}${WPSorted[$n+1]})
            else
              echo "Current: $img" "Prev: ${WPSorted[$n-1]}"
              KDE_CURR_WALLPAPERS+=(${KDE_IMG_INDEX_DIR}${WPSorted[$n-1]})
            fi

          fi
          n+=1
        done
      fi
    fi

    done

  if [[ -z "$KDE_CURR_WALLPAPERS" ]]; then
    echo -e "Current KDE wallpaper:$C_PURPLE $ORIGWALL $C_RES"
    echo -e "Image size           :" $(identify -ping -format '%wx%h' $ORIGWALL)

    if [[ -z "$ORIGWALL"  ]]; then
      ORIGWALL="$DEFAULT_IMG_PATH/$DISPSIZE.jpg"
      if [[ ! -f "$ORIGWALL" ]]; then
        echo -e "$C_RED""Error: File $ORIGWALL not found! $C_RES"
        exit
      fi
    fi

  fi
fi

#----------------------------------------------------------

# Function check path $ORIGWALL
function check_wallpaper () {
  if [[ ! -f "$ORIGWALL" ]]; then
    echo -e "$C_RED""Error: File $ORIGWALL not found! $C_RES"

    if [[ -f "$DEFAULTWALLPAPER" ]]; then
      echo -e "Set file:$C_YELLOW $DEFAULTWALLPAPER $C_RES"
      ORIGWALL="$DEFAULTWALLPAPER"
    else
      echo -e "$C_RED""Error: File $DEFAULTWALLPAPER not found! $C_RES"
      exit
    fi

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
  echo -e "$C_RED""Error: Do not mix [-f] and [-d] options $C_RES"
  exit
fi

# Check if wallpaper already created
if [[ -z "$FILE" && -z "$DIR" ]]; then
  if [[ "$ORIGWALL" =~ "$HOME/$HOMEIMAGES/Custom" ]]; then
    echo -e "$C_RED""Error: Wallpaper $ORIGWALL already created. Skipping. $C_RES"
    echo "Exit"
    exit
  fi
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

# Generate System info image
if [[ "$PANGO" != "true" ]] && [[ "$PANGO_OK" != "true"  ]]; then
  echo -e "$C_GREEN Generate System info image $C_RES"
  # Export to BGFILE
  echo "$L_HOSTNAME" "$R_HOSTNAME"             >> "$BGFILE"
  echo "$L_USERNAME" "$R_USERNAME"             >> "$BGFILE"
  IFS=$'\n'
  for i in ${R_IPADRS[@]}; do
    echo "$L_IPADDRESS" "$i"                   >> "$BGFILE"
  done
  for m in ${R_MACADRS[@]}; do
    echo "$L_MACADRS" "$m"                     >> "$BGFILE"
  done
  unset IFS
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

  cat "$BGFILE" | convert \
    -font "$FONT" -pointsize "$FONTSIZE" \
    -strokewidth "$STROKEWIDTH" -stroke "$STROKECOLOR" \
    -background "$BFILL" \
    -fill "$FILL" \
    label:@- "$BG" 

else
  # Generate System info image (PANGO)
  echo -e "$C_GREEN Generate System info image (PANGO) $C_RES"

  echo "<span foreground='White'>$L_HOSTNAME </span><span foreground='Green' ><b>$R_HOSTNAME</b></span>"      >> "$BGFILE"
  echo "<span foreground='White'>$L_USERNAME </span><span foreground='Red'   ><b>$R_USERNAME</b></span>"      >> "$BGFILE"

  IFS=$'\n'
  for i in ${R_IPADRS[@]}; do
    echo "<span foreground='White'>$L_IPADDRESS </span><span foreground='Yellow'>$i</span>"                   >> "$BGFILE"
  done

  for m in ${R_MACADRS[@]}; do
    echo "<span foreground='White'>$L_MACADRS </span><span foreground='Yellow'>$m</span>"                     >> "$BGFILE"
  done
  unset IFS

  echo "<span foreground='White'>$L_GATEWAY </span><span foreground='Lime'>$R_GATEWAY</span>"                 >> "$BGFILE"

  for d in ${R_DNSSERVER[@]}; do
    echo "<span foreground='White'>$L_DNSSERVER </span><span foreground='Aqua'>$d</span>"                     >> "$BGFILE"
  done

  echo "<span foreground='White'>$L_CPUMODEL </span><span foreground='Orange'>$R_CPUMODEL x $R_NUMCPU</span>" >> "$BGFILE"
  echo "<span foreground='White'>$L_MEMTOTAL </span><span foreground='Orange'>$R_MEMGB Gb $R_SWAPGB</span>"   >> "$BGFILE"
  echo "<span foreground='White'>$L_OSVERSION </span><span foreground='Purple'>$R_OS $R_VERSION</span>"       >> "$BGFILE"
  echo "<span foreground='White'>$L_KERNEL </span><span foreground='Purple'>$R_KERNEL</span>"                 >> "$BGFILE"
  echo "" >> "$BGFILE"
  echo "" >> "$BGFILE"
  echo "" >> "$BGFILE"

  cat "$BGFILE" | convert \
    -font "$FONT_P" -pointsize "$FONTSIZE_P" \
    -background "$BFILL" \
    pango:@- "$BG"

fi

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
    echo -e "$C_GREEN Resize original image to display resolution $C_RES"
    convert -resize "$GEOMERTY" -quality 100 "$ORIGWALL" "$TMP_IMAGE"
  else
    TMP_IMAGE="$ORIGWALL"
  fi

  # Composite images
  echo -e "$C_GREEN Composite images $C_RES"
  composite -gravity "$POSITION" "$BG" "$TMP_IMAGE" "$NEWWALL"

  # Copy new image
  echo -e "$C_GREEN Copy new image $C_RES"
  cp "$NEWWALL" "$WALLPAPER"

  echo -e "$C_GREEN Update wallpaper $C_RES"
  # Update wallpaper
}

#----------------------------------------------------------

# KDE setup wallpapers
if [[ "$XDG_SESSION_DESKTOP" == "KDE" ]] || [[ $XDG_SESSION_DESKTOP == "plasma" ]]; then

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
          d.writeConfig(\"Image\", \"file://$NEWWALL\");"

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
          d.writeConfig(\"Image\", \"file://$NEWWALL\");}"

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
echo -e "$C_YELLOW Clearing temprorary directory $C_RES"
if [[ ! -d "$TEMPDIR" ]]; then
  exit
else
  rm -Rf "$TEMPDIR"
fi

# Finish
echo -e "$C_CYAN Finish $C_RES"
