#!/usr/bin/env bash
coals_version="0.1.4" # this must be on line 2 or the version checker will break
# Launcher for coal-cli 2.9.2
# [mine|smelt|chop|reprocess|stake|claim|equip|unequip|inspect|balance|version|update|uninstall]
# [forever]
# All other args pass straight to 'coal'

coal_start() {
   [ "$1" == "update" ] && coals_update && exit 0
   [ "$1" == "uninstall" ] && [ "$0" == "$HOME/.local/bin/coals" ] && { 
      printf '\e[1;33m%s\e[m' "Uninstalling coals..."
      rm "$HOME/.local/bin/coals" &&
         { echo "done" && exit 0; } || 
         { echo "failed to uninstall :( whyyy" && exit 1; }
   }
   # Check if 'solana' and 'coal' are installed
   for i in solana coal; do
      [ ! "$(which $i)" ] && echo "Error: $i not installed wyd" && exit 1
   done
   # [ "$#" -gt 2 ] && echo "Error: too many args (argh!)" && exit 1
   # Switch to infinite loop mode if specified
   [ "$2" == "forever" ] && { 
      case "$1" in
         "mine") looptask="mine" && coals_loop && exit 0 ;;
         "smelt") looptask="smelt" && coals_loop && exit 0 ;;
         *) echo "'forever' is only for 'mine' or 'smelt'." && exit 1 ;;
      esac;
   }
   # Auto set a different 'solana' config for each username (or don't)
   case "$USER" in
      "asdf") _cfg="--config $HOME/.config/solana/dirtyore.yml" ;;    # [Y]
      "asdg") _cfg="--config $HOME/.config/solana/filthyore.yml" ;;   # [0]
      *) _cfg="" ;; # fallback to default
   esac
   # Set 'coal' parameters
   # - pay high fee to reprocess for $CHROMIUM and enhance tools because reward is timing dependent
   buffer_time=2
   prio_smol=1212
   prio_big=2112112

   case "$1" in
      "mine"|"chop"|"smelt") _params="$1 --cores $(nproc) --buffer-time $buffer_time --priority-fee $prio_smol" ;;
      "reprocess") _params="$* --priority-fee $prio_big" ;;
      "inspect"|"unequip"|"craft") _params="$1 --priority-fee $prio_smol" ;;
      "enhance"|"equip") [ "$2" != "" ] && [ "$2" == "$(echo $2 | grep -oP "[1-9A-HJ-NP-Za-km-z]{32,44}")" ] && 
         { _params="$1 --tool $2 --priority-fee $( [ "$1" == "equip" ] && echo "$prio_smol" || echo "$prio_big" )"; } ||
         { echo "Usage: 'coals $1 <tool_address>'" && exit 1; } ;;
      "stake"|"claim") 
         case "$2" in
            "") _params="$1 --priority-fee $prio_smol" ;;
            "coal"|"ingot"|"wood") _params="$1 --resource $2 --priority-fee $prio_smol" ;;
            "chromium"|"ore") echo "Nah: $2 can't be staked" && exit 1 ;;
            *) echo "Options: [coal], ingot, wood." && exit 1 ;;
         esac ;;
      "balance")
         case "$2" in
            "") _params="$1" ;;
            "coal"|"ingot"|"wood"|"chromium") _params="$1 --resource $2" ;;
            "ore") printf 'Balance: %s ORE\n' "$(spl-token balance oreoU2P8bN6jkk3jbaiVxYnG1dCXcYxwhwyK9jSybcp $_cfg)" && exit 0 ;;
            *) echo "Options: [coal], ingot, wood, chromium, ore." && exit 1 ;;
         esac ;;
      "version") coal -V; exit 0 ;;
      *) _params="$*" ;;
   esac

   # Print 'solana' config filename, wallet address, SOL balance, and 'coal' parameters
   printf '\e[1;30m'
   printf '%s\n' "$_cfg" | grep -oP "[^/]*$" # hmm
   printf '%s\n' "$(solana address $_cfg && solana balance $_cfg)"
   printf '%s\n' "$_params"
   printf '\e[m'
   # omg it's happening omg
   bash -c "coal $_cfg $_params"
}; export -f coal_start

