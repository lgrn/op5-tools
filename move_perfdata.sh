#!/bin/bash
# MIT License
#
# Copyright (c) 2018, Linus Ågren, OP5
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

# Usage information:
#
#   This script will copy and/or move perfdata files for hosts or services
#   to paths specified in the script, if they exist.
#
#   The purpose of this script is to make it easier to use Nagflux and
#   PNP in parallel, or switch between the two, without having to modify
#   your command_line setting in misccommands.cfg -- instead, this script
#   will handle the logic, and will not move the files to a path that does
#   not exist -- or make sure it's in both, if they both exist.
#
# Example:
#
#   ./move_perfdata -c host -t 1543412003
#
#   Normally this would not be run manually, but would be configured in
#   misccommands.cfg as your "command_line" for process-service-perfdata,
#   or process-host-perfdata. Don't forget to change the -c flag:
#
#   define command{
#       command_name process-host-perfdata
#       command_line /opt/monitor/etc/move_perfdata.sh -c host -t $TIMET$
#   }
#
#   "$TIMET" is here a standard Nagios macro that will be replaced before
#   actually running the command.

err() {
    echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

# Check if this run has no arguments, i.e. "./move_perfdata.sh"

if [[ ! $@ =~ ^\-.+ ]]
then
    err "No arguments given: please use both -c [host|service] and -t [timestamp]. Exiting."; exit 1
fi

# Presumably we have some arguments, so let's go through them.

while getopts ":t:c:" opt; do
  case "${opt}" in
    t)

      # Is our timestamp a number?

      if [[ "$OPTARG" -ge 0 ]] ; then TIMET="$OPTARG";
      else err "The value you supplied for timestamp -t isn't a number. Exiting."; exit 1;
      fi
      ;;

    c)

      if [[ "$OPTARG" = "service" ]] ; then
        RUNTYPE="service"
      elif [[ "$OPTARG" = "host" ]] ; then
        RUNTYPE="host"
      else
        err "The value for -c must be 'service' or 'host'. Exiting."; exit 1; fi
      ;;

    \?)

      err "Invalid: -$OPTARG"; exit 1 ;;

    :)

      err "-$OPTARG missing argument."; exit 1 ;;

    esac
done

# These variables help with making paths shorter, since they're re-used

omv=/opt/monitor/var
omvn=/opt/monitor/var/nagfluxspool

# In order to make this run unique in temp filenames, we're saving the
# current timestamp and using $unixtime as a suffix.
# The assumption here is that two jobs of the exact same type won't start
# the same second.

unixtime=$(date +%s)

# Step 0: 'Snapshot' the perfdata file since new stuff comes into it constantly

if [[ $RUNTYPE == "service" ]]; then
  /bin/mv $omv/service-perfdata $omv/service-perfdata-$unixtime
elif [[ $RUNTYPE == "host" ]]; then
  /bin/mv $omv/host-perfdata $omv/host-perfdata-$unixtime
fi

# Step 1: Copy perfdata to nagflux spool, *if* it exists.

if [ -d $omvn/perfdata ]; then

    # Nagflux spool dir exists on this system, will *copy* service/host data.

    if [[ $RUNTYPE == "service" ]]; then
        /bin/cp $omv/service-perfdata-$unixtime $omvn/perfdata/service_perfdata.$TIMET
    elif [[ $RUNTYPE == "host" ]]; then
        /bin/cp $omv/host-perfdata-$unixtime $omvn/perfdata/host_perfdata.$TIMET
    fi

fi

# Step 2: If the regular perfdata spool exists, *move* the file so it's gone.

if [ -d $omv/spool/perfdata ]; then

    # Regular spool dir exists on this system, will *move* service/host data.

    if [[ $RUNTYPE == "service" ]]; then
        /bin/mv $omv/service-perfdata-$unixtime $omv/spool/perfdata/service_perfdata.$TIMET
    elif [[ $RUNTYPE == "host" ]]; then
        /bin/mv $omv/host-perfdata-$unixtime $omv/spool/perfdata/host_perfdata.$TIMET
    fi

fi

# Step 3: If step 2 didn't fire, and temp files are lying around,
# discard the temp files from this run.
# If we don't do this, the risk is that these lie around forever,
# causing more and more old data to be repeatedly re-sent to spool.
# If PNP or Nagflux isn't picking up the spool files, that's
# backlog enough, we don't need it duplicated.

if [[ $RUNTYPE == "service" ]]; then
    if [[ -f $omv/service-perfdata-$unixtime ]]; then
        /bin/rm $omv/service-perfdata-$unixtime
    fi
fi
if [[ $RUNTYPE == "host" ]]; then
    if [[ -f $omv/host-perfdata-$unixtime ]]; then
        /bin/rm $omv/host-perfdata-$unixtime
    fi
fi

