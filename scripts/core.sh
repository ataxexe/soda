#!/bin/bash
#                            The MIT License
#
#        Copyright (c) 2013 Marcelo Guimaraes <ataxexe@gmail.com>
# ----------------------------------------------------------------------
# Permission  is hereby granted, free of charge, to any person obtaining
# a  copy  of  this  software  and  associated  documentation files (the
# "Software"),  to  deal  in the Software without restriction, including
# without  limitation  the  rights to use, copy, modify, merge, publish,
# distribute,  sublicense,  and/or  sell  copies of the Software, and to
# permit  persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The  above  copyright  notice  and  this  permission  notice  shall be
# included  in  all  copies  or  substantial  portions  of the Software.
#                        -----------------------
# THE  SOFTWARE  IS  PROVIDED  "AS  IS",  WITHOUT  WARRANTY OF ANY KIND,
# EXPRESS  OR  IMPLIED,  INCLUDING  BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN  NO  EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM,  DAMAGES  OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT  OR  OTHERWISE,  ARISING  FROM,  OUT OF OR IN CONNECTION WITH THE
# SOFTWARE   OR   THE   USE   OR   OTHER   DEALINGS  IN  THE  SOFTWARE.

SODA_VERSION="1.5.0"

# Stores the usage for exposed commands
TASKS_USAGE="  TASKS:"
PARAMETERS_USAGE="  PARAMETERS:"

NAMESPACES=""
TASKS=""

BASH_COMPLETION_TASKS=""
BASH_COMPLETION_PARAMETERS=""

# Used for showing the namespaces of task functions in help message
TASK_NAMESPACE=""
PARAMETER_NAMESPACE=""

clear_help_usage() {
  TASKS_USAGE="  TASKS:"
  PARAMETERS_USAGE="  PARAMETERS:"
}

