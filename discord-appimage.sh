#!/bin/bash -x
# Author: Syretia
# Name: discord-appimage
# License: MIT
# Description: Builds an AppImage of Discord and keeps it up to date
# Dependencies (only required for building from scratch): ar (binutils), curl

# function to display messages
discord_msg() {
    case "$2" in
        error) msg_type="error";;
        msg) msg_type="message";;
        question) msg_type="question";;
    esac
    fltk-dialog --title="$version_upper AppImage" --close-label="OK" --center --system-colors --"$msg_type" --text="$1"
}

# function to handle exits
discord_error() {
    # cleanup leftover files
    rm -rf "$HOME"/.cache/"$version_lower"-appimage
    # kill progress bar if running
    if [[ -n "$progress_pid" ]]; then
        kill -SIGTERM "$progress_pid"
    fi
    # show error
    discord_msg "$1" "error"
    # exit
    exit "$2"
}

# function to find latest debs from Ubuntu's site for building AppImage
discord_dldeps() {
    deb_name="$1"
    # set deb_release to bionic-updates for libappindicator1 and bionic for everything else
    # bionic-updates contains fix for crashing during voice calls
    case "$deb_name" in
        libappindicator1) deb_release="bionic-updates";;
        *) deb_release="bionic";;
    esac
    # find latest deb url using grep and head -n 1
    latest_deb_url="$(curl -skL "https://packages.ubuntu.com/$deb_release/amd64/$deb_name/download" | \
    grep '<li>*..*amd64\.deb' | \
    cut -f2 -d'"' | \
    head -n 1)"
    # exit if not found
    if [[ -z "$latest_deb_url" ]]; then
        discord_error "Error getting download URL for '$deb_name'" "1"
        return
    fi
    # download latest deb
    curl -skL "$latest_deb_url" -o "$HOME"/.cache/"$version_lower"-appimage/debs/"$deb_name".deb || \
    discord_error "Error downloading '$deb_name' from '$latest_deb_url'" "1"
}

