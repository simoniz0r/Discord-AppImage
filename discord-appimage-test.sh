#!/bin/bash -x
# Author: Syretia
# Name: discord-appimage
# License: MIT
# Description: Builds an AppImage of Discord and keeps it up to date
# Dependencies (only required for building from scratch): ar (binutils), curl

# function to display messages
discord_msg() {
    msg_type="$2"
    if command -v fltk-dialog > /dev/null; then
        fltk-dialog --title="Discord AppImage" --close-label="OK" --center --"$msg_type" --text="$1" --width=500
    elif command -v xmessage > /dev/null; then
        case "$msg_type" in
            error|message) xmessage -buttons OK:0 -center -geometry 500x150 "$1";;
            question) xmessage -buttons Yes:0,No:1 -center -geometry 500x150 "$1";;
        esac
    else
        echo "$1"
    fi
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
    # find latest deb url using grep and head -n 1
    latest_deb_url="$(curl -skL "https://packages.ubuntu.com/focal/amd64/$deb_name/download" | \
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
    ar x "$HOME"/.cache/"$version_lower"-appimage/debs/temp/"$1" || \
    discord_error "Error using 'ar' to extract '$1'" "1"
    # extract files from the data tar to AppDir
    tar -xf "$HOME"/.cache/"$version_lower"-appimage/debs/temp/data.tar.* -C "$HOME"/.cache/"$version_lower"-appimage/AppDir/ || \
    discord_error "Error using 'tar' to extract data tarball from '$1'" "1"
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
    # curl -skL "file:///home/syretia/git/Discord-AppImage/discord-appimage-test.sh" \
    curl -skL "https://github.com/simoniz0r/Discord-AppImage/raw/master/discord-appimage-test.sh" \
    -o "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/bin/discord-runner || \
    discord_error "Error downloading discord-appimage.sh" "1"
    chmod +x "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/bin/discord-runner
    # download fltk-dialog (used for displaying messages)
    curl -skL "https://github.com/simoniz0r/Discord-AppImage/raw/master/fltk-dialog" \
    -o "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/bin/fltk-dialog || \
    discord_error "Error downloading fltk-dialog" "1"
    # make executable
    chmod +x "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/bin/fltk-dialog
    # if $discord_build_full set to true, download and extract Discord deb
    if [[ "$discord_build_full" == "true" ]]; then
        # download Discord deb
        curl -skL "$version_url" -o "$HOME"/.cache/"$version_lower"-appimage/debs/discord.deb || \
        discord_error "Error downloading $version_upper deb file" "1"
        # extract discord deb
        discord_extractdebs "discord.deb"
        # copy discord.desktop and discord.png to AppDir
        cp "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/share/"$version_lower"/"$version_lower".desktop \
        "$HOME"/.cache/"$version_lower"-appimage/AppDir/"$version_lower".desktop
        cp "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/share/"$version_lower"/discord.png \
        "$HOME"/.cache/"$version_lower"-appimage/AppDir/"$version_lower".png
    else
        # else setup dummy .desktop file and icon because appimagetool needs them
        echo "[Desktop Entry]" > "$HOME"/.cache/"$version_lower"-appimage/AppDir/discord.desktop
        echo 'Name=Discord AppImage Builder' >> "$HOME"/.cache/"$version_lower"-appimage/AppDir/discord.desktop
        echo 'Comment=Builds Discord AppImages.' >> "$HOME"/.cache/"$version_lower"-appimage/AppDir/discord.desktop
        echo 'GenericName=Internet Messenger' >> "$HOME"/.cache/"$version_lower"-appimage/AppDir/discord.desktop
        echo 'Exec=./usr/bin/discord-runner' >> "$HOME"/.cache/"$version_lower"-appimage/AppDir/discord.desktop
        echo 'Icon=discord' >> "$HOME"/.cache/"$version_lower"-appimage/AppDir/discord.desktop
        echo 'Type=Application' >> "$HOME"/.cache/"$version_lower"-appimage/AppDir/discord.desktop
        echo 'StartupNotify=false' >> "$HOME"/.cache/"$version_lower"-appimage/AppDir/discord.desktop
        echo 'Categories=Network;' >> "$HOME"/.cache/"$version_lower"-appimage/AppDir/discord.desktop
        echo 'Keywords=discord;' >> "$HOME"/.cache/"$version_lower"-appimage/AppDir/discord.desktop
        curl -sKL "https://sy.imgix.net/Lq4hPU_command-window.png" \
        -o "$HOME"/.cache/"$version_lower"-appimage/AppDir/discord.png
    fi
    # download curl binary
    curl -skL "https://github.com/moparisthebest/static-curl/releases/latest/download/curl-amd64" \
    -o "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/bin/curl || \
    discord_error "Error downloading curl" "1"
    # make executable
    chmod +x "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/bin/curl
    # download and extract Discord's deps
    if [[ "$discord_build_full" == "true" ]]; then
        deps=(binutils libnotify4 libxss1 libxtst6 libappindicator1 libnspr4 libnss3 libgconf-2-4 libatomic1)
    else
        deps=(binutils)
    fi
    for dep in "${deps[@]}"; do
        discord_dldeps "$dep"
        discord_extractdebs "$dep.deb"
    done
}

