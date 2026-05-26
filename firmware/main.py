import sys, json, time, select
from machine import I2C, Pin

# --- config (overridable via "cfg" cmd from Mac) ---
SIT_MM   = 633         # calibrated
STAND_MM = 937         # calibrated
SAMPLE_HZ = 2
DEBOUNCE_N = 3
HB_SEC = 10
SANITY_MIN, SANITY_MAX = 300, 1500
BUF_MAX = 50

I2C_ADDR = 0x57
i2c = I2C(0, sda=Pin(0), scl=Pin(1), freq=100_000)

def read_distance_mm():
    try:
        i2c.writeto(I2C_ADDR, b'\x01')
        time.sleep_ms(120)
        b = i2c.readfrom(I2C_ADDR, 3)
        return ((b[0] << 16) | (b[1] << 8) | b[2]) // 1000
    except OSError:
        return None

state = "unknown"
pending = None
pending_count = 0
seq = 0
buf = []
cal_mode = False
last_hb_ms = 0
last_d = 0

def emit(obj):
    print(json.dumps(obj))

def classify(d):
    mid = (SIT_MM + STAND_MM) / 2
    band = (STAND_MM - SIT_MM) * 0.2
    if d > mid + band: return "standing"
    if d < mid - band: return "sitting"
    return None

def step(d):
    global state, pending, pending_count, seq
    if d is None or not (SANITY_MIN <= d <= SANITY_MAX):
        return
    cand = classify(d)
    if cand is None or cand == state:
        pending, pending_count = None, 0
        return
    if cand != pending:
        pending, pending_count = cand, 1
    else:
        pending_count += 1
    if pending_count >= DEBOUNCE_N:
        state = pending
        pending, pending_count = None, 0
        seq += 1
        ev = {"t":"tx","state":state,"d":d,"seq":seq}
        buf.append(ev)
        if len(buf) > BUF_MAX: buf.pop(0)
        emit(ev)

def handle_cmd(line):
    global SIT_MM, STAND_MM, cal_mode, buf
    try:
        msg = json.loads(line)
    except Exception:
        return
    c = msg.get("cmd")
    if c == "cfg":
        SIT_MM = int(msg.get("sit", SIT_MM))
        STAND_MM = int(msg.get("stand", STAND_MM))
        emit({"t":"cfg_ok","sit":SIT_MM,"stand":STAND_MM})
    elif c == "cal":
        cal_mode = bool(msg.get("on", False))
        emit({"t":"cal_ok","on":cal_mode})
    elif c == "ack":
        n = int(msg.get("seq", 0))
        buf = [e for e in buf if e["seq"] > n]
    elif c == "replay":
        for e in buf: emit(e)

emit({"t":"hello","fw":"0.1","sit":SIT_MM,"stand":STAND_MM})

poll = select.poll()
poll.register(sys.stdin, select.POLLIN)
period_ms = 1000 // SAMPLE_HZ

while True:
    t0 = time.ticks_ms()

    while poll.poll(0):
        line = sys.stdin.readline()
        if line: handle_cmd(line.strip())

    d = read_distance_mm()
    if d is not None: last_d = d
    if cal_mode and d is not None:
        emit({"t":"raw","d":d})
    else:
        step(d)

    now = time.ticks_ms()
    if time.ticks_diff(now, last_hb_ms) >= HB_SEC * 1000:
        emit({"t":"hb","state":state,"d":last_d,"seq":seq})
        last_hb_ms = now

    elapsed = time.ticks_diff(time.ticks_ms(), t0)
    time.sleep_ms(max(0, period_ms - elapsed))
