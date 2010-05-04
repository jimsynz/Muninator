#!/bin/sh

# This is a simple script that runs through your Rails apps (I
# have mine in a group called "Rails", see the munin.conf docs)
# and hits it with wget to make sure it's spawned - you might 
# need this, if like me you are using Passenger.
# I have this in my /etc/cron.d/munin:
# */5 * * * *     munin if [ -x /usr/bin/munin-cron ]; then /usr/local/bin/munin_rails.sh ; /usr/bin/munin-cron; fi

awk '/^\[Rails\;(.+)\]$/{print gensub(/.*;(.+)]/,"wget -O /dev/null -q http://\\1","")}' /etc/munin/munin.conf  | sh
