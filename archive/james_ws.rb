#!/root/.rvm/rubies/ruby-2.0.0-p195/bin/ruby
require 'wiringpi'

pin = 18
#pin = 17
#pin = 23
#pin = 24

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
    reading +=1
  end 
  return reading
end

io = WiringPi::GPIO.new(WPI_MODE_GPIO)
puts "hi"
time = []

while true do
  total=0
  weightvalue =  RCtime(pin,io)
  time.push(weightvalue)

  if time.size > 20
    time.shift
  end
  
  time.each do |t|
#    puts "averaging: #{t}"
    total +=t
  end
  weightvalue = total/time.size

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
