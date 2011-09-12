# Easy extensible graphing of your Rails app using Munin

I have used [Munin](http://munin-monitoring.org) for years to monitor machines that I am looking after and recently, after migrating my sites to a new [linode](http://linode.com) I found myself setting up `munin-node` again and reflecting on Munin's very simple protocol to talking to nodes over the network.

I had been lamenting the lack of visibility of what's going on inside my rails app without going overboard with products like [New Relic's RPM](http://newrelic.com), so I decided to write a rails plugin that turns your Rails application into a munin-node by implementing the protocol that Munin uses.  This, like Munin's protocol itself, was trivially easy.

It's my pleasure to present [Muninator](http://github.com/jamesotron/Muninator).  I have it running for.  As you can tell from my graphs, this site doesn't exactly get a lot of traffic, but I think you get the idea.

## Installation

Getting Muninator running in your app is trivially easy, start by installing the plugin (preferred for Rails 2)

    $ ./script/plugin install git://github.com/jamesotron/Muninator.git

Or Just add the 'muninator' gem to your application's Gemfile (preferred way for Rails 3)

    gem 'muninator'

## Configuration

Next create `config/muninator.yml` and tell it what environments, ports, etc you want it to use (most likely you only want to monitor your production environment, but just like `config/database.yml` you can specify configs for `development` and `test` also). 

    $ rails generate muninator:install

Here I am instructing Muninator to listen on TCP port 4950 (Munin-node usually uses 4949, but I am incrementing from there) and the `server_name` attribute must match that configured in your `munin.conf` (more on that later).  The `restrict` option can be a list of IP addresses or `localhost` which is an alias for `::1`, `fe80::1` and `127.0.0.1`.

    $ cat <<EOF > config/muninator.yml
    > production:
    >   server_name: myrailsapp.com
    >   port: 4950
    >   restrict: localhost
    >   # standalone: true
    > EOF
   
If you set standalone to true, you will be able to start muninator by its own by invoking script/muninator - you will loose your controller / performance benchmarks but the server will be always up.

## Data Sources

### Build in
By default Muninator will load plugins to monitor process memory usage (resident and virtual size), disk I/O and thread state.  I expect these don't give very accurate data however when running on systems like [Passenger](http://modrails.com) which will `fork` multiple instances of the application, although they do give you an idea of how much memory each instance is using and whether it is [grinding](http://en.wikipedia.org/wiki/Grinding_%28video_gaming%29).

### Models
You can also add automagic monitoring of your models (at the moment, just total row count plus additions and modifications) by calling the `acts_as_munin_plugin` class method within your models.  You might also want to add an explicit call to the model class in your `config/initializers/muninator.rb` to make sure that the model is loaded at application start-up (by default models are lazy-loaded by Rails).

### Controllers
In addition to automagic monitoring of models you get detailed monitoring of controller actions for no extra cost by calling the `monitor_with_munin` class method within your controller. By default it will monitor all RESTful actions (ie `:index`, `:new`, `:create`, `:show`, `:edit`, `:update` and `:destroy`), or you can specify arbitrary actions by adding an argument like so: `:actions => [ :action_name, :other_action_name ]`. The default controller monitoring will give you per action monitoring of hits, response time and response size.

### Custom
If you want to have full control over your data sources, you can create so called templates in your application's `app/munin` directory. You have to create two files: `.config` and `.fetch`. For example:

    $ cat app/munin/things.config
    graph_title Things
    graph_category My Rails app
    graph_info Things your app knows about
    graph_vlabel count
    graph_args --base 1000 -l 0
    all.label all
    all.type GAUGE
    all.min 0

    $ cat app/munin/things.fetch
    all.value <%= Thing.count %>


## Running

You can now restart your Rails app, and Muninator will be listening on the specified port waiting for a connection from your Munin collector:

    $ sudo lsof -n | grep :4950
    ruby       6514      jnh    5u     IPv4    4002312       0t0        TCP *:4950 (LISTEN)

Getting Munin itself installed is beyond the scope of this article, and there are some pretty good docs on [Munin's site](http://munin-monitoring.org) to help you.  Debian/Ubuntu users can just `apt-get install munin` and it will take care of the bulk of the work for you.  The relevant parts of my `munin.conf` for mashd.cc look like this:

    $ cat /etc/munin/munin.conf
    [Rails;]
      use_node_name yes
   
    [Rails;mashd.cc]
      address 127.0.0.1
      port 4950

## Gotcha

The only other potential gotcha is that platforms like Passenger will shut down your rails apps if they don't have any hits for a while, leaving large blank patches in your graphs.  This might actually be desirable (especially on low memory environments), however I whipped up the following which I run in cron just before the `munin-update` job:

    awk '/^\[Rails\;(.+)\]$/{print gensub(/.*;(.+)]/,"wget -O /dev/null -q http://\\1","")}' /etc/munin/munin.conf  | sh

Another way is to run muninator as a standalone server. See Configuration above.

## Write your own plugins
If you wish to create your own Muninator plugin (or plugins) to monitor a specific part of your application then it's dead simple.  All you have to do is add a class to `Muninator::Commands` that implements `config()` and `fetch()` class methods which return strings in the [format expected by Munin](http://munin-monitoring.org/wiki/protocol-config). Take a look at the source for [Muninator's memory plugin](https://github.com/jamesotron/Muninator/blob/master/lib/muninator/commands/memory.rb) for about the simplest possible plugin.  If you plugin is even vaguely useful to others then please feel free to contribute it either by forking on Github and sending me a pull request, or just [hit me on twitter](http://www.twitter.com/jamesotron)

## License

This plugin is licensed under the terms of the Mozilla Public License version 1.1 or later and Copyright (c) 2010, 2011 James Harton.
