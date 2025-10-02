#!/usr/bin/env bash
coals_version="0.1.11.2"
# 'coals': easy launcher for 'coal' (coal-cli 2.9.2)

coal_start() {

   # Set 'coal' parameters
   # - pay high fee to reprocess for $CHROMIUM and enhance tools because reward is timing dependent
   freecores=0       # number of CPU cores to leave unused when mining/smelting/chopping
   buffer_time=2     # seconds
   prio_smol=111     # lamports
   prio_big=2112112  # lamports

   case "$1" in
      "") coals_help ; exit ;;
      "help") printf '\e[1;32m%s\e[m%s\n' "coals" " help:" ; coals_help ; printf '\n\e[1;32m%s\e[m%s\n' "coal" " help:" ; coal help ; exit ;;
      "update") coals_update ; exit ;;
      "uninstall") coals_uninstall ; exit ;;
   esac

   # Check if 'solana' and 'coal' are installed
   for i in solana coal ; do
      [ ! "$(which $i)" ] && { echo "Error: $i not installed wyd" ; exit ;}
   done

   # Auto set a different 'solana' config for each username (or don't)
   case "$USER" in
      # "<your_username_here>") _cfg="--config $HOME/.config/solana/<whatever_config_file_you_want_to_use>.yml" ;;
      # "asd"?) freecores=2 ;;&
      *) _cfg="--config $HOME/.config/solana/coals_config.yml" ;; # fallback to default
   esac

   # Switch to infinite loop mode for work functions
   shopt -s extglob
   [ -f "$0" ] && [[ "$1" == @("mine"|"smelt"|"chop") ]] && { looptask="$1" ; export -f coal_start ; coals_loop ; exit ;}

   # Parse args
   case "$1" in
      "mine"|"smelt"|"chop")
         case "$2" in
            "") _params="$1 --cores $(( $(nproc) - $freecores )) --buffer-time $buffer_time --priority-fee $prio_smol" ;;
            "forever") { echo "'forever' is default behaviour, no need to specify it" ; exit ;} ;;
         esac ;;
      "reprocess") _params="$1 --priority-fee $prio_big" ;;
      "inspect"|"unequip"|"craft"|"replant") _params="$1 --priority-fee $prio_smol" ;;
      "enhance"|"equip") [ "$2" != "" ] && [ "$2" == "$(grep -oP "[1-9A-HJ-NP-Za-km-z]{32,44}" <<< "$2")" ] &&
         { _params="$1 --tool $2 --priority-fee $( [ "$1" == "equip" ] && echo "$prio_smol" || echo "$prio_big" )" ;} ||
         { echo "Usage: 'coals $1 <tool_address>'" ; exit ;} ;;
      "stake"|"claim")
         case "$2" in
            "") _params="$1 --priority-fee $prio_smol" ;;
            "coal"|"ingot"|"wood") _params="$1 --resource $2 --priority-fee $prio_smol" ;;
            "chromium"|"ore") { echo "Nah: $2 can't be staked" ; exit ;} ;;
            *) { echo "Options: [coal], ingot, wood." ; exit ;} ;;
         esac ;;
      "balance")
         case "$2" in
            ""|"all") coals_balance ; exit ;;
            "coal"|"ingot"|"wood"|"chromium") _params="$1 --resource $2" ;;
            "ore") { printf 'Balance: %s ORE\n' "$(spl-token balance oreoU2P8bN6jkk3jbaiVxYnG1dCXcYxwhwyK9jSybcp $_cfg)" ; exit ;} ;;
            *) { echo "Options: coal, ingot, wood, chromium, ore." ; exit ;} ;;
         esac ;;
      "version") coal -V ; exit ;;
      *) _params="$*" ;;
   esac

   # Print 'solana' config filename, wallet address, SOL balance, and 'coal' parameters
   printf '\e[1;30m'
   printf '%s\n' "$_cfg" | grep -oP "[^/]*$" # hmm
   printf '%s\n' "$(solana address $_cfg || echo "address not found" ; solana balance $_cfg || echo "balance not found")"
   printf '%s\n' "$_params"
   printf '\e[m'

   # omg it's happening omg
   bash -c "coal $_cfg $_params"

   # this should only happen if 'coal' freaks out while mining/smelting/chopping
   [[ "$0" != *"coals" ]] && echo "ERROR: Tantrum >:("
}


