#!/usr/bin/env bash
coals_version="0.1.13.37.420"
# 'coals': easy launcher for 'coal' (coal-cli 2.9.2)

coal_start() {

   # Set 'coal' parameters
   # - pay high fee to reprocess for $CHROMIUM and enhance tools because reward is timing dependent
   freecores=0       # number of CPU cores to leave unused when mining/smelting/chopping
   buffer_time=2     # seconds
   prio_smol=111     # lamports
   prio_big=2000002  # lamports

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
      # "asdf"|"asdg") freecores=2 ;;&
      # "asdc") freecores=4 ;;&
      *) _cfg=(--config "$HOME/.config/solana/coals_config.yml") ;; # fallback to default
   esac

   # Switch to infinite loop mode for work functions
   shopt -s extglob
   [ -f "$0" ] && [[ "$1" == @("mine"|"smelt"|"chop") ]] && { looptask="$1" ; export -f coal_start ; coals_loop ; exit ;}

   # Parse args
   case "$1" in
      "mine"|"smelt"|"chop")
         case "$2" in
            "") _params=("$1" --cores "$(( $(nproc) - freecores ))" --buffer-time "$buffer_time" --priority-fee "$prio_smol") ;;
            "forever") { echo "'forever' is default behaviour, no need to specify it" ; exit ;} ;;
         esac ;;
      "reprocess") _params=("$1" --priority-fee "$prio_big") ;;
      "inspect")
         case "$2" in
            "") _params=("$1" --priority-fee "$prio_smol") ;;
            *) [ "$2" != "" ] && [ "$2" == "$(grep -oP "[1-9A-HJ-NP-Za-km-z]{32,44}" <<< "$2")" ] &&
               { inspect_external "$2" ; exit ;} ||
               { echo "Usage: 'coals $1 [<tool_address>]'" ; exit ;} ;;
         esac ;;
      "unequip"|"craft"|"replant") _params=("$1" --priority-fee "$prio_smol") ;;
      "enhance"|"equip") [ "$2" != "" ] && [ "$2" == "$(grep -oP "[1-9A-HJ-NP-Za-km-z]{32,44}" <<< "$2")" ] &&
         { _params=("$1" --tool "$2" --priority-fee "$( [ "$1" == "equip" ] && echo "$prio_smol" || echo "$prio_big" )") ;} ||
         { echo "Usage: 'coals $1 <tool_address>'" ; exit ;} ;;
      "stake"|"claim")
         case "$2" in
            "") _params=("$1" --priority-fee "$prio_smol") ;;
            "coal"|"ingot"|"wood") _params=("$1" --resource "$2" --priority-fee "$prio_smol") ;;
            "chromium"|"ore") { echo "Nah: $2 can't be staked" ; exit ;} ;;
            *) { echo "Options: [coal], ingot, wood." ; exit ;} ;;
         esac ;;
      "balance")
         case "$2" in
            ""|"all") coals_balance ; exit ;;
            "coal"|"ingot"|"wood"|"chromium") _params=("$1" --resource "$2") ;;
            "ore") { printf 'Balance: %s ORE\n' "$(spl-token balance oreoU2P8bN6jkk3jbaiVxYnG1dCXcYxwhwyK9jSybcp "${_cfg[@]}")" ; exit ;} ;;
            *) { echo "Options: coal, ingot, wood, chromium, ore." ; exit ;} ;;
         esac ;;
      "version") coal -V ; exit ;;
      *) _params=("$@") ;;
   esac

   # Print 'solana' config filename, wallet address, SOL balance, and 'coal' parameters
   printf '\e[1;30m'
   printf '%s\n' "${_cfg[1]}" | grep -oP "[^/]*$" # hmm
   printf '%s\n' "$(solana address "${_cfg[@]}" || echo "address not found" ; solana balance "${_cfg[@]}" || echo "balance not found")"
   printf '%s\n' "${_params[*]}"
   printf '\e[m'

   # omg it's happening omg
   bash -c "coal ${_cfg[*]} ${_params[*]}"

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
   printf '\n'

   while : ; do
      kill "$(pidof coal)" "$_app_pid" 2>/dev/null

      # Print timestamp and say GMM
      printf "\e[1A\e[1G\e[m%(%Y-%m-%d %H:%M:%S %Z)T\n\n"
      printf "\e[1G\e[1;33mGMM\e[1;37m...\e[m\n\n"

      # Get SOL balance (retry if not found (ie no internet) - ragequit if poor)
      sol_bal="$(solana balance --lamports "${_cfg[@]}" 2>&1 | awk '{print $1}')"
      [[ "$sol_bal" == "Error"* ]] && { printf '\e[2A\e[2K%s' "Balance not found, retrying..." ; sleep 11 ; printf '\e[2K' ; continue ;}
      [ "$sol_bal" -lt 10000000 ] && { printf '\e[1;31m%s\e[m%s\n\n' "ERROR: " "Not enough SOL :(" ; break ;}

      # Flush log
      : > "$_log"

      # Do mining until death
      script -qfc "$_app" "$_log" &
      _app_pid=$!

      # Kill if death or when log file becomes chonkish or if thing-happening stops
      tail -F -n +2 "$_log" | while read -r -t 40 -n 15970 line; do
         [ "$(wc -c < "$_log")" -gt 6942069 ] && [[ "$(tail -n 1 "$_log")" == *"OK"* ]] && kill HUP "$_app_pid" 2>/dev/null && { echo ; sleep 3 ; printf '\n\e[1;36m%s\e[m\n\n' "Flushing temp file" ; break ;}
         [ "$(grep -oi "error" <<< "$line")" != "" ] && { printf '\n%b\n\n' "\U274c \U274c \U274c \U274c \U274c" ; kill $_app_pid 2>/dev/null ; break ;}
      done

      # Catch (probable) smelter failure and break the loop
      [ "$looptask" == "smelt" ] && [ "$(tail "$_log" | grep -P '(error: 0x1)|(foreman)')" != "" ] && { printf '\n%s\n\n' "RUH ROH Probably not enough coal/ore for the smelter!" ; break ;}

      # Catch ecocide and break the loop
      [ "$looptask" == "chop" ] && [ "$(tail "$_log" | grep -P '(Needs reset)')" != "" ] && { printf '\n%s\e[48;5;130m\e[38;5;226m%s\e[38;5;21m%s\e[38;5;220m%s\e[m\n%s\n\n' "RUH ROH All the trees have been chopped! Lorax is judging you  " ">" ":" "{ " "Remember to replant so the forest can grow back!" ; break ;}

      # Hold horses
      sleep 3
      for (( D=7 ; D>0 ; D-- )) ; do printf '\e[m\e[1G%s\e[1;33m%d\e[m' "Restarting in " "$D" ; sleep 1 ; done ; echo
   done
   exit
}


