#!/root/.rvm/rubies/ruby-2.0.0-p195/bin/ruby
require 'rubygems'
require 'logger'

log= Logger.new('/var/log/coffeebot/deamon.log', 5, 500000)

msg = ARGV[0]
#msg = "blah1" 


loop do
  puts msg 
  log.info msg 
  sleep(5)
end