# Error-catching infinite loop
coals_loop() {

   # Cleanup on exit
   trap 'kill $(pidof coal) $_app_pid 2>/dev/null ; [ -f "$_log" ] && rm "$_log" ; sleep 3 ; echo' EXIT

   # Terminal command to monitor with 'script'
   _app="coal_start $looptask"
   _log="$(mktemp --suffix ".coals.log")"
   printf "\n\n"

   while : ; do
      kill $(pidof coal) $_app_pid 2>/dev/null
      # Print timestamp and say GMM
      printf "\e[2A\e[2K\e[1G\e[m%(%Y-%m-%d %H:%M:%S)T\n\n"
      printf "\e[1A\e[2K\e[1G\e[1;33mGMM\e[1;37m...\e[m\n\e[2K"

      # Get SOL balance (retry if not found (ie no internet) - ragequit if poor)
      sol_bal="$(solana balance --lamports $_cfg 2>&1 | awk '{print $1}')"
      [[ "$sol_bal" == "Error"* ]] && { printf '%s\n' "Balance not found, retrying..." ; sleep 10 ; continue ;}
      [ "$sol_bal" -lt 10000000 ] && { printf '\n\e[1;31m%s\e[m%s\n\n' "ERROR: " "Not enough SOL :(" ; break ;}

      # Flush log
      : > "$_log"

      # Do mining until death
      script -qfc "$_app" "$_log" &
      _app_pid=$!

      # Kill if death or when log file becomes chonkish or if thing-happening stops
      tail -F -n +2 "$_log" | while read -r -t 40 -n 15970 line; do
         [ "$(wc -c < "$_log")" -gt 6942069 ] && [[ "$(tail -n 1 "$_log")" == *"OK"* ]] && kill HUP "$_app_pid" 2>/dev/null && { echo ; sleep 3 ; printf '\n\e[1;36m%s\e[m\n\n\n\n' "Flushing temp file" ; break ;}
         [ "$(grep -oi "error" <<< "$line")" != "" ] && { echo ; for i in {1..5} ; do printf '\U274c ' ; done ; echo ; kill $_app_pid 2>/dev/null ; break ;}
      done

      # Catch (probable) smelter failure and break the loop
      [ "$looptask" == "smelt" ] && [ "$(tail "$_log" | grep -P '(error: 0x1)|(foreman)')" != "" ] && { printf '\n%s\n' "RUH ROH Probably not enough coal for the smelter!" ; break ;}

      # Catch ecocide and break the loop
      [ "$looptask" == "chop" ] && [ "$(tail "$_log" | grep -P '(Needs reset)')" != "" ] && { printf '\n%s\e[48;5;130m\e[38;5;226m%s\e[38;5;21m%s\e[38;5;220m%s\e[m\n%s\n\n' "RUH ROH All the trees have been chopped! Lorax is judging you  " ">" ":" "{ " "Remember to replant so the forest can grow back!" ; break ;}

      # Hold horses
      sleep 3
      for (( D=7 ; D>0 ; D-- )) ; do printf '\e[m\e[1G%s\e[1;33m%d\e[m' "Restarting in " "$D" ; sleep 1 ; done
   done
   exit
}


