# soda

SODA is a simple platform to help writing and executing tasks in shell script.

## How It Works

SODA works by loading any scripts in a specific directory and calling a function passed by the command line. Only functions exposes through the builtin **task** function may be called.

## How To Install

Just clone the git repo and place the *soda* file in your path (a symlinks works well to) and you're done.

## How To Use

Create a *~/.soda* directory with the following structure:

* _scripts_ - directory to put the scripts organized by namespaces
* _config_ - directory to put the configuration files organized by namespaces
* Any other directory you like, still organized by namespaces

You can also use the same directory you install soda without configure the user directory. You can access any file in that directories by using the **exists** function.

Inside *scripts*, any function in any script present in *scripts/common* and exposed through **task** can be invoked:

    task "git-open" "Creates a new branch off master"
    git_open() {
      local branch="$1"
      if [[ -z "$branch" ]]; then
        input "Name your branch" branch work
      fi
      git checkout -b "$branch"
    }

    $ soda git-open work

This will call the *git_open* function passing *work* as the arguments. By convention, you may call a function with underscores replacing them by hyphens. To execute the task without arguments, just use `soda git-open`.

To see the program usage, type `soda`, `soda help` or `soda --help`.

## Task Namespaces

The namespaces are simply directories in _scripts_. By default, the *common* and *soda* namespaces are always imported. You can include other namespaces using the **import** function.

Namespaces are useful if you have a set of scripts that you should use only on specific cases. (It also keeps your scripts organized.)

    # Example: script inside ~/.soda/scripts/git

    task "push" "Push local commits into the repository"

    push() {
      stash_work
      local branch="$(current_branch)"
      if [[ "$branch" == "master" ]]; then
        echo "Pushing changes from master into server"
        git_push
      else
        echo "Pushing changes from $branch into master"
        git checkout master
        git merge "$branch"
        echo "Pushing changes from master into server"
        git_push
        echo "Going back to $branch branch"
        git checkout "$branch"
        git rebase master
      fi
      unstash_work
    }

You can call any task in *git* namespace using a **"."**:

    $ soda git.push

The **"."** indicates that namespace is the first part and task is the second part. To see a help message for only one namespace, use `soda help NAMESPACE` (additionally, you can place a `info`  file in the scripts folder for a namespace to make its contents appear in the help message).

## Task Parameters

If you need to pass a set of parameters, you can use --OPTION_NAME in case of a boolean option or --OPTION_NAME=OPTION_VALUE. The parameters will be translated replacing hyphens with underscores (but ignoring the prefix **--**) **with upper case**.

      $ soda --my-option=test

      # script
      if [[ -n "$MY_OPTION" ]]; then
        # some code
      fi

To register a parameter in the program usage, use the *parameter* function (for more details, see the documentation bellow). The registered parameters will also be available for bash completion.

Keep in mind that **any** parameter will be converted to a variable (even those not exposed).

## Events

You can subscribe and publish events in SODA using **when** and **broadcast** builtin functions.

    when finish say_goodbye
    say_goodbye() {
      echo "Goodbye, $1!"
    }

    broadcast finish "$USER"

The builtin events are:

* **start** - before the task execution
* **finish** - after the task execution
* **fail** *(output)* - when a command fails to execute (broadcasted by *execute* and *check* functions)

## Quick Tasks

Quick Tasks are tasks defined in a directory and will work only in that directory only. To use them, create a file `.soda-tasks` in any directory and call the tasks without using namespaces:

    task my-task
    my_task() {
      echo "My Task"
    }

    $ soda my-task

## Custom PATH

Any directory in the form `bin/$NAMESPACE` in both `$SODA_HOME` or `$SODA_USER_HOME` will be included in the `$PATH` variable.

## Bash Completion

