#!/root/.rvm/rubies/ruby-2.0.0-p195/bin/ruby
require 'wiringpi'

pin = 18

def map(x, in_min, in_max, out_min, out_max)
  return (x - in_min) * (out_max - out_min + 1 ) / (in_max - in_min + 1) + out_min
end

def RCtime(pin, io)
  reading = 0
  io.mode(pin,OUTPUT)
  io.write(pin,LOW)
  sleep(0.1)
  io.mode(pin,INPUT)
  
  while io.read(pin) == 0 and reading < 10000 do
    sleep(0.0000001)
    reading +=1
  end 
  return reading
end

def averagetime(pin,io)
time = []
total = 0  
10.times do |t|
  weightvalue =  RCtime(pin,io)
#  puts "averageing #{weightvalue}"
  time.push(weightvalue)
end

time.each do |t|
   total += t
end

return total/time.size

end


io = WiringPi::GPIO.new(WPI_MODE_GPIO)
puts "hi"

while true do
  weightvalue =  RCtime(pin,io)
  #weightvalue =  averagetime(pin,io)
 
  if weightvalue > 1220
    print "EMPTY"
  elsif weightvalue >= 210
    print map(weightvalue,210,1220,25,0).to_s + "%"
  elsif weightvalue >= 135 
    print map(weightvalue,135,210,50,25).to_s + "%"
  elsif weightvalue >= 90 
    print map(weightvalue,90,135,75,50).to_s + "%"
  elsif weightvalue >= 65 
    print map(weightvalue,65,90,100,75).to_s + "%"
  elsif weightvalue < 65 
    print "REALLY FULL!"
  end  
  
  puts ": actual value=#{weightvalue}"

end
