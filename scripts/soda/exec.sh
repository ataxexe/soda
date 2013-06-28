#!/bin/sh

#
# Invokes a function based on user choice. Additionally, a pre_$function
# and post_$function will be invoked if exists.
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
      read option
    }
    echo "$2=$option" >> $OPTIONS_FILE
    echo "$option" | grep -qi "^Y$" && {
      [ -n "$(type -t "pre_$2")" ] && {
        debug "Invoking pre_$2"
        pre_$2
      }
      debug "Invoking $2"
      $2
      [ -n "$(type -t "post_$2")" ] && {
        debug "Invoking post_$2"
        post_$2
      }
    }
  }
}

#
# Asks user about something and indicates if the answer is 'yes' or 'no'
#
function ask {
  echo "$(bold_white "$1 (")$(bold_green 'y')$(bold_white '/')$(bold_green 'N')$(bold_white ')')"
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

#
# Parse the function name. By convention, '-' will be replaced
# by '_' to build the function name.
#
function build_function_name {
  echo "${1//-/_}"
}

#
# Calls the given function with the given args.
#
# Before the call, the function name will be normalized using
# the conventions in #build_function_name.
#
# To call a function in a namespace without import it implicit, use
# the sintax namespace::function as the function name.
#
function call {
  function="$1"
  shift
  if [[ -n "$function" ]]; then
    if [[ $(echo "$function" | grep -ie "::") ]]; then
      namespace="${function%%::*}"
      function="${function#*::}"

      import $namespace
    fi
    "${build_function_name function}" "$@"
  fi
}

# Aborts the script
function abort {
  debug "Aborted with exit code $1"
  exit $1
}

#
# Indicates that a reboot is required. Soda will ask to reboot
# before terminate.
#
function require_reboot {
  REBOOT_REQUIRED=true
}

#
# Finish the program.
#
function finish {
  [ "$REBOOT_REQUIRED" == true ] && {
    warn "A reboot is required to complete process!"
    invoke "Reboot system" reboot
  }
}

#
# Reboots the system
#
function reboot {
  warn "Rebooting system now!"
  init 6
}
