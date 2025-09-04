#!/usr/bin/env bash
# cw.sh 0.1.1 for coal-cli 2.9.2
   # Launcher for coal [mine|chop|smelt|reprocess|forever]
      # eg., 'bash cw.sh forever'
   # All other args pass straight to 'coal'
      # eg., 'bash cw.sh balance'

coals() {
   # Check if 'solana' and 'coal' are installed
   for i in solana coal; do
      [ ! "$(which $i)" ] && printf '\e[1;31m%b\e[m\n' "ERROR\e[1;37m: \"$i\" not installed wyd" && exit 1
   done

   [ "$1" == "forever" ] && coalw && exit 0

   # Auto set a different 'solana' config for each username (or don't)
   case "$USER" in
      "asdf") _cfg="$HOME/.config/solana/dirtyore.yml" ;;    #[Y]
      "asdg") _cfg="$HOME/.config/solana/filthyore.yml" ;;   #[0]
      *) printf '\e[1;37m%b\e[m\n' "No custom solana config defined for \"${USER}\", using default."
   esac

   # Set 'coal' parameters
   # - pay high fee to reprocess for $CHROMIUM because reward is timing dependent
   buffer_time=2
   [ "$1" == "reprocess" ] && priority_fee=2112112 || priority_fee=2501
   case "$1" in
      "mine"|"chop"|"smelt"|"reprocess") _params="$* --cores $(nproc) --buffer-time $buffer_time --priority-fee $priority_fee" ;;
      *) _params="$*" ;;
   esac

   # Print 'solana' config filename, wallet address, SOL balance, and 'coal' parameters
   printf '\e[1;30m'
   printf '%s\n' "$_cfg" | grep -oP "[^/]*$" # hmm
   printf '%s\n' "$(solana --config "$_cfg" address && solana --config "$_cfg" balance)"
   printf '%s\n' "$_params"
   printf '\e[m'

   # omg it's happening omg
   bash -c "coal --config $_cfg $_params"

}; export -f coals

# Error-catching infinite loop
coalw() {

   # Make ^C exit look a bit cleaner
   trap 'sleep 2; printf "\e[1A\n"; [ -f "$_log" ] && rm "$_log"' EXIT

   # Terminal command to monitor with 'script'
   _app="while :; do coals mine; printf '\e[1;31m%s\e[m%s\n' \"ERROR\" \": Tantrum >:(\"; done"
   _log="coals_output.log"
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
}; export -f coalw

coals "$*"