coals_balance() {
   declare -A coals_bals coals_stakes
   balance_order=(sol coal ingot wood chromium ore)
   stake_order=(coal ingot wood)
   coals_tools=()
   results=$(mktemp) ; trap 'kill "${pids[@]}" "$timeoutpid" 2>/dev/null ; rm -f $results' EXIT

   make_fetch_happen() {
      local resource="$1" output type
      case $resource in
         sol) output="$(solana balance "${_cfg[@]}" 2>&1)" ;;
         ore) output="$(spl-token balance oreoU2P8bN6jkk3jbaiVxYnG1dCXcYxwhwyK9jSybcp "${_cfg[@]}" 2>/dev/null)" ;;
         *) output="$(coal balance --resource "$resource" "${_cfg[@]}" 2>/dev/null)" ;;
      esac
      while read -r line; do
         [[ "$line" == *"Error"* ]] && sleep 11
         [[ "$line" == "Stake"* ]] && type="stake" || type="balance"
         value="$(grep -ioP "\d+(\.\d+)?" <<< "$line")"
         echo "${type},${resource},${value}"
      done <<< "$output"
   }

   tool_time_equipped() {
      output="$(coal inspect "${_cfg[@]}" 2>/dev/null)"
      [ "$output" != "" ] && grep -zoP "(?<=Inspected:\s)([1-9A-HJ-NP-Za-km-z]{32,44})|(?<=Durability:\s)(\d+(\.\d+)?)|(?<=Multiplier:\s)(\d+(\.\d+)?)" <<< "$output" | awk 'BEGIN{RS="\0"} {a[NR]=$0} END{printf "tool,,*#%s#%s#%s#%s\n", a[1], a[3] * 100, a[2], "<- Equipped!"}'
   }

   tool_time_unequipped() {
      local -A tools_blah
      local sol_addr fk_outa_hea rpc_output jq_output tool_addr tool_mult tool_durb
      sol_addr="$(solana address "${_cfg[@]}" 2>/dev/null)"
      fk_outa_hea="$(mktemp)"
      trap 'kill "${cull_pids[@]}" 2>/dev/null ; rm -f "$fk_outa_hea"' EXIT

      # sub function to check which 'MplCoreAsset's are not actually NFTs
      tool_cull() { [ "$(solana account "$1" | grep "Length:" | awk '{print $2}')" == 1 ] && echo "$1" ;}

      # get all MplCoreAssets in wallet
      rpc_output="$(curl -s -X POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"searchAssets\",\"params\":{\"interface\":\"MplCoreAsset\",\"ownerAddress\":\"$sol_addr\"}}" "https://api.mainnet-beta.solana.com")"

      # get address and durability for items which are unburnt and have durability attribute
      jq_output="$(jq -r '.result.items[]? | select(.burnt == false)? | select(.plugins.attributes.data.attribute_list[]? | select(.key == "multiplier")? | select(.value)?)? | select(.plugins.attributes.data.attribute_list[]? | select(.key == "durability")? | select(.value)?)? | "\(.id),\((.plugins.attributes.data.attribute_list[] | select(.key == "multiplier") | .value)),\((.plugins.attributes.data.attribute_list[] | select(.key == "durability") |.value))"' <<<"$rpc_output")"

      # read info into array
      [ "$jq_output" != "" ] && while IFS=, read -r tool_addr tool_mult tool_durb; do tools_blah["$tool_addr"]="$tool_mult#$tool_durb" ; done <<< "$jq_output"

      # call cull function in parallel for super fast ultra speedyness
      for i in "${!tools_blah[@]}"; do [ "$(grep -oP "#1000$" <<< "${tools_blah[$i]}")" != "" ] && tool_cull "$i" >> "$fk_outa_hea" & cull_pids+=($!) ; done

      # wait for cull functions to finish
      for pid in "${cull_pids[@]}"; do wait "$pid" 2>/dev/null ; done

      # remove non-tools from array
      while read -r line; do unset "tools_blah[$line]" ; done < "$fk_outa_hea"

      # print results
      for i in "${!tools_blah[@]}" ; do printf 'tool,,#%s#%s\n' "$i" "${tools_blah[$i]}" ; done
   }

   # mystery function what it does who can tell. you thought maybe the comment would give you a clue but no.
   printf '\n%s' "Fetching..."

   # get balances
   for i in "${balance_order[@]}" ; do make_fetch_happen "$i" >> "$results" & pids+=($!) ; done

   # get equipped tool info
   tool_time_equipped "$i" >> "$results" & pids+=($!)

   # get spent tool addresses if 'jq' is installed
   [ "$(which jq)" != "" ] && { tool_time_unequipped "$i" >> "$results" & pids+=($!) ;}

   # timeout countdown
   (for _ in {0..7} ; do sleep 1 ; printf '.' ; done ; kill "${pids[@]}" 2>/dev/null) & timeoutpid="$!"

   # wait for fetch
   for pid in "${pids[@]}"; do wait "$pid" 2>/dev/null ; done

   # quit if timed out
   kill -0 "$timeoutpid" 2>/dev/null || { printf '\e[2K\r%s\n' "Error fetching balances :(" ; exit ;} ; kill "$timeoutpid"

   # put results in arrays
   while IFS=',' read -r type resource value; do
      case $type in
         "balance") coals_bals["$resource"]="$value" ;;
         "stake") coals_stakes["$resource"]="$value" ;;
         "tool") coals_tools+=("$value") ;;
      esac
   done < "$results"

   # print it
   printf '\e[2K\r'
   printf '\e[1;37m%s\e[m\n' "Balance:" ; for B in "${balance_order[@]}" ; do printf '%12.4f %s\n' "${coals_bals[$B]}" "${B^^}" ; done
   printf '\e[1;37m%s\e[m\n' "Stake:" ; for S in "${stake_order[@]}" ; do printf '%12.4f %s\n' "${coals_stakes[$S]}" "${S^^}" ; done
   printf '\e[1;37m%s\e[m\n' "Tools:" ;
   if [ "${#coals_tools[@]}" -eq 0 ] ; then
      printf '\e[7G%s\n' "None"
   else
      printf '\e[1;30m\e[7G%s\e[54G%s\e[62G%s\e[m\n' "Address" "Mult." "Durability"
      for i in ${!coals_tools[@]} ; do awk 'BEGIN{FS="#"} {printf "\33[4G\33[1;30m%s\33[m\33[7G%s\33[54G%4.2fx\33[62G%10.5f\33[74G\33[1;30m%s\33[m\n",$1,$2,$3/100,$4,$5}' <<< "${coals_tools[$i]}" ; done
      [ "$(which jq)" == "" ] && printf '\e[7G\e[1;30m%s\n' "(Install 'jq' to see non-equipped tools here)"
   fi
   printf '\n'
}


