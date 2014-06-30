#!/root/.rvm/rubies/ruby-2.0.0-p195/bin/ruby
require 'pi_piper'
require 'time'
require 'json'
require 'net/https'
require 'uri'

#port of the Adafruit MCP3008 interface code found @ http://learn.adafruit.com/send-raspberry-pi-data-to-cosm/python-script

def map(x, in_min, in_max, out_min, out_max)
  return (x - in_min) * (out_max - out_min + 1 ) / (in_max - in_min + 1) + out_min
end

def read_adc(adc_pin, clockpin, adc_in, adc_out, cspin)
  cspin.on
  clockpin.off
  cspin.off
  
  command_out = adc_pin
  command_out |= 0x18
  command_out <<= 3

    (0..4).each do
        adc_in.update_value((command_out & 0x80) > 0)
        command_out <<= 1
        clockpin.on
        clockpin.off
    end
    result = 0

    (0..11).each do
        clockpin.on
        clockpin.off
        result <<= 1
        adc_out.read
        if adc_out.on?
            result |= 0x1
        end
    end 

    cspin.on

    result >> 1
end
   
def weakmap(value)

  if value <= 940
    return 0
  elsif value < 960 
    return 25 
  elsif value < 975
    return 50 
  elsif value < 985
    return 75 
  elsif value >= 985
    return 100 
  end    

end

#MAIN
clock = PiPiper::Pin.new :pin => 18, :direction => :out
adc_out = PiPiper::Pin.new :pin => 23
adc_in = PiPiper::Pin.new :pin => 24, :direction => :out
cs = PiPiper::Pin.new :pin => 25, :direction => :out

pot_removed = false 
prev_value = 0
ip = "localhost"
sensor = ARGV[0].to_i

# Set up our HTTP object with the required host and path
url = URI.parse("http://#{ip}:3000/api/brews/")
headers = { "Content-Type" => 'application/json' }
http = Net::HTTP.new(url.host, url.port)


loop do
    sensorvalue = read_adc((sensor - 1), clock, adc_in, adc_out, cs)
   
  if (sensorvalue > (prev_value + 10)) and (not pot_removed)
    puts "PUMP DETECTED!"
    sleep 10
    sensorvalue = read_adc((sensor - 1), clock, adc_in, adc_out, cs)
    weightvalue = weakmap(sensorvalue)
    puts weightvalue
    data = {"brew_type" => "French Roast","level" => weightvalue}
    url = URI.parse("http://#{ip}:3000/api/brews/#{sensor}")
    http.put(url.path, data.to_json, headers)
  end

  if pot_removed 
    if sensorvalue > 700
      puts "new pot of coffee added! changing time stamp"
      pot_removed = false
      weightvalue = weakmap(sensorvalue)
      puts weightvalue
      data = {"brew_type" => "French Roast","level" => weightvalue,"filled_at" => Time.now}
      url = URI.parse("http://#{ip}:3000/api/brews/#{sensor}")
      http.put(url.path, data.to_json, headers)
    end
  end

    #testing
  if sensorvalue <= 200
    print "pot removed"
    if not pot_removed
      puts " updated level to -1"
      data = {"brew_type" => "French Roast","level" => -1}
      url = URI.parse("http://#{ip}:3000/api/brews/#{sensor}")
      http.put(url.path, data.to_json, headers)
    end
    pot_removed = true 
  end    
  print "\n"

  puts "Value = #{sensorvalue}, #{Time.now}"

  prev_value =sensorvalue 
  sleep 1
end

