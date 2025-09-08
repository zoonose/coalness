#!/usr/bin/env bash
coals_version="0.1.2" # this must be on line 2 or the version checker will break
# Launcher for coal-cli 2.9.2
# [mine|chop|smelt|reprocess|forever|smelever|stake|claim|balance|version]
# All other args pass straight to 'coal'

coal_start() {
   # Check if 'solana' and 'coal' are installed
   for i in solana coal; do
      [ ! "$(which $i)" ] && printf '\e[1;31m%b\e[m\n' "ERROR\e[1;37m: $i not installed wyd" && exit 1
   done
   case "$1" in
      "forever") looptask="mine" && coals_loop && exit 0 ;;
      "smelever") looptask="smelt" && coals_loop && exit 0 ;;
   esac
#   [ "$1" == "forever" ] && coalmineloop && exit 0

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
      "uninstall") [ "$0" == "$HOME/.local/bin/coals" ] && printf '\e[1;33m%s\e[m\n' "Uninstalling coals..." && rm "$HOME/.local/bin/coals" && exit 0 ;;
      "update") coals_update && exit 0 ;;
      "version") echo "cw $cw_version"; coal -V; exit 0 ;;
      "mine"|"chop"|"smelt") _params="$1 --cores $(nproc) --buffer-time $buffer_time --priority-fee $prio_smol" ;;
      "reprocess"|"enhance") _params="$* --priority-fee $prio_big" ;;
      "stake"|"claim"|"balance")
         case "$2" in
            "") _params="$1 --priority-fee $prio_smol" ;;
            "coal"|"ingot"|"wood") _params="$1 --resource $2 --priority-fee $prio_smol" ;;
            "chromium"|ore)
               case "$1" in
                  "stake"|"claim") printf '\e[1;31m%b\e[m\n' "ERROR\e[1;37m: ${1} can't be staked" && exit 1 ;;
                  "balance")
                     case "$2" in
                        "chromium") _params="$1 --resource $2 --priority-fee $prio_smol" ;;
                        "ore") printf 'Balance: %s ORE\n' "$(spl-token balance oreoU2P8bN6jkk3jbaiVxYnG1dCXcYxwhwyK9jSybcp $_cfg)"; exit 0 ;;
                     esac ;;
               esac ;;
            *) printf '\e[1;31m%b\e[m\n' "ERROR\e[1;37m: bamboozled\n1=\"$1\"; 2=\"$2\"; *=\"$*\"" && exit 1 ;;
         esac ;;
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
   _app="while :; do coal_start $looptask; printf '\e[1;31m%s\e[m%s\n' \"ERROR\" \": Tantrum >:(\"; done"
   _log="coals_loop_output.log"
   printf "\n\n"

   while :; do

      # Print timestamp and say GMM
      printf "\e[2A\e[2K\e[1G\e[m%(%Y-%m-%d %H:%M:%S)T\n\n"
      printf "\e[1A\e[2K\e[1G\e[1;33mGMM\e[1;37m...\e[m\n\e[2K"

      # Get SOL balance (retry if not found (ie no internet) - ragequit if poor)
      sol_bal="$(solana balance --lamports 2>&1 | awk '{print $1}')"
      [[ "$sol_bal" == "Error"* ]] && printf '%s\n' "Balance not found, retrying..." && sleep 10 && continue
      [ "$sol_bal" -lt 10000000 ] && printf '\n%b\n\n' "\e[1;31mERROR:\e[m Not enough SOL :(" && break

      # Logn't
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
      sleep 2
      for (( D=10; D>0; D-- )); do
         printf '\e[m\e[1G%s\e[1;33m%2d' "Restarting in " "$D"
         sleep 1
      done

   done
}; export -f coals_loop

coals_install() {
   echo "Installing coals v$coals_version ...";
   [ -f "$HOME/.local/bin/coals" ] && coals_checkver || cver_this_isnewer=1;
   [ "$cver_this_isnewer" != "1" ] && exit 1;
   if [ ! -d "$HOME/.local/bin" ]; then
      echo "Creating directory $HOME/.local/bin";
      mkdir "$HOME/.local/bin";
      [ "$(echo $PATH | tr ":" "\n" | grep "$HOME/\.local/bin$")" == "" ] && export PATH="$HOME/.local/bin:$PATH";
   fi
   echo "Removing previous version" && rm "$HOME/.local/bin/coals";
   [ -d "$HOME/.local/bin" ] && mv "$0" "$HOME/.local/bin/coals";
   [ -f "$HOME/.local/bin/coals" ] && { chmod +x "$HOME/.local/bin/coals" && echo Installed as 'coals' in "$HOME/.local/bin"; } || { echo "Failed to install" && exit 1; }
}; export -f coals_install

coals_checkver() {
   IFS_="$IFS"
   IFS=.
   read -r -a cver_exist <<< "$(cat "./.local/bin/coals" | tail -n +2 | head -n 1 | grep -oP "\d\.\d\.\d")"
   read -r -a cver_this <<< "$(echo "$coals_version")"
   for i in ${!cver_exist[@]}; do
      [ ${cver_this[i]} -lt ${cver_exist[i]} ] && cver_this_isnewer=0 && break
      [ ${cver_this[i]} -gt ${cver_exist[i]} ] && cver_this_isnewer=1 && break
   done
   case "$cver_this_isnewer" in
      "") echo "Error: coals v$coals_version already installed (run 'coals uninstall' to remove)" ;;
      0) echo "Error: newer version (${cver_exist[*]}) already installed (run 'coals uninstall' to remove)" ;;
   esac
   IFS="$IFS_"
}; export -f coals_checkver

coals_update() {
echo "nothing"
   # Get latest version from GitHub
#   curl -sL "https://raw.githubusercontent.com/zoonose/coalness/main/coals.sh" -o "./coals.sh" || { echo "Failed to download coals.sh" && exit 1; }
   # Verify download
#   [ ! -f "./coals.sh" ] && echo "Failed to download coals.sh" && exit 1;
   # Check version
#   cat ./.local/bin/cw | awk -F'=' '/cw_version/ {print $2}' | tr "\"" "\0" | awk -f'.' {
}; export -f coals_update

[ "$0" == *"coals.sh" ] && coals_install || coal_start "$@"