inspect_external() {
   local -A inspectoor
   local rpc_output jq_output
   local equipped_as_bro="nah"

   [ "$(which jq)" == "" ] && { echo "Error: To use this feature, 'jq' must be installed." ; exit ;}

   rpc_output="$(curl -sX POST -H "Content-Type: application/json" -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getAsset\",\"params\":{\"id\":\"$1\"}}" https://api.mainnet-beta.solana.com)"

   jq_output="$(jq -r ' .result? | select(.burnt == false)? | select( .grouping[]?|select(.group_key)|select(.group_value=="CuaLHUJA1dyQ6AYcTcMZrCoBqssSJbqkY7VfEEFdxzCk")? )? | select( .ownership.owner )? | select( .content.metadata.name )? | select( .plugins.attributes.data.attribute_list[]?|select(.key == "multiplier")?|select(.value)? )? | select( .plugins.attributes.data.attribute_list[]?|select(.key == "durability")?|select(.value)?)? | "Address=\(.id)", "Type=\(.content.metadata.name)", "Owner=\(.ownership.owner)", "Multiplier=\((.plugins.attributes.data.attribute_list[]|select(.key=="multiplier")|.value))", "Durability=\((.plugins.attributes.data.attribute_list[]|select(.key=="durability")|.value))" ' <<< "$rpc_output")"

   [ "$jq_output" == "" ] && { printf '\n%s\n\n' "Hmm: That does not seem to be a minechain tool!" ; exit ;}

   while IFS="=" read -r key value; do
      inspectoor["$key"]="$value"
   done <<< "$jq_output"

   # if the owner of the owner address is not the system program, the tool must be equipped-as, bro.
   [ "$(solana account "${inspectoor[Owner]}" | grep -oP "(?<=Owner: )1{32}")" == "" ] && equipped_as_bro="yeah"

   # if the durability value returned by the asset lookup is 1000, it might be brand-new, or it might not be an actual tool NFT
   [ "${inspectoor[Durability]}" == "1000" ] && [ "$(solana account "${inspectoor[Address]}" | grep "Length:" | awk '{print $2}')" == 1 ] && { printf '\n%s\n\n' "Hmm: If you're reading this, you may be a 1337 h4x0r and/or a curious cat, but that is not a valid tool, sorry. *womp womp*)" ; exit ;}

   # format the multiplier for printin'
   inspectoor[Multiplier]="$(awk -v var="${inspectoor[Multiplier]}" 'BEGIN {printf "%4.2fx", var/100}')"

   # printy mcprintface
   printf '\n\e[1;37m%s\e[m' "Tool info:"
   for i in Type Multiplier Durability Address Owner ; do printf '\n\e[4G\e[1;30m%10s:\e[m\e[16G%s' "$i" "${inspectoor[$i]}" ; done

   # if the tool is currently equipped, warn that the "owner" is not the actual owner
   [ "$equipped_as_bro" == "yeah" ] && printf '\e[1;33m%s\n\e[16G\e[1;30m%s\n\e[16G%s\e[m' " *" "Note: This \"owner\" is a Program Derived Address!" "> This tool might be in use down in the mines, or for sale at the market."
   printf '\n\n'
}


