#!/usr/bin/env bash
coals_version="0.1.8.1"
# 'coals': easy launcher for 'coal' (coal-cli 2.9.2)

coal_start() {

   [ "$1" == "" ] && { coals_help; exit 0; }
   [ "$1" == "help" ] && { printf '\e[1;32m%s\e[m%s\n' "coals" " help:"; coals_help;  printf '\n\e[1;32m%s\e[m%s\n' "coal" " help:"; coal help; exit 0; }

   [ "$1" == "update" ] && { coals_update; exit; }

   [ "$1" == "uninstall" ] && [ "$0" == "$HOME/.local/bin/coals" ] && {
      printf '\e[1;33m%s\e[m' "Uninstalling coals..."
      rm "$HOME/.local/bin/coals" && {
         [ -f "$HOME/.config/solana/coals_config.yml" ] && {
            printf '%s\n\e[1;37m%s\e[m%s\e[1;37m%s\e[m' "DONE" "Delete config file" " $HOME/.config/solana/coals_config.yml" "? [Y/N]: "; 
            rm -i "$HOME/.config/solana/coals_config.yml" 2>/dev/null && { echo "OK"; exit 0; }
         }
      } || { echo "failed :("; exit 1; }
   }

   # Check if 'solana' and 'coal' are installed
   for i in solana coal; do
      [ ! "$(which $i)" ] && { echo "Error: $i not installed wyd"; exit 1 ;}
   done

   # [ "$#" -gt 2 ] && echo "Error: too many args (argh!)" && exit 1
   # Switch to infinite loop mode if specified
   [ "$2" == "forever" ] && {
      case "$1" in
         "mine") { looptask="mine"; export -f coal_start; coals_loop; exit 0; } ;;
         "smelt") { looptask="smelt"; export -f coal_start; coals_loop; exit 0; } ;;
         *) { echo "'forever' is only for 'mine' or 'smelt'."; exit 1; } ;;
      esac;
   }

   # Auto set a different 'solana' config for each username (or don't)
   case "$USER" in
      # "<your_username_here>") _cfg="--config $HOME/.config/solana/<whatever_config_file_you_want_to_use>.yml" ;;
      *) _cfg="--config $HOME/.config/solana/coals_config.yml" ;; # fallback to default
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
      "enhance"|"equip") [ "$2" != "" ] && [ "$2" == "$(grep -oP "[1-9A-HJ-NP-Za-km-z]{32,44}" <<< "$2")" ] &&
         { _params="$1 --tool $2 --priority-fee $( [ "$1" == "equip" ] && echo "$prio_smol" || echo "$prio_big" )"; } ||
         { echo "Usage: 'coals $1 <tool_address>'"; exit 1; } ;;
      "stake"|"claim")
         case "$2" in
            "") _params="$1 --priority-fee $prio_smol" ;;
            "coal"|"ingot"|"wood") _params="$1 --resource $2 --priority-fee $prio_smol" ;;
            "chromium"|"ore") { echo "Nah: $2 can't be staked"; exit 1; } ;;
            *) { echo "Options: [coal], ingot, wood."; exit 1; } ;;
         esac ;;
      "balance")
         case "$2" in
            "") _params="$1" ;;
            "coal"|"ingot"|"wood"|"chromium") _params="$1 --resource $2" ;;
            "ore") { printf 'Balance: %s ORE\n' "$(spl-token balance oreoU2P8bN6jkk3jbaiVxYnG1dCXcYxwhwyK9jSybcp $_cfg)"; exit; } ;;
            "all") 
               printf '\e[1;30m%s\e[m\n' "$(grep -oP "[^/]*$" <<< "$_cfg")"
               for h in "Balance" "Stake"; do
                  printf '\e[1;37m%s\e[m\n' "$h:"
                  for i in "sol" "coal" "ingot" "wood" "chromium" "ore"; do
                     case "$i" in
                        "sol") [ "$h" == "Balance" ] &&
                           while read line; do 
                              [[ "$line" == *"Error"* ]] && { echo Error, check connection; echo exit; } || 
                              printf '%12.4f %s\n' "$(grep -oP "\d+(\.\d+)?" <<< "$line")" "SOL"; 
                           done <<< "$(solana balance 2>&1)" ;;
                        "coal"|"ingot"|"wood") 
                           printf '%12.4f %s\n' "$(coal balance --resource "$i" | grep -ioP "(?<=$h:\ )\d+(\.\d+)?")" "${i^^}" ;;
                        "chromium") [ "$h" == "Balance" ] && 
                           printf '%12.4f %s\n' "$(coal balance --resource "$i" | grep -ioP "(?<=$h:\ )\d+(\.\d+)?")" "${i^^}" ;;
                        "ore") [ "$h" == "Balance" ] && 
                           printf '%12.4f %s\n' "$(spl-token balance oreoU2P8bN6jkk3jbaiVxYnG1dCXcYxwhwyK9jSybcp $_cfg)" "${i^^}" ;;
                     esac
                  done
               done ; exit 0 ;;
            *) { echo "Options: [coal], ingot, wood, chromium, ore, all."; exit 1; } ;;
         esac ;;
      "version") coal -V; exit 0 ;;
      *) _params="$*" ;;
   esac

   # Print 'solana' config filename, wallet address, SOL balance, and 'coal' parameters
   printf '\e[1;30m'
   printf '%s\n' "$_cfg" | grep -oP "[^/]*$" # hmm
   printf '%s\n' "$(solana address $_cfg || echo "address not found"; solana balance $_cfg || echo "balance not found")"
   printf '%s\n' "$_params"
   printf '\e[m'

   # omg it's happening omg
   bash -c "coal $_cfg $_params"
}


