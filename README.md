Briak
=====

Briak is a Sinatra-based web front-end browser for the ultra-cool distributed NoSQL database Riak from [Basho](http://www.basho.com).

QUICK START
===========

You will need Ruby 1.8.7, and the following gems:

    gem install sinatra ripple
    
Clone the git repo

    git clone http://github.com/johnthethird/Briak.git briak
    cd briak
    ruby briak.rb

Surf to the Briak URL

    http://127.0.0.1:4567
    
Enter the host and port for your Riak cluster/node, and click the Connect button.

Click the `edit` link in the Buckets section, and enter a space-separated list of bucket names you would like to browse, and click `Save`.

Use the Buckets drop-down to select the Bucket to browse, and the keys will populate the Keys section. Clicking on any key will show you the contents of that key. 

GOTCHAS
=======
You dont need to run Briak on the same machine as your Riak node, but make sure the Riak node is set to bind to a real IP instead of localhost. Basically this involves modifying `riak_web_ip` in `etc/app.config` in your Riak directory.
    
If you have lots of keys (tens of thousands) in a bucket, Briak will try to list them all, which could be problematic.

I whipped this up so I could visualize what is going on inside Riak as I am learning about it, and hopefully others will find it useful as well.