# function to build AppImage
discord_buildappimage() {
    if [[ -z "$save_dir" ]]; then
        # pick dir to save AppImage to
        discord_msg "Please choose the directory to save the $version_upper AppImage to..." "message"
        cd "$HOME"
        export save_dir="$(fltk-dialog --title="Discord AppImage" --center --directory)"
    fi
    # exit if no dir or dir not writable
    if [[ -z "$save_dir" ]]; then
        discord_error "No directory chosen" "1"
    fi
    if [[ "$discord_build_full" == "true" ]]; then
        # show progress bar while building AppImage
        fltk-dialog --title="Discord AppImage" \
        --center \
        --width=400 \
        --progress \
        --pulsate \
        --no-cancel \
        --no-escape \
        --undecorated \
        --skip-taskbar \
        --text="Building $version_upper AppImage.  Please wait..." &
        export progress_pid="$!"
        sleep 0.5
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
    # write version_lower to .build_version file
    echo "$version_lower" > "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/bin/.build_version
    if [[ "$discord_build_full" == "true" ]]; then
        # run Discord's postinst script before creating AppImage
        chmod +x "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/share/"$version_lower"/postinst.sh
        "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/share/"$version_lower"/postinst.sh || \
        discord_error "Error running 'postinst.sh' script from $version_upper" "1"
    fi
    # download appimagetool
    curl -skL "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" \
    -o "$HOME"/.cache/"$version_lower"-appimage/appimagetool || \
    discord_error "Error downloading 'appimagetool'" "1"
    # make executable
    chmod +x "$HOME"/.cache/"$version_lower"-appimage/appimagetool
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
        sudo_pass="$(fltk-dialog --title="Discord AppImage" \
        --close-label="OK" \
        --center \
        --password \
        --text="Authentication is needed to move the $version_upper AppImage to '$save_dir'")"
        echo "$sudo_pass" | sudo -S mkdir -p "$save_dir" || discord_error "Error creating directory '$save_dir'" "1"
        echo "$sudo_pass" | sudo -S mv "$HOME"/.cache/"$version_lower"-appimage/"$version_lower".AppImage "$save_dir"/"$version_lower" || \
        discord_error "Error moving $version_upper AppImage to '$save_dir'" "1"
    fi
    # kill progress bar
    if [[ -n "$progress_pid" ]]; then
        kill -SIGTERM "$progress_pid"
    fi
    # if being ran from distributable AppImage, ask to create menu entry
    if [[ "$discord_build_full" == "true" && ! -d "$running_dir/../share/$version_lower" ]]; then
        discord_msg "Finished building AppImage for $version_upper version '$latest_ver' to '$save_dir/$version_lower'.\n\nWould you like to create a menu entry for $version_upper?\n\n" "question"
        if [[ "$?" == "0" ]]; then
            # copy desktop file and icon to ~/.local
            mkdir -p "$HOME"/.local/share/applications
            mkdir -p "$HOME"/.local/share/icons/hicolor/256x256/apps
            rm -rf "$HOME"/.local/share/applications/"$version_lower".desktop
            rm -rf "$HOME"/.local/share/icons/hicolor/256x256/apps/"$version_lower".png
            cp "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/share/"$version_lower"/"$version_lower".desktop \
            "$HOME"/.local/share/applications/"$version_lower".desktop || \
            discord_error "Error copying '$version_lower.desktop' to '$HOME/.local/share/applications/$version_lower.desktop'" "1"
            cp "$HOME"/.cache/"$version_lower"-appimage/AppDir/usr/share/"$version_lower"/discord.png \
            "$HOME"/.local/share/icons/hicolor/256x256/apps/"$version_lower".png || \
            discord_error "Error copying 'discord.png' to '$HOME/.local/share/icons/hicolor/256x256/apps/$version_lower.png'" "1"
            # fix Exec and Icon lines in .desktop file
            sed -i "s%^Exec=.*%Exec=$save_dir/$version_lower%g" \
            "$HOME"/.local/share/applications/"$version_lower".desktop
            sed -i "s%^Icon=.*%Icon=$HOME/.local/share/icons/hicolor/256x256/apps/$version_lower.png%g" \
            "$HOME"/.local/share/applications/"$version_lower".desktop
            discord_msg "$version_upper desktop file and icon have been copied to '"$HOME"/.local/share'.\nYou can run '$save_dir/$version_lower uninstall' if you would like to remove them later.\n$version_upper will now start. This AppImage is no longer required and can be removed." "message"
        else
            discord_msg "$version_upper will now start. This AppImage is no longer required and can be removed." "message"
        fi
    else
        discord_msg "Finished building AppImage for $version_upper version '$latest_ver'." "message"
    fi
    rm -rf "$HOME"/.cache/"$version_lower"-appimage
}

