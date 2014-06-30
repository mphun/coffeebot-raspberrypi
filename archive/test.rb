#!/root/.rvm/rubies/ruby-2.0.0-p195/bin/ruby
require 'pi_piper'
require 'time'
require 'rest_client'
require 'logger'

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
   
def weakmap(value,sensor)
    if value <= 945
      return 0
    elsif value < 955 
      return 20 
    elsif value < 965 
      return 40 
    elsif value < 970
      return 60 
    elsif value < 975
      return 80 
    elsif value >= 975
      return 100 
    end    
end

def averagetime(pin)
  clock = PiPiper::Pin.new :pin => 18, :direction => :out
  adc_out = PiPiper::Pin.new :pin => 23
  adc_in = PiPiper::Pin.new :pin => 24, :direction => :out
  cs = PiPiper::Pin.new :pin => 25, :direction => :out
  
  time = []
  total = 0
  10.times do |t|
    weightvalue = read_adc(pin, clock, adc_in, adc_out, cs) 
  #  puts "averageing #{weightvalue}"
    time.push(weightvalue)
  end
  
  time.each do |t|
     total += t
  end
  
  return total/time.size

end

#MAIN
clock = PiPiper::Pin.new :pin => 18, :direction => :out
adc_out = PiPiper::Pin.new :pin => 23
adc_in = PiPiper::Pin.new :pin => 24, :direction => :out
cs = PiPiper::Pin.new :pin => 25, :direction => :out

debug = true
removetime = 0 
pot_removed = false 
prev_value = 0
ip = "localhost"
ip = '199.30.89.24'
#ip = '127.0.0.1'
port = 3000
port = 80

loop do
    value1 = averagetime(0)
    value2 = averagetime(1)
    value3 = averagetime(2)
    value4 = averagetime(3)
      
    puts "Value      = #{value1} #{value2} #{value3} #{value4}, #{Time.now}"
    #puts "percentage = "#{weakmap(value1,1)} #{weakmap(value2,2)} #{weakmap(value3,3)} #{weakmap(value4,4)}"
    puts "\%          = #{weakmap(value1,1)} #{weakmap(value2,2)} #{weakmap(value3,3)} #{weakmap(value4,4)}"
  sleep 1
end

