#!/root/.rvm/rubies/ruby-2.0.0-p195/bin/ruby
require 'pi_piper'
require 'time'
require 'json'
#port of the Adafruit MCP3008 interface code found @ http://learn.adafruit.com/send-raspberry-pi-data-to-cosm/python-script

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
    
clock = PiPiper::Pin.new :pin => 18, :direction => :out
adc_out = PiPiper::Pin.new :pin => 23
adc_in = PiPiper::Pin.new :pin => 24, :direction => :out
cs = PiPiper::Pin.new :pin => 25, :direction => :out

adc_pin = 0

loop do
    #value = read_adc(adc_pin, clock, adc_in, adc_out, cs)
    value0 = read_adc(0, clock, adc_in, adc_out, cs)
    value1 = read_adc(1, clock, adc_in, adc_out, cs)
    value2 = read_adc(2, clock, adc_in, adc_out, cs)
    value3 = read_adc(3, clock, adc_in, adc_out, cs)
    
    #mvolts = value * (3300.0 / 1023.0)
    #puts "Value = #{value}, mvolts = #{mvolts} #{Time.now}"
    puts "Value = #{value0} #{value1} #{value2} #{value3}, #{Time.now}"
    data = "{\"brew_type\":\"French Roast\",\"level\":#{value0}}"
    puts data
    `curl -X PUT -H "Content-Type: application/json" -d '{"brew_type":"French Roast","level":#{value0}}' http://172.16.72.73:3000/api/brews/23423259`
    `curl -X PUT -H "Content-Type: application/json" -d '{"brew_type":"Mocha","level":#{value1}}' http://172.16.72.73:3000/api/brews/23423249`
    `curl -X PUT -H "Content-Type: application/json" -d '{"brew_type":"Columbia","level":#{value2}}' http://172.16.72.73:3000/api/brews/23423250`
    sleep 5
end