coals_update() {
   local fetch_temp
   fetch_temp=$(mktemp)
   printf '%s' "Downloading latest version..."
   curl -sL "https://raw.githubusercontent.com/zoonose/coalness/main/coals.sh" -o "$fetch_temp" && echo "done" || { echo " Failed to download :(" && exit 1 ;}
   [ -f "$fetch_temp" ] && bash "$fetch_temp" || echo "Something went wrong"
   rm -f "$fetch_temp"
}


coals_install() {

   echo "Installing coals $coals_version"

   # Check for and remove previous version
   [ -f "$HOME/.local/bin/coals" ] && coals_checkver && { 
      printf '%s' "Removing previous version..."
      oldcoals="$(mktemp --suffix "_old_coals.sh")"
      trap 'rm -f "$oldcoals"' EXIT
      mv "$HOME/.local/bin/coals" "$oldcoals"
   } && echo "done"

   # Check for and create "~/.local/bin" directory
   [ ! -d "$HOME/.local/bin" ] && { printf '%s' "Creating directory $HOME/.local/bin..." ; mkdir "$HOME/.local/bin" ;} && echo "done"

   # Add to PATH if not already there (only for current session; bash should add it automatically on startup if it exists)
   [ "$(echo "$PATH" | tr ":" "\n" | grep "$HOME/\.local/bin$")" == "" ] && export PATH="$HOME/.local/bin:$PATH"

   # Create default config file if it doesn't exist
   # The commitment level is 'processed' instead of (default) 'final' to help with transaction wait times.
   local coalfig="$HOME/.config/solana/coals_config.yml"
   [ ! -f "$coalfig" ] && { printf '%s\n%s\n%s\n%s\n%s\n' "---" "json_rpc_url: 'https://api.mainnet-beta.solana.com'" "websocket_url: ''" "keypair_path: '$HOME/.config/solana/id.json'" "commitment: 'processed'" > "$coalfig" ; echo "Created default config file at $coalfig" ;}

   # Check that ~/.local/bin exists and move this script there and rename to 'coals' and make it executable and report result
   [ -d "$HOME/.local/bin" ] && mv "$0" "$HOME/.local/bin/coals" && chmod +x "$HOME/.local/bin/coals" && printf '\n%s\n%s\n\n' "Installed in $HOME/.local/bin" "run 'coals' to see a list of commands" || { echo "Failed to install" ; printf '%s' "Restoring previous version..." ; mv "$oldcoals" "$HOME/.local/bin/coals" && echo done || { echo failed ; exit 1 ;} ;}
}


