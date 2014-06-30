#!/root/.rvm/rubies/ruby-2.0.0-p195/bin/ruby
require 'pi_piper'
require 'time'
require 'rest_client'
require 'logger'
require 'fileutils'

class CoffeePot
  #@@ip = '199.30.89.24'
  @@ip = '54.202.13.4'
  @@port = 80
  @@debug = true 
  def initialize(sensornum)
    @sensor = sensornum
    @remove_time = 0
    @pot_removed = false
    @pumped = false
    @prev_value = 0
    @pump_time = 0
    @low_value = 0
    @high_value = 0
    @log = Logger.new("/var/log/coffeebot/sensor#{@sensor}.log", 5, 500000)
    @weight = Logger.new("/var/log/coffeebot/weight.log", 5, 500000)
  end


  def map(x, in_min, in_max, out_min, out_max)
    return (x - in_min) * (out_max - out_min + 1 ) / (in_max - in_min + 1) + out_min
  end

  def weakmap(value)
    if value <= 919
      return 0
    elsif value < 936
      return 20
    elsif value < 952
      return 40
    elsif value < 963
      return 60
    elsif value < 971
      return 80
    elsif value >= 971
      return 100
    end
  end

  def update(sensorvalue)
    
    if @prev_value == 0 and sensorvalue > 700
      puts "update weight value"
      @log.info "update weight value"
      weightvalue = weakmap(sensorvalue)
      RestClient.put "http://#{@@ip}:#{@@port}/api/brews/#{@sensor}", {"level" => weightvalue,"state" => "normal"}
      @prev_value = sensorvalue
      return
    end

    if (sensorvalue > (@prev_value + 10)) and (not @pot_removed) and (not @pumped) 
      puts "PUMP DETECTED for sensor #{@sensor}! sleeping 10 sec"
      @log.info "PUMP DETECTED for sensor #{@sensor}! sleeping 10 sec, value = #{sensorvalue}"
      @pumped = true
      @pump_time = Time.now + 10 
      RestClient.put "http://#{@@ip}:#{@@port}/api/brews/#{@sensor}", {"state" => "pumping"}
      if @high_value < 0
        puts "updating autocalibration" 
        @high_value = @prev_value
        @weight.info "low: #{@low_value} high: #{@high_value}"
      end
      return
    end

    if @pumped
      if (Time.now > @pump_time) 
        weightvalue = weakmap(sensorvalue)
        puts "after pump for sensor #{@sensor} \%value = #{weightvalue} actual val = #{sensorvalue}"
        @log.info "after pump for sensor #{@sensor} \%value = #{weightvalue} actual val = #{sensorvalue}"
        RestClient.put "http://#{@@ip}:#{@@port}/api/brews/#{@sensor}", {"level" => weightvalue,"state" => "normal"}
        @pumped = false
        @prev_value = sensorvalue
        return 
      end
   
      if sensorvalue  <= @prev_value+2
        puts "pumping released, sleeping for a second"       
        @log.info "pumping released, sleeping for a second"       
        @prev_value = -1
        @pump_time = Time.now + 1 
      else
        puts "in a pump state, sleeping"
        @log.info "in a pump state, sleeping"
        return
      end
      @prev_value = sensorvalue
      return 
    end
 
    if @pot_removed
      if sensorvalue > 700
        puts "pot detected for sensor #{@sensor}"
        @log.info "pot detected for sensor #{@sensor}"
        if Time.now > @remove_time + 60
        #if Time.now > @remove_time + 10
          weightvalue = weakmap(sensorvalue)
          puts "new pot of coffee added for sensor #{@sensor}! changing time stamp. value = 100"
          @log.info "new pot of coffee added for sensor #{@sensor}! changing time stamp. value = 100"
          @high_value = -1 
          RestClient.put "http://#{@@ip}:#{@@port}/api/brews/#{@sensor}", {"level" => 100,"filled_at" => Time.now,"state" => "normal"}
        else
          puts "pot has been added back too quickly not a new pot of coffee for sensor #{@sensor}"
          @log.info "pot has been added back too quickly not a new pot of coffee for sensor #{@sensor}"
          RestClient.put "http://#{@@ip}:#{@@port}/api/brews/#{@sensor}", {"level" => weightvalue,"state" => "normal"}
        end
        @pot_removed = false
        @prev_value = sensorvalue
        return
      end
    end

    if sensorvalue <= 700
      if not @pot_removed
        puts "pot removed for sensor #{@sensor}: updated level to -1"
        @log.info "pot removed for sensor #{@sensor}:  updated level to -1"
        RestClient.put "http://#{@@ip}:#{@@port}/api/brews/#{@sensor}", {"level" => 0,"state" => "removed"}
        @remove_time = Time.now
        puts @remove_time
        puts "new low=#{@prev_value}"
        @low_value = @prev_value
      end
      @pot_removed = true
    end
    if @@debug
      puts "Value#{@sensor} = #{sensorvalue}, #{Time.now}"
      @log.info "Value#{@sensor} = #{sensorvalue}"
    end
    @prev_value = sensorvalue
  end
 private:weakmap
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


#MAIN

if File.exist?("/var/log/coffeebot/coffee.lock")
   puts "lock file exist, exiting"
   exit 1
end

FileUtils.touch("/var/log/coffeebot/coffee.lock")

cb1 = CoffeePot.new(1)
cb2 = CoffeePot.new(2)
cb3 = CoffeePot.new(3)
cb4 = CoffeePot.new(4)

begin
loop do
  cb1.update(averagetime(0))
#  sleep 0.2
  cb2.update(averagetime(1))
#  sleep 0.2
  cb3.update(averagetime(2))
#  sleep 0.2
  cb4.update(averagetime(3))
#  sleep 0.2
end
rescue Exception => e
  puts "crash summary:"
  puts e
ensure
  FileUtils.rm("/var/log/coffeebot/coffee.lock")
end



