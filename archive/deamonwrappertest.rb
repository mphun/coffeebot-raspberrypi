#!/root/.rvm/rubies/ruby-2.0.0-p195/bin/ruby
require 'rubygems'
require 'daemons'

Daemons.run('/root/coffeebot/deamontestscript.rb')
#Daemons.run('/root/coffeebot/deamontestscript.rb boo')
#Daemons.run('/root/coffeebot/deamontestscript.rb mike')
#Daemons.run('/root/coffeebot/deamontestscript.rb phun')

