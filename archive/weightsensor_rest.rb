#!/root/.rvm/rubies/ruby-2.0.0-p195/bin/ruby
require 'pi_piper'
require 'time'
require 'rest_client'
require 'logger'
require 'fileutils'

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
  
  loop do
    if not File.exist?("/tmp/sensor.lock")    
      break;
    end
    randomsleep = (Random.rand(10)+1).to_f
    randomsleep = 1/randomsleep
    sleep(randomsleep)
  end
  FileUtils.touch('/tmp/sensor.lock')

  time = []
  total = 0
  5.times do |t|
    weightvalue = read_adc(pin, clock, adc_in, adc_out, cs) 
#   puts "    averageing #{weightvalue}"
    time.push(weightvalue)
    sleep(0.1) 
  end
  
  time.each do |t|
     total += t
  end
  
  File.delete("/tmp/sensor.lock") if File.exist?("/tmp/sensor.lock")
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
#port = 3000
port = 80
sensor = ARGV[0].to_i
log = Logger.new("/var/log/coffeebot/sensor#{sensor}.log", 5, 500000)
#`touch /tmp/sensor.lock`
File.delete("/tmp/sensor.lock") if File.exist?("/tmp/sensor.lock")
loop do
    #sensorvalue = read_adc((sensor - 1), clock, adc_in, adc_out, cs)
    sensorvalue = averagetime(sensor -1)

  if (sensorvalue > (prev_value + 20)) and (not pot_removed)
    puts "PUMP DETECTED! sleeping 10 sec, value = #{sensorvalue}"
    log.info "PUMP DETECTED! sleeping 10 sec, value = #{sensorvalue}"
    sleep 10
    #sensorvalue = read_adc((sensor - 1), clock, adc_in, adc_out, cs)
    sensorvalue = read_adc((sensor - 1), clock, adc_in, adc_out, cs)
    weightvalue = weakmap(sensorvalue)
    puts "after pump \%value = #{weightvalue} actual val = #{sensorvalue}"
    log.info "after pump \%value = #{weightvalue} actual val = #{sensorvalue}"
    RestClient.put "http://#{ip}:#{port}/api/brews/#{sensor}", {"level" => weightvalue} 
  end

  if pot_removed
    if sensorvalue > 700
      puts "pot detected!@#@!#"
      pot_removed = false
      weightvalue = weakmap(sensorvalue)
      #puts weightvalue
      #log.info weightvalue
      if Time.now > removetime + 120
        puts "new pot of coffee added! changing time stamp. value = #{weightvalue}"
        log.info "new pot of coffee added! changing time stamp. value = #{weightvalue}"
        RestClient.put "http://#{ip}:#{port}/api/brews/#{sensor}", {"level" => weightvalue,"filled_at" => Time.now}
      else
        puts "pot has been added back too quickly not a new pot of coffee"
        log.info "pot has been added back too quickly not a new pot of coffee"
        RestClient.put "http://#{ip}:#{port}/api/brews/#{sensor}", {"level" => weightvalue}
      end 
    end
  end

    #testing
  if sensorvalue <= 200
    #puts "pot removed"
    #log.info "pot removed"
    if not pot_removed
      puts "pot removed: updated level to -1"
      log.info "pot removed:  updated level to -1"
      RestClient.put "http://#{ip}:#{port}/api/brews/#{sensor}", {"level" => -1} 
      removetime = Time.now
      puts removetime
    end
    pot_removed = true 
  end    

  if debug
    puts "Value = #{sensorvalue}, #{Time.now}"
    log.info "Value = #{sensorvalue}"
  end
  prev_value =sensorvalue 
  sleep(0.5)
end