# Error-catching infinite loop
coals_loop() {
   # Make ^C exit look a bit cleaner
   trap 'sleep 2; printf "\e[1A\n"; [ -f "$_log" ] && rm "$_log"' EXIT
   # Terminal command to monitor with 'script'
   _app="while :; do coal_start $looptask; echo \"ERROR: Tantrum >:(\"; done"
   _log=$(mktemp)
   printf "\n\n"
   while :; do
      # Print timestamp and say GMM
      printf "\e[2A\e[2K\e[1G\e[m%(%Y-%m-%d %H:%M:%S)T\n\n"
      printf "\e[1A\e[2K\e[1G\e[1;33mGMM\e[1;37m...\e[m\n\e[2K"
      # Get SOL balance (retry if not found (ie no internet) - ragequit if poor)
      sol_bal="$(solana balance --lamports 2>&1 | awk '{print $1}')"
      [[ "$sol_bal" == "Error"* ]] && printf '%s\n' "Balance not found, retrying..." && sleep 10 && continue
      [ "$sol_bal" -lt 10000000 ] && printf '\n%b\n\n' "\e[1;31mERROR:\e[m Not enough SOL :(" && break
      # Flush log
      : > "$_log"
      # Do mining until death
      script -qfc "$_app" "$_log" &
      _app_pid=$!
      # Watch for death and kill if death
      tail -F "$_log" | while read -r line; do
         if [[ "$line" == *"ERROR"* ]]; then
            for i in {1..5}; do printf '\U274c '; done ; echo
            kill "$_app_pid" 2>/dev/null
            break
         fi
      done
      # Hold horses
      sleep 3
      for (( D=12; D>0; D-- )); do
         printf '\e[m\e[1G%s\e[1;33m%2d' "Restarting in " "$D"
         sleep 1
      done
   done
}; export -f coals_loop

coals_install() {
   echo "Installing 'coals' v$coals_version ..."
   # Remove previous version if it exists
   [ -f "$HOME/.local/bin/coals" ] && coals_checkver && echo "Removing previous version" && rm "$HOME/.local/bin/coals"
   # Create ~/.local/bin if it doesn't exist
   [ ! -d "$HOME/.local/bin" ] && echo "Creating directory $HOME/.local/bin" && mkdir "$HOME/.local/bin"
   # Add to PATH if not already there (only for current session; bash should add it automatically on startup if it exists)
   [ "$(echo $PATH | tr ":" "\n" | grep "$HOME/\.local/bin$")" == "" ] && export PATH="$HOME/.local/bin:$PATH"
   # Move this script to ~/.local/bin and rename to 'coals'
   [ -d "$HOME/.local/bin" ] && mv "$0" "$HOME/.local/bin/coals"
   # Make 'coals' executable and verify installation (kinda)
   [ -f "$HOME/.local/bin/coals" ] && 
      { chmod +x "$HOME/.local/bin/coals" && echo Installed in "$HOME/.local/bin"; } || 
      { echo "Failed to install" && exit 1; }
}; export -f coals_install

coals_checkver() {
   # Set delimiter to '.'
   IFS_="$IFS" && IFS=.
   # Compare versions
   read -r -a cver_exist <<< "$(cat "./.local/bin/coals" | tail -n +2 | head -n 1 | grep -oP "\d\.\d\.\d")"
   read -r -a cver_this <<< "$(echo "$coals_version")"
   for i in ${!cver_exist[@]}; do
      [ ${cver_this[i]} -lt ${cver_exist[i]} ] && cver_this_isnewer=0 && break
      [ ${cver_this[i]} -gt ${cver_exist[i]} ] && cver_this_isnewer=1 && break
   done
   # Exit if same or older version than installed
   case "$cver_this_isnewer" in
      "") echo "Error: coals v$coals_version already installed (run 'coals uninstall' to remove)" && exit 1 ;;
      0) echo "Error: newer version (${cver_exist[*]}) already installed (run 'coals uninstall' to remove)" && exit 1 ;;
   esac
   IFS="$IFS_"
}; export -f coals_checkver

coals_update() {
fetch_temp=$(mktemp --suffix ".coals.sh")
echo "Downloading latest version..."
curl -sL "https://raw.githubusercontent.com/zoonose/coalness/main/coals.sh" -o "$fetch_temp" || { echo "Failed to download" && exit 1; }
bash "$fetch_temp" || echo "Failed to run installer"
[ -f "$fetch_temp" ] && rm "$fetch_temp"
}; export -f coals_update

# MAIN
# Run installer if script is called 'coals.sh', otherwise run 'coals'
[[ '$0' == *"coals.sh" ]] && { coals_install; } || { echo "coals v$coals_version"; coal_start "$@"; }