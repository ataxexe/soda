#!/bin/sh

#
# Invokes a function based on user choice.
#
# Arguments:
#
#   1- Function description (used in the question message)
#   2- Function name
#
# If there is a variable named exactly like the function, its
# value will be used instead of asking user.
#
# The value of the user choice will be stored in the $OPTIONS_FILE file.
#
function invoke {
  [ -n "$(type -t $2)" ] && {
    option=$(get_var "$2")
    [ -z "$option" ] && {
      echo "$(bold_white "$1? (")$(bold_green 'y')$(bold_white '/')$(bold_green 'N')$(bold_white ')')"
      printf "$(yellow " > ")"
      read option
    }
    echo "$2=$option" >> $OPTIONS_FILE
    echo "$option" | grep -qi "^Y$" && {
      debug "Invoking $2"
      $2
    }
  }
}

#
# Asks user about something and indicates if the answer is 'yes' or 'no'
#
function ask {
  echo "$(bold_white "$1 (")$(bold_green 'y')$(bold_white '/')$(bold_green 'N')$(bold_white ')')"
  printf "$(yellow " > ")"
  read option
  echo "$option" | grep -qi "^Y$"
}

#
# Checks if the previous command returned successfully.
#
# Arguments:
#
#  1- The command description
#
function check {
  code="$?"
  if [[ $code == 0 ]]; then
    success "$1"
  else
    fail "$1" $code
  fi
}

#
# Executes a command and checks if it was sucessfull. The output will be redirected
# to $LAST_COMMAND_LOG_FILE
#
# Arguments:
#
#  1- The command description
#  ...- The command itself
#
function execute {
  description=$1
  shift
  printf "%-60s " "$description"
  $@ &>$LAST_COMMAND_LOG_FILE
  code="$?"
  cat $LAST_COMMAND_LOG_FILE >> $COMMAND_LOG_FILE
  if [[ $code == 0 ]]; then
    printf "[  %s  ]\n" $(green "OK")
    log "OK" "$description"
  else
    printf "[ %s ]\n" $(red "FAIL")
    log "FAIL" "$description"
  fi
}