#
# Enables a function to be invoked as a task in SODA. If a description is given, expose the given
# function in the program usage and register it for autocompletion.
#
# Tasks not registered cannot be executed.
#
# Arguments:
#
#   1- function name
#   2- function args (optional)
#   3- function description
#
task() {
  local task_name="${1//_/-}"
  local task_description=""
  local task_args=""
  if [[ $# == 2 ]]; then
    task_description="$2"
  elif [[ $# == 3 ]]; then
    task_args=" $2"
    task_description="$3"
  fi
  if [[ -n "$task_description" ]]; then
    TASKS_USAGE="$TASKS_USAGE
    $(printf "%-${SODA_FUNCTION_NAME_LENGTH}s" "$TASK_NAMESPACE$task_name$task_args") $task_description"
    BASH_COMPLETION_TASKS="$BASH_COMPLETION_TASKS $TASK_NAMESPACE${task_name}"
  fi
  TASKS="$TASKS {$TASK_NAMESPACE${task_name}}"
}

#
# Exposes the given parameter in the program usage, register it for autocompletion
# and returns indicating if the parameter was given. You can access the parameter
# value through the variable named as the parameter name with upper case and hyphens
# replaced by unerscores.
#
# Arguments:
#
# parameter name, [parameter value, [default value]], description
#
parameter() {
  extract_parameter "$@"
  if [[ $parameter_value ]]; then
    if [[ "$parameter_value" == true ]]; then
      if [[ -n "$default_value" ]]; then
        log_debug "Setting default value for $parameter_name: $default_value"
        set_var "$parameter_name" "$default_value"
      fi
    fi
    return 0
  else
    return 1
  fi
}

#
# Exposes the given parameter in the program usage as a convention. If it's not
# given through the command line, the default value will be assumed
#
# Arguments:
#
# parameter name, parameter value, default value, description
#
convention() {
  extract_parameter "$@"
  if [[ $parameter_value ]]; then
    return 0
  else
    log_debug "Setting default value for $parameter_name: $default_value"
    set_var "$parameter_name" "$default_value"
    return 1
  fi
}

extract_parameter() {
  parameter_name="$(lowercase ${1//_/-})"
  parameter_value=""
  default_value=""
  local description=""
  if [[ $# == 3 ]]; then
    parameter_value="$2"
    description="$3"
  elif [[ $# == 4 ]]; then
    parameter_value="$2"
    default_value="$3"
    description="$4 (defaults to '$3')"
  else
    description="$2"
  fi
  if [[ "$parameter_value" == *"["*"]" ]]; then
    local optional=true
    parameter_value="${parameter_value/[/[=}"
  elif [[ -n "$parameter_value" ]]; then
    parameter_value="=${parameter_value}"
  fi
  PARAMETERS_USAGE="$PARAMETERS_USAGE
    $(printf "%-${SODA_PARAMETER_NAME_LENGTH}s" "--${parameter_name}${parameter_value}")"
  PARAMETERS_USAGE="${PARAMETERS_USAGE}$(printf "%+${SODA_PARAMETER_NAMESPACE_LENGTH}s" "$PARAMETER_NAMESPACE") $description"
  BASH_COMPLETION_PARAMETERS="$BASH_COMPLETION_PARAMETERS --${parameter_name}"
  if [[ -n "$parameter_value" ]]; then
    BASH_COMPLETION_PARAMETERS="${BASH_COMPLETION_PARAMETERS}="
    if [[ $optional ]]; then
      BASH_COMPLETION_PARAMETERS="$BASH_COMPLETION_PARAMETERS --${parameter_name}"
    fi
  fi
  parameter_name="$(uppercase ${parameter_name//-/_})"
  parameter_value="$(get_var "$parameter_name")"
}

SODA_IMPORTS=""

clear_imports() {
  SODA_IMPORTS=""
  TASK_NAMESPACE=""
  PARAMETER_NAMESPACE=""
  BASH_COMPLETION_PARAMETERS=""
  BASH_COMPLETION_TASKS=""
}

#
# Loads all scripts in the *scripts/namespace* directory. The scripts may be in
# $SODA_USER_HOME or $SODA_HOME.
#
# If a namespace was already imported, then it will not be imported again.
#
# Example: to import the namespace denoted by $SODA_USER_HOME/scripts/install
# use `import install`.
#
import() {
  if [[ ! $(echo "$SODA_IMPORTS" | grep ":$1:") ]]; then
    if [[ "$1" != "soda" ]]; then
      if [[ "$1" != "common" ]]; then
        TASK_NAMESPACE="$1$SODA_NAMESPACE_DELIMITER"
        PARAMETER_NAMESPACE="[$1]"
      fi
    fi
    SODA_IMPORTS="$SODA_IMPORTS:$1:"
    NAMESPACES="$NAMESPACES $1"
    local OLD_NAMESPACE="$NAMESPACE"
    NAMESPACE="$1"
    load_config "$SODA_HOME/config/$1"
    if ! [[ "$SODA_HOME" == "$SODA_USER_HOME" ]]; then
      load_config "$SODA_USER_HOME/config/$1"
    fi

    load_scripts "$SODA_HOME/scripts/$1"
    if ! [[ "$SODA_HOME" == "$SODA_USER_HOME" ]]; then
      load_scripts "$SODA_USER_HOME/scripts/$1"
      load_binaries "$SODA_USER_HOME/bin/$1"
    fi
    load_binaries "$SODA_HOME/bin/$1"
    if [[ -n $OLD_NAMESPACE ]]; then
      NAMESPACE="$OLD_NAMESPACE"
    fi
    return 0
  else
    return 1
  fi
}

_import_all() {
  if [[ -d "$1/scripts" ]]; then
    for namespace in $1/scripts/*; do
      if [[ -d "$namespace" ]]; then
        import "$(basename $namespace)"
      fi
    done
  fi
}

import_all_namespaces() {
  _import_all $SODA_HOME
  if ! [[ "$SODA_HOME" == "$SODA_USER_HOME" ]]; then
    _import_all $SODA_USER_HOME
  fi
}

#
# Loads all scripts inside a directory
#
load_scripts() {
  if [[ -d "$1" ]]; then
    DIRNAME=$1
    for script in $1/*.sh; do
      . "$script"
    done
  fi
}

#
# Put the directory in PATH
#
load_binaries() {
  if [[ -d "$1" ]]; then
    export PATH="$PATH:$1"
  fi
}

#
# Loads all config files inside a directory
#
load_config() {
  if [[ -d "$1" ]]; then
    for config in $1/*.conf; do
      if [[ -f "$config" ]]; then
        . "$config"
      fi
    done
  fi
}

set_parameter() {
  local parameter="${1#*--}"
  if [[ -z "$parameter" ]]; then
    return 1
  fi
  local value="${parameter#*=}"
  if [[ ! $(echo "$1" | grep -ie "=") ]]; then
    value=true
  fi
  parameter="${parameter%%=*}"
  parameter="${parameter//-/_}"
  parameter="$(uppercase $parameter)"
  set_var "$parameter" "$value"
}

#
# Parse the function name. By convention, '-' will be replaced
# by '_' to build the function name.
#
build_name() {
  echo "${1//-/_}"
}

task_exists() {
  if [[ "$TASKS" == *"{$1}"* ]]; then
    return 0
  else
    return 1
  fi
}

parse_task() {
  TASK="$1"
  NAMESPACE="${TASK%%$SODA_NAMESPACE_DELIMITER*}"
  TASK="${TASK#*${SODA_NAMESPACE_DELIMITER}}"
  if [[ "${NAMESPACE}" == "$1" ]]; then
    NAMESPACE=""
  fi
  TASK=$(build_name "$TASK")
  if [[ -n "$NAMESPACE" ]]; then
    return 0
  else
    return 1
  fi
}

# Dynamically sets a variable value.
set_var() {
  eval "$1=\"$2\""
}

# Dynamically gets a variable value
get_var() {
  eval echo "\$$1"
}

# Converts the string to upper case (for use with old versions of bash)
uppercase() {
  echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Converts the string to lower case (for use with old versions of bash)
lowercase() {
  echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Appends the value to the given variable (creates the variable if necessary)
append_to_var() {
  local content="$(get_var "$1") $2"
  set_var "$1" "${content}"
}

# Returns all namespaces
namespaces() {
  import_all_namespaces
  echo "$NAMESPACES"
}

# Returns a resource based on the current namespace.
resource() {
  local folder="$SODA_DEFAULT_RESOURCE_DIR"
  local filename=""
  if [[ $# == 1 ]]; then
    filename="$1"
  elif [[ $# == 2 ]]; then
    folder="$1"
    filename="$2"
  fi
  echo "$SODA_USER_HOME/$folder/$NAMESPACE/$filename"
}

# Returns a resource in "config" folder based on the current namespace.
config() {
  resource config $1
}

# Loads the given file (if exists). The file is checked using #exists function
load() {
  exists "$@" && source "$FILE"
}

# Checks if a resource exists based on the current namespace.
exists() {
  FILE="$(resource "$@")"
  if [[ -e "$FILE" ]]; then
    return 0
  else
    return 1
  fi
}
