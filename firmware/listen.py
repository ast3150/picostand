import serial, sys, time
port = sys.argv[1] if len(sys.argv) > 1 else '/dev/tty.usbmodem1301'
secs = float(sys.argv[2]) if len(sys.argv) > 2 else 15.0
s = serial.Serial(port, 115200, timeout=0.5)
end = time.time() + secs
while time.time() < end:
    line = s.readline()
    if line:
        print(line.decode(errors='replace').rstrip())
        sys.stdout.flush()