# function to check for update and apply update if available
discord_update() {
    # get latest version by checking header on download url
    latest_headers="$(curl -skIX HEAD "$version_url")"
    latest_ver="$(echo "$latest_headers" | grep -im1 '^location:' | cut -f6 -d'/')"
    if [[ -z "$latest_ver" ]]; then
        discord_error "Error getting latest $version_upper version information" "1"
    fi
    # skip version check if $discord_build_full set to true and just build AppImage
    if [[ "$discord_build_full" != "true" ]]; then
        # get current version from ../share/"$version_lower"/resources/build_info.json
        current_ver="$(grep '"version":' "$running_dir"/../share/"$version_lower"/resources/build_info.json | cut -f4 -d'"')"
        if [[ -z "$current_ver" ]]; then
            discord_error "Error getting current $version_upper version" "1"
        fi
        echo "Current version: $current_ver"
        echo "Latest version: $latest_ver"
        # check if versions match and return if they do
        if [[ "$current_ver" == "$latest_ver" ]]; then
            # up to date, run Discord
            echo "$version_upper is up to date."
            # run with --disable-gpu-sandbox to work around bug with Electron and glibc 2.34
            "$running_dir"/"$version_lower" --disable-gpu-sandbox "$@"
            # while loop that sleeps so that internal update process works
            while true; do
                sleep 30
                # break if Discord is not running
                if ! ps -x | grep -q "[/]$version_lower/Discord"; then
                    break
                fi
            done
            exit 0
        fi
        # versions did not match, so build new AppImage
        discord_msg "New $version_upper version '$latest_ver' is available.\nUpdate now?" "question"
        if [[ "$?" != "0" ]]; then
            discord_error "$version_upper was not updated" "0"
        fi
        # set $discord_build_full to true so Discord deb will be downloaded
        export discord_build_full="true"
    else
        discord_msg "Would you like to build $version_upper AppImage for version '$latest_ver'?" "question"
        if [[ "$?" != "0" ]]; then
            discord_error "$version_upper AppImage was not built." "0"
        fi
    fi
    # detect previous save_dir from .desktop file
    if [[ -f "$HOME/.local/share/applications/$version_lower.desktop" ]]; then
        desktop_exec="$(grep -m1 '^Exec=' "$HOME"/.local/share/applications/"$version_lower".desktop | cut -f2 -d'=')"
        # if Exec value starts with '/' and basename is version_lower, use readelf to check if is AppImage
        if [[ "$(echo "$desktop_exec" | cut -c1)" == "/" && "$(basename "$desktop_exec")" == "$version_lower" ]]; then
            # use readelf to check comment for AppImage and ask to use that path as save_dir
            if readelf -Wp .comment "$desktop_exec" | grep -q 'AppImage'; then
                discord_msg "Existing $version_upper AppImage detected.\nWould you like to save $version_upper AppImage version $latest_ver to '$desktop_exec'?\nThis will overwrite the existing $version_upper AppImage." "question"
                if [[ "$?" == "0" ]]; then
                    export save_dir="$(dirname "$desktop_exec")"
                fi
            fi
        fi
    fi
    # build AppImage
    discord_buildappimage
    # run new AppImage, fork it to background, and exit
    cd "$HOME"
    "$save_dir"/"$version_lower" "$@" & disown
    exit 0
}