coals_checkver() {

   # Set delimiter to '.' and make arrays of version numbers
   local IFS=. cver_exist cver_this cver_this_isnewer
   cver_this=() ; cver_exist=()
   read -r -a cver_this <<< "$coals_version"
   read -r -a cver_exist <<< "$(grep -oPm 1 "(?<=coals_version=\")(\d+\.)+\d+(?=\")" < "$HOME/.local/bin/coals")"

   # Equalise lenth of arrays
   for _ in $(seq -s. $(( ${#cver_this[@]} - ${#cver_exist[@]} ))) ; do cver_exist+=(0) ; done
   for _ in $(seq -s. $(( ${#cver_exist[@]} - ${#cver_this[@]} ))) ; do cver_this+=(0) ; done

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
   printf '\n\e[1;33m%s\e[m%s\n' "GMM" "!"
   cat <<< "
Notes:
- Transaction fees for mining/smelting/chopping are approximately $(awk -v var="$prio_smol" 'BEGIN {printf "%.2g", (var+5000)*60/10^9}') sol per hour.
  > 5000 lamport base fee + $prio_smol lamport priority fee per tx (1 tx per minute).
  > Smelting also burns coal and wraps ore (see below).
- Higher fee for reprocess/enhance because rewards partially depend on precise transaction timing.
  > 5000 lamport base fee + $prio_big lamport priority fee per tx (2 tx per operation).
  > Enhancing also consumes chromium and additional sol (see below).
- To adjust fees or processor usage, edit '~/.local/bin/coals' and change these variables (near the top):
  > Priority fees (in lamports): 'prio_smol' (most functions), and 'prio_big' (reprocess/enhance).
  > Number of CPU cores to NOT use while mining etc: 'freecores'.
  > Note: These changes will not persist through updates. A better solution may come in future :)
- To use a different solana keypair, edit '~/.config/solana/coals_config.yml'.
- Mining/smelting/chopping will auto-restart on non-fatal errors.
- Commands not listed below (including invalid & typos) will be passed through to 'coal'.

Every 'coals' command:
   coals                           # show this help message
   coals help                      # show this help message and the 'coal' help message
   coals mine                      # mine for coal
   coals smelt                     # smelt for iron ingots (cost 75 coal and 0.01 ore per ingot)
   coals chop                      # chop for wood
   coals replant                   # replant trees after chopping
   coals reprocess                 # reprocess for chromium (cost $(awk -v var="$prio_big" 'BEGIN {printf "%.2g", 2*(var+5000)/10^9}') sol)
   coals craft                     # craft a new pickaxe (cost 3 ingot and 2 wood)
   coals inspect [<tool_address>]  # inspect currently equipped tool [or <tool_address>]
   coals unequip                   # unequip currently equipped tool
   coals enhance <tool_address>    # enhance specified pickaxe (cost 1 chromium and $(awk -v var="$prio_big" 'BEGIN {printf "%.2g", 2*(var+5000)/10^9+0.01}') sol)
   coals equip <tool_address>      # equip specified pickaxe
   coals balance                   # show all balances, stakes, and tools
   coals balance <resource>        # show balance [& stake] of <resource> (coal, ingot, wood, chromium, ore)
   coals stake [<resource>]        # stake all coal [or <resource>: coal, ingot, wood]
   coals claim [<resource>]        # claim all staked coal [or <resource>: coal, ingot, wood]
   coals version                   # show version numbers of 'coals' and 'coal'
   coals update                    # update 'coals' to latest version
   coals uninstall                 # uninstall 'coals'
"
}

#------------------------------------------------------------------------------

[ -f "$0" ] || { echo "Not like this" ; exit 1 ;}
[[ "$0" != "$HOME/.local/bin/coals" ]] && { coals_install ; exit ;}

printf '%s\n' "coals $coals_version"
case "$1" in balance) printf '%(%Y-%m-%d %H:%M:%S %Z)T\n' ;; esac
coal_start "$@"