SODA supports bash completion by importing all namespaces and searching for defined parameters and tasks. To enable bash completion, use the file **soda-bash-completion** (you can source it, copy to */etc/bash_completion.d/* or using your preferred way). The default bash completion proposes tasks and parameters.

    $ soda he[TAB]
    $ soda help

To customize the options for a given task, use a function named ${TASK}_bash_completion:

    my_task_bash_completion() {
      echo "foo"
      echo "bar"
    }

    $ soda my-task f[TAB]
    $ soda my-task foo

Alternatively, you can use the **suggest** function to map the bash completion function:

    suggest suggestions my_task
    suggestions() {
      echo "foo"
      echo "bar"
    }

If a parameter is passed after the task declaration in command line, the suggestions will be only the parameters for the task namespace.

    # namespace my-namespace

    parameter "option" "My custom option"
    task "my-task" "My task"
    my_task() {
      :
    }

    $ soda my-namespace.my-task --[TAB]
    $ soda my-namespace.my-task --option

It is important to remember that logs and event broadcasting are disabled while SODA is in bash completion mode.

## Configuration

Every namespace has it own configuration dir in $SODA_USER_HOME/config/NAMESPACE. Any configuration file will be loaded in that directory at namespace import **before** loading script files.

You can configure **soda** namespace through a **$SODA_USER_HOME/conf/soda/soda.conf** file (or any other name but inside that directory). The supported properties are:

* **SODA_NAMESPACE_DELIMITER** - The namespace delimiter (defaults to **.**). Changing this also affects the bash completion
* **SODA_TASK_BASH_COMPLETION_SUFFIX** - The suffix to build the function for custom bash completion (defaults to *_bash_completion*)
* **SODA_FILE_LOG_PATTERN** - The pattern to format logs that goes in *LOG_FILE*
* **SODA_CONSOLE_LOG_PATTERN** - The pattern to format logs that goes in console
* **SODA_FUNCTION_NAME_LENGTH** - The max length to format the function name in the help usage
* **SODA_PARAMETER_NAME_LENGTH** - The max length to format the parameter names in the help usage
* **SODA_PARAMETER_NAMESPACE_LENGTH** - The max length to format the parameter namespace in the help usage
* **SODA_DEFAULT_RESOURCE_DIR** - the default directory to search for resources (defaults to *resources*)
* **SODA_TASK_OPTIONAL_PREFIX** - the optional prefix to map a task function (defaults to *do_*)

Remember that parameters are converted to upper case, so you can call `soda --log-file=path/to/file` and the *$LOG_FILE* variable will be set to that value.

The parameter **SODA_TASK_OPTIONAL_PREFIX** is very usefull in case of tasks with a name already defined by another function or name (*kill* or *status*, for example). To avoid conflicts, prefix the function with the SODA_TASK_OPTIONAL_PREFIX value (*do_kill*, *do_status*, ...).

## Logging

To log something, just call the **log** function passing the category and message (optionally, you can pass a color for showing in console). There are some aliases for calling log with a predefined category:

* **log_debug** - uses the DEBUG category
* **log_info** - uses the INFO category
* **log_notice** - uses the NOTICE category
* **log_warn** - uses the WARN category
* **log_error** - uses the ERROR category
* **log_fatal** - uses the FATAL category

Log messages are shown in console, if you need to persist them, pass the parameter `--log-file=/path/to/the/file`. To disable the console log, pass the parameter `--no-console-log`.

### Custom logging

If you want to use another log system (a *syslog* or another) just define a **log** function.

    log() {
      local category="$1"
      local message="$2"
      logger -s -t "$category" "$message"
    }

## Builtin functions

The builtin functions are present in *scripts/soda* dir and the *scripts/core.sh*, the most significant are listed below:

### task (function_name, [function_args], [description])

Register the given function as a task and enables invoking it. You may pass the function args in *$function_name*. If a description is given, expose the given function in the program usage and register it for autocompletion.

### parameter (parameter_name, [value_name] ,[default_value], description)

Register the given parameter and returns indicating if the parameter was given. The parameter value is accessible through the variable $parameter_name in upper case with hyphens replaced by underscores.

    parameter "help" "Prints this help message" && {
      usage
    }

    parameter "backup-extension" "[EXTENSION]" "bak" "Indicates the extension for file backup" && {
      additional_parameters="$additional_parameters --extension=$BACKUP_EXTENSION"
    }

### convention (parameter_name, parameter_value, convention_value, description)

Same as `#parameter` but applies to values that have a convention and, so, will have always a value assigned (even
if the user didn't specify one).

    convention "output-format" "pdf" "Sets the output format"

    echo "$OUTPUT_FORMAT" # will print 'pdf' if user didn't use the `--output-format` parameter.

### exists ([type] path)

Checks if the file $SODA_USER_HOME/$type/$NAMESPACE/$path exists using the namespace of the invoked task or imported namespace. The file path will be stored in the $FILE variable. If the *type* is not passed then **resources** will be used.

    exists config "my-config.conf" && {
      source $FILE
    }

### load ([type] path)

Call `#exists` and, if the file exists, `source` it.

### resource ([type] path)

Returns the file $SODA_USER_HOME/$type/$NAMESPACE/$path using the namespace of the invoked task or imported namespace without checking if the file exists. If the *type* is not passed then **resources** will be used. For use with the **config** type, use the `config` builtin function. The `config` function redirects to the resource function using *config* as the first parameter and the given parameter as the second parameter.

### invoke (description, function_name)

Invokes the given function based on user choice.

### ask (question)

Asks user about something and indicates if the answer is **yes** or **no**.

    ask "Push commits?" && {
      git push
    }

### check (description)

Checks if the previous command returned successfully and logs the result using the given description.

### execute (description, command, [*args])

Executes a command and checks if it was sucessfull. The output will be stored in the variable *$LAST_EXECUTION_OUTPUT* and the code in *${LAST_EXECUTION_CODE}*.

    execute "Pushing commits" git push
    # outputs according to exit code:
    # Pushing commits           [  OK  ]
    # Pushing commits           [ FAIL ]

### input (description, variable, [default_value])

Asks the user to input a value. The value will be stored in the indicated variable. If the variable name is in upper case and is already set, the prompt will be skipped.

    input "Server address" "SERVER" "localhost"
    input "User name" "USER_NAME" "$(whoami)"

    scp file $USER_NAME@$SERVER:/tmp/.

### choose (description, variable, *options)

Asks user to choose a value from a list of options and stores the 0-based index of the selected value and the label in the $variable_label var. If the variable name is in upper case and is already set, the prompt will be skipped.

    choose "Server Type" "SERVER_TYPE" "Production" "Development"

    echo "$SERVER_TYPE: $SERVER_TYPE_label"

### suggest (suggestion_function tasks...)

Maps the given function as the bash completion function to the given tasks.

### when (event_name subscribers...)

Subscribe the given functions to the specified event name. The subscribers should be notified using the *broadcast* function.

### broadcast (event_name [args...])

Broadcast the event to the subscribers using the given arguments.

## Examples

Check out the **examples** dir for a simple set of tasks that may help you.