# function to extract debs and move them to AppDir folder
discord_extractdebs() {
    # mv deb to temp dir so contents can be extracted there
    mv "$HOME"/.cache/"$version_lower"-appimage/debs/"$1" "$HOME"/.cache/"$version_lower"-appimage/debs/temp/"$1"
    # cd to temp so 'ar' will extract files there
    cd "$HOME"/.cache/"$version_lower"-appimage/debs/temp
    # extract files from deb
    ar x "$HOME"/.cache/"$version_lower"-appimage/debs/temp/"$1"
    # extract files from the data tar to AppDir
    tar -xf "$HOME"/.cache/"$version_lower"-appimage/debs/temp/data.tar.* -C "$HOME"/.cache/"$version_lower"-appimage/AppDir/
    # remove leftovers
    rm -rf "$HOME"/.cache/"$version_lower"-appimage/debs/temp/*
    # make sure permissions are correct on all extracted files
    chmod -R 755 ~/.cache/"$version_lower"-appimage
}

# function to download and extract dependencies to AppRun dir for building AppImage
discord_setup() {
    # create necessary directories
    mkdir -p "$HOME"/.cache/"$version_lower"-appimage/debs/temp
    mkdir -p "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/bin
    # download discord-appimage.sh script to AppDir bin
    curl -skL "https://github.com/simoniz0r/Discord-AppImage/raw/master/discord-appimage.sh" \
    -o "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/bin/discord-runner || \
    discord_error "Error downloading discord-appimage.sh" "1"
    chmod +x "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/bin/discord-runner
    # download fltk-dialog (used for displaying messages)
    curl -skL "https://github.com/darealshinji/fltk-dialog/releases/download/continuous/fltk-dialog" \
    -o "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/bin/fltk-dialog || \
    discord_error "Error downloading fltk-dialog" "1"
    # make executable
    chmod +x "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/bin/fltk-dialog
    # download Discord deb
    curl -skL "https://discord.com/api/download$version_url?format=deb&platform=linux" \
    -o "$HOME"/.cache/"$version_lower"-appimage/debs/discord.deb || \
    discord_error "Error downloading $version_upper deb file" "1"
    # extract discord deb
    discord_extractdebs "discord.deb"
    # download curl binary
    curl -skL "https://github.com/moparisthebest/static-curl/releases/latest/download/curl-amd64" \
    -o "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/bin/curl || \
    discord_error "Error downloading curl" "1"
    # make executable
    chmod +x "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/bin/curl
    # copy discord.desktop and discord.png to AppDir
    cp "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/share/"$version_lower"/"$version_lower".desktop \
    "$HOME"/.cache/"$version_lower"-appimage/AppDir/"$version_lower".desktop
    cp "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/share/"$version_lower"/discord.png \
    "$HOME"/.cache/"$version_lower"-appimage/AppDir/"$version_lower".png
    # download and extract Discord's deps
    deps=(libnotify4 libxss1 libxtst6 libappindicator1 libnspr4 libnss3 libgconf-2-4)
    for dep in "${deps[@]}"; do
        discord_dldeps "$dep"
        discord_extractdebs "$dep.deb"
    done
}

# function to build AppImage
discord_buildappimage() {
    if [[ -z "$save_dir" ]]; then
        # pick dir to save AppImage to
        discord_msg "Please choose the directory to save the $version_upper AppImage to..." "msg"
        cd "$HOME"
        export save_dir="$(fltk-dialog --title="$version_upper AppImage" --center --directory)"
    fi
    # exit if no dir or dir not writable
    if [[ -z "$save_dir" ]]; then
        discord_error "No directory chosen" "1"
    fi
    # create AppDir
    mkdir -p "$HOME"/.cache/"$version_lower"-appimage/AppDir
    # setup AppRun
    echo '#!/bin/bash' > "$HOME"/.cache/"$version_lower"-appimage/AppDir/AppRun
    echo 'export RUNNING_DIR="$(dirname "$(readlink -f "$0")")"' >> "$HOME"/.cache/"$version_lower"-appimage/AppDir/AppRun
    echo 'export PATH="$RUNNING_DIR"/usr/bin/:"$PATH"' >> "$HOME"/.cache/"$version_lower"-appimage/AppDir/AppRun
    echo 'export LD_LIBRARY_PATH="$RUNNING_DIR"/usr/lib/:"${LD_LIBRARY_PATH}"' >> "$HOME"/.cache/"$version_lower"-appimage/AppDir/AppRun
    echo 'discord-runner "$@"' >> "$HOME"/.cache/"$version_lower"-appimage/AppDir/AppRun
    # make executable
    chmod +x "$HOME"/.cache/"$version_lower"-appimage/AppDir/AppRun
    # download and extract discord and dependencies to AppDir
    discord_setup
    # download appimagetool
    curl -skL "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" \
    -o "$HOME"/.cache/"$version_lower"-appimage/appimagetool || \
    discord_error "Error downloading 'appimagetool'" "1"
    # make executable
    chmod +x "$HOME"/.cache/"$version_lower"-appimage/appimagetool
    # run Discord's postinst script before creating AppImage
    chmod +x "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/share/"$version_lower"/postinst.sh
    "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/share/"$version_lower"/postinst.sh || \
    discord_error "Error running 'postinst.sh' script from $version_upper" "1"
    # build AppImage using appimagetool
    ARCH="x86_64" "$HOME"/.cache/"$version_lower"-appimage/appimagetool \
    "$HOME"/.cache/"$version_lower"-appimage/AppDir \
    "$HOME"/.cache/"$version_lower"-appimage/"$version_lower".AppImage || \
    discord_error "Error using 'appimagetool' to build AppImage for $version_upper" "1"
    # check if save dir is writeable
    if [[ -w "$save_dir" ]]; then
        # create save_dir
        mkdir -p "$save_dir" || discord_error "Error creating directory '$save_dir'" "1"
        # mv to save_dir
        mv "$HOME"/.cache/"$version_lower"-appimage/"$version_lower".AppImage "$save_dir"/"$version_lower" || \
        discord_error "Error moving $version_upper AppImage to '$save_dir'" "1"
    # try to use pkexec if not writable
    elif command -v pkexec &> /dev/null; then
        # create save_dir and move AppImage to save_dir
        pkexec bash -c "mkdir -p "$save_dir" && \
        mv "$HOME"/.cache/"$version_lower"-appimage/"$version_lower".AppImage "$save_dir"/"$version_lower"" || \
        discord_error "Error moving $version_upper AppImage to '$save_dir'" "1"
    else
        sudo_pass="$(fltk-dialog --title="$version_upper AppImage" \
        --close-label="OK" \
        --center \
        --system-colors \
        --password \
        --text="Authentication is needed to move the $version_upper AppImage to '$save_dir'")"
        echo "$sudo_pass" | sudo -S mkdir -p "$save_dir" || discord_error "Error creating directory '$save_dir'" "1"
        echo "$sudo_pass" | sudo -S mv "$HOME"/.cache/"$version_lower"-appimage/"$version_lower".AppImage "$save_dir"/"$version_lower" || \
        discord_error "Error moving $version_upper AppImage to '$save_dir'" "1"
    fi
    rm -rf "$HOME"/.cache/"$version_lower"-appimage
}

# function to check for update and apply update if available
discord_update() {
    # get current version from ../share/"$version_lower"/resources/build_info.json
    current_ver="$(grep '"version":' "$running_dir"/../share/"$version_lower"/resources/build_info.json | cut -f4 -d'"')"
    if [[ -z "$current_ver" ]]; then
        discord_error "Error getting current $version_upper version" "1"
    fi
    # get latest version by checking header on download url
    latest_ver="$(curl -skIX HEAD "https://discord.com/api/download$version_url?format=deb&platform=linux" | \
    grep -im1 '^location:' | \
    cut -f6 -d'/')"
    if [[ -z "$latest_ver" ]]; then
        discord_error "Error getting latest $version_upper version" "1"
    fi
    echo "Current version: $current_ver"
    echo "Latest version: $latest_ver"
    # check if versions match and return if they do
    if [[ "$current_ver" == "$latest_ver" ]]; then
        # up to date, run Discord
        echo "$version_upper is up to date."
        # run with --disable-gpu-sandbox to work around bug with Electron and glibc 2.34
        "$running_dir"/"$version_lower" --disable-gpu-sandbox "$@"
        # sleep so that internal update process works
        sleep 30
        exit
    fi
    # versions did not match, so build new AppImage
    discord_msg "New $version_upper version '$latest_ver' is available.\nUpdate now?" "question" || \
    discord_error "$version_upper was not updated" "0"
    # show progress bar while building AppImage
    fltk-dialog --title="$version_upper AppImage" \
    --center \
    --system-colors \
    --progress \
    --pulsate \
    --no-cancel \
    --no-escape \
    --undecorated \
    --skip-taskbar \
    --text="Building $version_upper AppImage.  Please wait..." &
    progress_pid="$!"
    sleep 0.5
    # build AppImage
    discord_buildappimage
    # kill progress bar
    kill -SIGTERM "$progress_pid"
    discord_msg "Finished updating $version_upper to version '$latest_ver'." "msg"
    # run new AppImage, fork it to background, and exit
    cd "$HOME"
    "$save_dir"/"$version_lower" --disable-gpu-sandbox "$@" & disown
    exit
}

# get dir script is running from
export running_dir="$(dirname "$(readlink -f "$0")")"

# get Discord version by checking for directories or input when building from scratch
# Discord Stable
if [[ -d "$running_dir/../share/discord" ]]; then
    export version_lower="discord"
    export version_upper="Discord"
    export version_url=""
# Discord PTB
elif [[ -d "$running_dir/../share/discord-ptb" ]]; then
    export version_lower="discord-ptb"
    export version_upper="Discord PTB"
    export version_url="/ptb"
# Discord Canary
elif [[ -d "$running_dir/../share/discord-canary" ]]; then
    export version_lower="discord-canary"
    export version_upper="Discord Canary"
    export version_url="/canary"
else
    case "$2" in
        stable|Stable|"") # Discord Stable
            export version_lower="discord"
            export version_upper="Discord"
            export version_url=""
            ;;
        ptb|PTB) # Discord PTB
            export version_lower="discord-ptb"
            export version_upper="Discord PTB"
            export version_url="/ptb"
            ;;
        canary|Canary) # Discord Canary
            export version_lower="discord-canary"
            export version_upper="Discord Canary"
            export version_url="/canary"
            ;;
        *) discord_error "Invalid version input '$2'" "1";;
    esac
fi

# check arguments
case "$1" in
    build) # build AppImage from scratch
        if [[ -z "$3" ]]; then
            export save_dir="$PWD"
        else
            if [[ ! -d "$3" ]]; then
                discord_error "'$3' is not a directory" "1"
            fi
            export save_dir="$3"
        fi
        discord_buildappimage
        ;;
    install)
        # copy desktop file and icon to ~/.local
        mkdir -p "$HOME"/.local/share/applications
        mkdir -p "$HOME"/.local/share/icons/hicolor/256x256/apps
        rm -rf "$HOME"/.local/share/applications/"$version_lower".desktop
        rm -rf "$HOME"/.local/share/icons/hicolor/256x256/apps/"$version_lower".png
        cp "$running_dir"/../share/"$version_lower"/"$version_lower".desktop "$HOME"/.local/share/applications/"$version_lower".desktop || \
        discord_error "Error copying '$version_lower.desktop' to '"$HOME"/.local/share/applications/$version_lower.desktop'" "1"
        cp "$running_dir"/../share/"$version_lower"/discord.png "$HOME"/.local/share/icons/hicolor/256x256/apps/"$version_lower".png || \
        discord_error "Error copying 'discord.png' to '"$HOME"/.local/share/icons/hicolor/256x256/apps/$version_lower.png'" "1"
        # fix Exec and Icon lines in .desktop file
        sed -i "s%^Exec=.*%Exec=$version_lower%g" \
        "$HOME"/.local/share/applications/"$version_lower".desktop
        sed -i "s%^Icon=.*%Icon=$HOME/.local/share/icons/hicolor/256x256/apps/$version_lower.png%g" \
        "$HOME"/.local/share/applications/"$version_lower".desktop
        discord_msg "$version_upper desktop file and icon have been copied to '"$HOME"/.local/share'" "msg"
        ;;
    uninstall)
        # remove desktop file and icon from ~/.local
        rm -rf "$HOME"/.local/share/applications/"$version_lower".desktop
        rm -rf "$HOME"/.local/share/icons/hicolor/256x256/apps/"$version_lower".png
        discord_msg "$version_upper desktop "$@"file and icon have been removed from '"$HOME"/.local/share'" "msg"
        ;;
    *) discord_update "$@";; # check for update and run Discord
esac