# Error-catching infinite loop
coals_loop() {

   # Make ^C exit look a bit cleaner
   trap 'sleep 3; printf "\e[1A\n"; [ -f "$_log" ] && rm "$_log"' EXIT

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
      [[ "$sol_bal" == "Error"* ]] && { printf '%s\n' "Balance not found, retrying..."; sleep 10; continue; }
      [ "$sol_bal" -lt 10000000 ] && { printf '\n\e[1;31m%s\e[m%s\n\n' "ERROR: " "Not enough SOL :("; break; }

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
}


coals_install() {
   echo "Installing 'coals' $coals_version"

   # Check for and remove previous version
   [ -f "$HOME/.local/bin/coals" ] && coals_checkver && { printf '%s' "Removing previous version..."; rm "$HOME/.local/bin/coals"; } && echo "done"

   # Check for and create "~/.local/bin" directory
   [ ! -d "$HOME/.local/bin" ] && { printf '%s' "Creating directory $HOME/.local/bin..."; mkdir "$HOME/.local/bin"; } && echo "done"

   # Add to PATH if not already there (only for current session; bash should add it automatically on startup if it exists)
   [ "$(echo "$PATH" | tr ":" "\n" | grep "$HOME/\.local/bin$")" == "" ] && export PATH="$HOME/.local/bin:$PATH"

   # Create default config file if it doesn't exist
   # The commitment level is 'processed' instead of solana's default of 'final' to help with transaction wait times.
   local coalfig="$HOME/.config/solana/coals_config.yml"
   [ ! -f "$coalfig" ] && { printf '%s\n%s\n%s\n%s\n%s\n' "---" "json_rpc_url: 'https://api.mainnet-beta.solana.com'" "websocket_url: ''" "keypair_path: '$HOME/.config/solana/id.json'" "commitment: 'processed'" > "$coalfig"; echo "Created default config file at $coalfig"; }

   # Check that ~/.local/bin exists and move this script there and rename to 'coals' and make it executable and report result
   [ -d "$HOME/.local/bin" ] && mv "$0" "$HOME/.local/bin/coals" && chmod +x "$HOME/.local/bin/coals" && echo "Installed in $HOME/.local/bin" || { echo "Failed to install"; exit 1; }
}