coals_balance() {
   declare -A coals_bals coals_stakes
   balance_order=(sol coal ingot wood chromium ore)
   stake_order=(coal ingot wood)
   results=$(mktemp) ; trap "rm -f $results" EXIT

   make_fetch_happen() {
      local resource="$1" output type

      case $resource in
         sol) output="$(solana balance $_cfg 2>&1)" ;;
         ore) output="$(spl-token balance oreoU2P8bN6jkk3jbaiVxYnG1dCXcYxwhwyK9jSybcp $_cfg 2>/dev/null)" ;;
         *) output="$(coal balance --resource "$resource" $_cfg 2>/dev/null)" ;;
      esac

      while read -r line; do
         [[ "$line" == *"Error"* ]] && sleep 11
         [[ "$line" == "Stake"* ]] && type="stake" || type="balance"
         value="$(grep -ioP "\d+(\.\d+)?" <<< "$line")"
         echo "${resource}:${type}:${value}"
      done <<< "$output"
   }

   printf '%s' "Fetching..."

   # get balances
   for i in "${balance_order[@]}" ; do
      make_fetch_happen "$i" >> "$results" &
      pids+=($!)
   done

   # timeout countdown
   (for t in {0..10} ; do sleep 1 ; printf '.' ; done ; kill "${pids[@]}" 2>/dev/null) & timeoutpid="$!"

   # wait for fetch
   for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null ; done

   # quit if timed out
   kill -0 "$timeoutpid" 2>/dev/null || { printf '\e[2K\r%s\n' "Error fetching balances :(" ; exit ;} ; kill "$timeoutpid"

   # put results in arrays
   while IFS=':' read -r resource type value; do
      case $type in
         "balance") coals_bals[$resource]=$value ;;
         "stake") coals_stakes[$resource]=$value ;;
      esac
   done < "$results"

   # print it
   printf '\e[2K\r'
   printf '\e[1;37m%s\e[m\n' "Balance:" ; for B in "${balance_order[@]}" ; do printf '%12.4f %s\n' "${coals_bals[$B]}" "${B^^}" ; done
   printf '\e[1;37m%s\e[m\n' "Stake:" ; for S in "${stake_order[@]}" ; do printf '%12.4f %s\n' "${coals_stakes[$S]}" "${S^^}" ; done
}


coals_update() {
   local fetch_temp
   fetch_temp=$(mktemp)
   echo "Downloading latest version..."
   curl -sL "https://raw.githubusercontent.com/zoonose/coalness/main/coals.sh" -o "$fetch_temp" || { echo "Failed to download" && exit 1 ;}
   [ -f "$fetch_temp" ] && bash "$fetch_temp" || { echo "Something went wrong" ; exit 1 ;}
   [ -f "$fetch_temp" ] && rm "$fetch_temp"
}


coals_install() {

   echo "Installing coals $coals_version" ; echo

   # Check for and remove previous version
   [ -f "$HOME/.local/bin/coals" ] && coals_checkver && { printf '%s' "Removing previous version..." ; rm "$HOME/.local/bin/coals" ;} && echo "done"

   # Check for and create "~/.local/bin" directory
   [ ! -d "$HOME/.local/bin" ] && { printf '%s' "Creating directory $HOME/.local/bin..." ; mkdir "$HOME/.local/bin" ;} && echo "done"

   # Add to PATH if not already there (only for current session; bash should add it automatically on startup if it exists)
   [ "$(echo "$PATH" | tr ":" "\n" | grep "$HOME/\.local/bin$")" == "" ] && export PATH="$HOME/.local/bin:$PATH"

   # Create default config file if it doesn't exist
   # The commitment level is 'processed' instead of (default) 'final' to help with transaction wait times.
   local coalfig="$HOME/.config/solana/coals_config.yml"
   [ ! -f "$coalfig" ] && { printf '%s\n%s\n%s\n%s\n%s\n' "---" "json_rpc_url: 'https://api.mainnet-beta.solana.com'" "websocket_url: ''" "keypair_path: '$HOME/.config/solana/id.json'" "commitment: 'processed'" > "$coalfig" ; echo "Created default config file at $coalfig" ;}

   # Check that ~/.local/bin exists and move this script there and rename to 'coals' and make it executable and report result
   [ -d "$HOME/.local/bin" ] && mv "$0" "$HOME/.local/bin/coals" && chmod +x "$HOME/.local/bin/coals" && printf '%s\n%s\n\n' "Installed in $HOME/.local/bin" "run 'coals' to see a list of commands" || { echo "Failed to install" ; exit 1 ;}
}