# get dir script is running from
export running_dir="$(dirname "$(readlink -f "$0")")"
export discord_build_full="false"

# get Discord version by checking for directories or input when building from distributable AppImage
# Discord Stable
if [[ -d "$running_dir/../share/discord" ]]; then
    export version_lower="discord"
    export version_upper="Discord"
    export version_url="https://discord.com/api/download?format=deb&platform=linux"
# Discord Insiders
elif [[ -d "$running_dir/../share/discord-ptb" ]]; then
    export version_lower="discord-ptb"
    export version_upper="Discord PTB"
    export version_url="https://discord.com/api/download/ptb?format=deb&platform=linux"
elif [[ -d "$running_dir/../share/discord-canary" ]]; then
    export version_lower="discord-canary"
    export version_upper="Discord Canary"
    export version_url="https://discord.com/api/download/canary?format=deb&platform=linux"
else
    if [[ "$1" != "build-distrib" ]]; then
        export discord_build_full="true"
        # full AppImage has not been built, detect which version to build
        build_version="$(cat "$running_dir"/.build_version)"
        case "$build_version" in
            discord) # Discord Stable
                export version_lower="discord"
                export version_upper="Discord"
                export version_url="https://discord.com/api/download?format=deb&platform=linux"
                ;;
            discord-ptb) # Discord PTB
                export version_lower="discord-ptb"
                export version_upper="Discord PTB"
                export version_url="https://discord.com/api/download/ptb?format=deb&platform=linux"
                ;;
            discord-canary) # Discord Insiders
                export version_lower="discord-canary"
                export version_upper="Discord Canary"
                export version_url="https://discord.com/api/download/canary?format=deb&platform=linux"
                ;;
            *) exit 0;;
        esac
    fi
fi

# check arguments
case "$1" in
    build-distrib) # build AppImage for distribution that doesn't actually contain Discord
        export latest_ver="Distributable AppImage"
        case "$2" in
            *ptb) # Discord PTB
                export version_lower="discord-ptb"
                export version_upper="Discord PTB"
                export version_url="https://discord.com/api/download/ptb?format=deb&platform=linux"
                ;;
            *canary) # Discord Canary
                export version_lower="discord-canary"
                export version_upper="Discord Canary"
                export version_url="https://discord.com/api/download/canary?format=deb&platform=linux"
                ;;
            *) # Discord Stable
                export version_lower="discord"
                export version_upper="Discord"
                export version_url="https://discord.com/api/download?format=deb&platform=linux"
                ;;
        esac
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
    uninstall) # remove desktop file and icon from ~/.local
        rm -rf "$HOME"/.local/share/applications/"$version_lower".desktop
        rm -rf "$HOME"/.local/share/icons/hicolor/256x256/apps/"$version_lower".png
        discord_msg "$version_upper desktop file and icon have been removed from '"$HOME"/.local/share'" "message"
        ;;
    *) discord_update "$@";; # check for update and run Discord
esac
