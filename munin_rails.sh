#!/bin/sh

# ***** BEGIN LICENSE BLOCK *****
# Version: MPL 1.1
#
# The contents of this file are subject to the Mozilla Public License Version
# 1.1 (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
# http://www.mozilla.org/MPL/
#
# Software distributed under the License is distributed on an "AS IS" basis,
# WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
# for the specific language governing rights and limitations under the
# License.
#
# The Original Code is Muninator Rails Plugin.
#
# The Initial Developer of the Original Code is James Harton.
#
# Portions created by the Initial Developer are Copyright (C) 2010, 2011
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#
# ***** END LICENSE BLOCK *****

# This is a simple script that runs through your Rails apps (I
# have mine in a group called "Rails", see the munin.conf docs)
# and hits it with wget to make sure it's spawned - you might 
# need this, if like me you are using Passenger.
# I have this in my /etc/cron.d/munin:
# */5 * * * *     munin if [ -x /usr/bin/munin-cron ]; then /usr/local/bin/munin_rails.sh ; /usr/bin/munin-cron; fi

awk '/^\[Rails\;(.+)\]$/{print gensub(/.*;(.+)]/,"wget -O /dev/null -q http://\\1","")}' /etc/munin/munin.conf  | sh