coals_checkver() {
   # Set delimiter to '.' and make arrays of version numbers
   local IFS=. cver_exist cver_this cver_this_isnewer
   cver_this=($coals_version)
   cver_exist=($(grep -oPm 1 "(?<=coals_version=\")(\d+\.)+\d+(?=\")" < "$HOME/.local/bin/coals"))
   
   # Equalise lenth of arrays
   for g in $(seq -s. $(( ${#cver_this[@]} - ${#cver_exist[@]} ))); do cver_exist+=(0); done 
   for h in $(seq -s. $(( ${#cver_exist[@]} - ${#cver_this[@]} ))); do cver_this+=(0); done

   # Compare versions
   for i in "${!cver_exist[@]}"; do
      [ "${cver_this[i]}" -lt "${cver_exist[i]}" ] && { cver_this_isnewer=0; break; }
      [ "${cver_this[i]}" -gt "${cver_exist[i]}" ] && { cver_this_isnewer=1; break; }
   done

   # Exit if same or older version than installed
   case "$cver_this_isnewer" in
      "") { echo "coals $coals_version already installed (run 'coals uninstall' to remove)"; exit 0; } ;;
      0) { echo "Error: newer version (${cver_exist[*]}) already installed (run 'coals uninstall' to remove)"; exit 1; } ;;
   esac
}


coals_update() {
   local fetch_temp
   fetch_temp=$(mktemp --suffix ".coals.sh")
   echo "Downloading latest version..."
   curl -sL "https://raw.githubusercontent.com/zoonose/coalness/main/coals.sh" -o "$fetch_temp" || { echo "Failed to download" && exit 1; }
   [ -f "$fetch_temp" ] && bash "$fetch_temp" || { echo "Something went wrong"; exit 1; }
   [ -f "$fetch_temp" ] && rm "$fetch_temp"
}


coals_help() {
   cat <<< "
Every 'coals' command
All other commands (including invalid ones) are passed through directly to 'coal':
   coals                        # show this help message
   coals help                   # show this help message and the 'coal' help message
   coals mine                   # mine for coal
   coals mine forever           # mine for coal and auto-restart on error
   coals smelt                  # smelt for iron ingots (cost 75 coal and 0.01 ore per ingot)
   coals smelt forever          # smelt for iron ingots and auto-restart on error
   coals chop                   # chop for wood
   coals replant                # replant trees after chopping
   coals reprocess              # reprocess for chromium
   coals inspect                # inspect currently equipped pickaxe
   coals unequip                # unequip currently equipped pickaxe
   coals craft                  # craft a new pickaxe (cost 3 ingot and 2 wood)
   coals enhance <tool_address> # enhance specified pickaxe (cost 1 chromium and 0.01 sol)
   coals equip <tool_address>   # equip specified pickaxe
   coals stake                  # stake all coal in wallet
   coals stake coal             # stake all coal in wallet
   coals stake ingot            # stake all ingot in wallet
   coals stake wood             # stake all wood in wallet
   coals claim                  # claim all staked coal
   coals claim coal             # claim all staked coal
   coals claim ingot            # claim all staked ingot
   coals claim wood             # claim all staked wood
   coals balance                # show coal balance
   coals balance coal           # show coal balance
   coals balance ingot          # show ingot balance
   coals balance wood           # show wood balance
   coals balance chromium       # show chromium balance
   coals balance ore            # show ore balance
   coals balance all            # show all balances (sol, coal, ingot, wood, chromium, ore)
   coals version                # show version numbers of 'coals' and 'coal'
   coals update                 # update 'coals' to latest version
   coals uninstall              # uninstall 'coals'
   "
}

#------------------------------------------------------------------------------

# Run installer if script filename ends with 'coals.sh'
[[ "$0" == *"coals.sh" ]] && { coals_install; exit 0; }

# Otherwise run the main function
echo "coals $coals_version"
coal_start "$@"
