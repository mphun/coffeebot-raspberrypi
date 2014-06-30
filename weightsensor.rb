#!/root/.rvm/rubies/ruby-2.0.0-p195/bin/ruby
require 'pi_piper'
require 'time'
require 'rest_client'
require 'logger'

#port of the Adafruit MCP3008 interface code found @ http://learn.adafruit.com/send-raspberry-pi-data-to-cosm/python-script

$sensorvalue1 = 0
$sensorvalue2 = 0
$sensorvalue3 = 0
$sensorvalue4 = 0

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

def averagetime(pin)
  clock = PiPiper::Pin.new :pin => 18, :direction => :out
  adc_out = PiPiper::Pin.new :pin => 23
  adc_in = PiPiper::Pin.new :pin => 24, :direction => :out
  cs = PiPiper::Pin.new :pin => 25, :direction => :out
  
  time = []
  total = 0
  10.times do |t|
    weightvalue = read_adc(pin, clock, adc_in, adc_out, cs) 
    #puts "   averageing #{weightvalue}"
    time.push(weightvalue)
  end
  
  time.each do |t|
     total += t
  end
  
  return total/time.size

end

def coffeecheck(sensor)
  debug = true
  removetime = 0 
  pot_removed = false 
  prev_value = 0
  #ip = "localhost"
  ip = '199.30.89.24'
  #ip = '172.16.72.73'
  #ip = '127.0.0.1'
  #port = 3000
  port = 80
  log = Logger.new("/var/log/coffeebot/sensor#{sensor}.log", 5, 500000)
  loop do
    case sensor
      when 1
        sensorvalue = $sensorvalue1
      when 2
        sensorvalue = $sensorvalue2
      when 3
        sensorvalue = $sensorvalue3
      when 4
        sensorvalue = $sensorvalue4
    end    
 
    if (sensorvalue > (prev_value + 10)) and (not pot_removed)
      puts "PUMP DETECTED for sensor #{sensor}! sleeping 10 sec"
      log.info "PUMP DETECTED for sensor #{sensor}! sleeping 10 sec, value = #{sensorvalue}"
      weightvalue = weakmap(prev_value)
      RestClient.put "http://#{ip}:#{port}/api/brews/#{sensor}", {"state" => "pumping"}
      sleep 5

      case sensor
        when 1
          sensorvalue = $sensorvalue1
        when 2
          sensorvalue = $sensorvalue2
        when 3
          sensorvalue = $sensorvalue3
        when 4
          sensorvalue = $sensorvalue4
      end    

      weightvalue = weakmap(sensorvalue)
      puts "after pump for sensor #{sensor} \%value = #{weightvalue} actual val = #{sensorvalue}"
      log.info "after pump for sensor #{sensor} \%value = #{weightvalue} actual val = #{sensorvalue}"
      #RestClient.put "http://#{ip}:#{port}/api/brews/#{sensor}", {"state" => "normal"}
      RestClient.put "http://#{ip}:#{port}/api/brews/#{sensor}", {"level" => weightvalue,"state" => "normal"}
    end
  
    if pot_removed
      if sensorvalue > 700
        puts "pot detected for sensor #{sensor}"
        log.info "pot detected for sensor #{sensor}"
        pot_removed = false
        weightvalue = weakmap(sensorvalue)
        #puts weightvalue
        #log.info weightvalue
        if Time.now > removetime + 120
          puts "new pot of coffee added for sensor #{sensor}! changing time stamp. value = #{weightvalue}"
          log.info "new pot of coffee added for sensor #{sensor}! changing time stamp. value = #{weightvalue}"
          RestClient.put "http://#{ip}:#{port}/api/brews/#{sensor}", {"level" => weightvalue,"filled_at" => Time.now}
        else
          puts "pot has been added back too quickly not a new pot of coffee for sensor #{sensor}"
          log.info "pot has been added back too quickly not a new pot of coffee for sensor #{sensor}"
          RestClient.put "http://#{ip}:#{port}/api/brews/#{sensor}", {"level" => weightvalue}
        end
      end
    end
  
      #testing
    if sensorvalue <= 200
      #puts "pot removed"
      #log.info "pot removed"
      if not pot_removed
        puts "pot removed for sensor #{sensor}: updating state to removed"
        log.info "pot removed for sensor #{sensor}:  updating state to removed"
        RestClient.put "http://#{ip}:#{port}/api/brews/#{sensor}", {"level" => 0,"state" => "removed"}
        removetime = Time.now
        puts removetime
      end
      pot_removed = true
    end
  
    if debug
      puts "Value#{sensor} = #{sensorvalue}, #{Time.now}"
      log.info "Value#{sensor} = #{sensorvalue}"
    end
    prev_value =sensorvalue
    sleep 1
  end
end


#MAIN
#clock = PiPiper::Pin.new :pin => 18, :direction => :out
#adc_out = PiPiper::Pin.new :pin => 23
#adc_in = PiPiper::Pin.new :pin => 24, :direction => :out
#cs = PiPiper::Pin.new :pin => 25, :direction => :out

#debug = true
#removetime = 0 
#pot_removed = false 
#prev_value = 0
#ip = "localhost"
#ip = '199.30.89.24'
##ip = '127.0.0.1'
#port = 3000
#port = 80
#sensor = ARGV[0].to_i
#log = Logger.new("/var/log/coffeebot/sensor#{sensor}.log", 5, 500000)

Thread.new do
loop do
    $sensorvalue1 = averagetime(0)
    sleep 0.2 
    $sensorvalue2 = averagetime(1) 
    sleep 0.2 
    $sensorvalue3 = averagetime(2) 
    sleep 0.2 
    $sensorvalue4 = averagetime(3)
    sleep 0.2 
    #puts "#{$sensorvalue1} #{$sensorvalue2} #{$sensorvalue3} #{$sensorvalue4}"
end
end

Thread.new do
  coffeecheck(1)
end

Thread.new do
  coffeecheck(2)
end

Thread.new do
  coffeecheck(3)
end

coffeecheck(4)