coals_checkver() {

   # Set delimiter to '.' and make arrays of version numbers
   local IFS=. cver_exist cver_this cver_this_isnewer
   cver_this=($coals_version)
   cver_exist=($(grep -oPm 1 "(?<=coals_version=\")(\d+\.)+\d+(?=\")" < "$HOME/.local/bin/coals"))

   # Equalise lenth of arrays
   for g in $(seq -s. $(( ${#cver_this[@]} - ${#cver_exist[@]} ))) ; do cver_exist+=(0) ; done
   for h in $(seq -s. $(( ${#cver_exist[@]} - ${#cver_this[@]} ))) ; do cver_this+=(0) ; done

   # Compare versions
   for i in "${!cver_exist[@]}"; do
      [ "${cver_this[i]}" -lt "${cver_exist[i]}" ] && { cver_this_isnewer=0 ; break ;}
      [ "${cver_this[i]}" -gt "${cver_exist[i]}" ] && { cver_this_isnewer=1 ; break ;}
   done

   # Exit if same or older version than installed
   case "$cver_this_isnewer" in
      "") { echo "Oops: coals $coals_version already installed (run 'coals uninstall' to remove it)" ; exit 0 ;} ;;
      0) { echo "Oops: newer version (${cver_exist[*]}) already installed (run 'coals uninstall' to remove it)" ; exit 1 ;} ;;
   esac
}


coals_uninstall() {
   printf '\e[1;33m%s\e[m' "Uninstalling coals..."
   [ "$0" == "$HOME/.local/bin/coals" ] && rm "$HOME/.local/bin/coals" && [ -f "$HOME/.config/solana/coals_config.yml" ] && {
      printf '%s\n\n\e[1;37m%s\e[m%s\e[1;37m%s\e[m' "DONE" "Delete config file" " $HOME/.config/solana/coals_config.yml" "? [Y/N]: "
      rm -i "$HOME/.config/solana/coals_config.yml" 2>/dev/null && { echo "OK" ; exit 0 ;} ;}
      echo "failed :(" ; exit 1
}


coals_help() {
   cat <<< "GMM!

Notes:
- cost of mining/smelting/chopping is approx $(awk -v var="$prio_smol" 'BEGIN {printf "%.2g", (var+5000)*60/10^9}') sol per hour.
   (5000 lamport base fee plus $prio_smol lamport priority fee per transaction)
   (smelting also burns coal and wraps ore (see below))

- cost of reprocessing and enhancing is $(( ($prio_big + 5000) * 2 )) lamports ($(awk -v var="$prio_big" 'BEGIN {printf "%.2g", 2*(var+5000)/10^9}') sol) per transaction.

- to adjust fees, edit '~/.local/bin/coals' and change ['prio_smol'|'prio_big'] variables near the top.
- to leave some of the CPU unused while doing work, edit '~/.local/bin/coals' and change 'freecores'.

- to use a different solana keypair, edit '~/.config/solana/coals_config.yml'.

- mining/smelting/chopping will auto-restart on non-fatal errors.

- commands not listed here (including invalid & typos) will be passed through to 'coal'.

Every 'coals' command:
   coals                        # show this help message
   coals help                   # show this help message and the 'coal' help message
   coals mine                   # mine for coal
   coals smelt                  # smelt for iron ingots (cost 75 coal and 0.01 ore per ingot)
   coals chop                   # chop for wood
   coals replant                # replant trees after chopping
   coals reprocess              # reprocess for chromium (cost $(awk -v var="$prio_big" 'BEGIN {printf "%.2g", 2*(var+5000)/10^9}') sol)
   coals craft                  # craft a new pickaxe (cost 3 ingot and 2 wood)
   coals inspect                # inspect currently equipped pickaxe
   coals unequip                # unequip currently equipped pickaxe
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
   coals balance                # show all balances (sol, coal, ingot, wood, chromium, ore)
   coals balance all            # show all balances (sol, coal, ingot, wood, chromium, ore)
   coals balance coal           # show coal balance
   coals balance ingot          # show ingot balance
   coals balance wood           # show wood balance
   coals balance chromium       # show chromium balance
   coals balance ore            # show ore balance
   coals version                # show version numbers of 'coals' and 'coal'
   coals update                 # update 'coals' to latest version
   coals uninstall              # uninstall 'coals'
"
}

#------------------------------------------------------------------------------

[ -f "$0" ] || { echo "Not like this" ; exit 1 ;}
[[ "$0" != "$HOME/.local/bin/coals" ]] && { coals_install ; exit ;}

echo "coals $coals_version"
coal_start "$@"