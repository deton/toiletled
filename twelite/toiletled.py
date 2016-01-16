#!/usr/bin/python
# coding: utf8
import json, urllib2, sys, time, datetime, serial

THISFLOOR = '3'
IGNOREFLOOR = '2' # XXX: no sensor at floor 2. always unknown
FLOOR_OFF    = '   ';
COLORSET_THISFLOOR =       {'GREEN': ')  ', 'YELLOW': ' ) ', 'RED': '  )'}
COLORSET_THISFLOOR_BLINK = {'GREEN': '!  ', 'YELLOW': ' ! ', 'RED': '  !'}
COLORSET_NORMAL =          {'GREEN': '*  ', 'YELLOW': ' * ', 'RED': '  *'}

if len(sys.argv) <= 1:
    print 'Usage: python toiletled.py <url>'
    quit()
url = sys.argv[1]

first_engaged_times = {}

# edison UART1
ser = serial.Serial('/dev/ttyMFD1', 115200)
# Linino ONE + ToCoStick
# ser = serial.Serial('/dev/ttyUSB0', 115200)

def onoff_floor_led(str):
    #print('t' + str + '\n')
    ser.write('t' + str + '\n')

def alloff_floor_led():
    #print('t' + FLOOR_OFF * 5 + '\n')
    ser.write('t' + FLOOR_OFF * 5 + '\n')

def sleep_floor_led(str):
    #print('s' + str + '\n')
    ser.write('s' + str + '\n')

def init():
    alloff_floor_led()

def fetchstatus():
    doorstatus = None
    try:
        r = None
        r = urllib2.urlopen(url, timeout=2)
        # {"6-1":"vacant","6-2":"engaged",...,"1-1":"unknown",...}
        doorstatus = json.loads(r.read())
    except Exception, err:
        print '{} HTTP error: {}'.format(datetime.datetime.now(), err)
        sys.stdout.flush()
    finally:
        if r: r.close()
    return doorstatus

def onoffled(doorstatus):
    def countvacant(n, x):
        if x == 'vacant':
            return n + 1
        else:
            return n
    now = time.time()
    # {"6":["vacant","engaged",...],...,"1":["unknown",...]}
    floorstatus = {'1':[],'2':[],'3':[],'4':[],'5':[],'6':[]}
    isAmbiguous = {}
    for door in doorstatus:
        floor = door.partition('-')[0]
        floorstatus[floor].append(doorstatus[door])
        # isAmbiguous
        if doorstatus[door] == 'engaged':
            if door not in first_engaged_times:
                first_engaged_times[door] = now
            else:
                # keep engaged 1 hour. sensor is broken? or battery is empty
                if now - first_engaged_times[door] > 3600:
                    isAmbiguous[floor] = True
        else:
            if door in first_engaged_times:
                del first_engaged_times[door]
    # vacant count or 'u'(nknown) for floor 1-6
    floorvacant = {}
    for floor in sorted(floorstatus.viewkeys()):
        if len(floorstatus[floor]) == 0:
            count = 'u'
        else:
            count = reduce(countvacant, floorstatus[floor], 0)
            if count == 0 and 'unknown' in floorstatus[floor]:
                count = 'u'
        floorvacant[floor] = count
    floorcolorstr = ''
    for floor in sorted(floorvacant.viewkeys()):
        if floor == IGNOREFLOOR: # XXX: no sensor at floor 2. always unknown
            continue
        floorcolorstr += decide_req_char(floorvacant[floor], floor, isAmbiguous.get(floor, False))
    onoff_floor_led(floorcolorstr)

def decide_req_char(vacant, floor, isAmbiguous):
    if isAmbiguous:
        return FLOOR_OFF
    if floor == THISFLOOR:
        colorset = COLORSET_THISFLOOR
    else:
        colorset = COLORSET_NORMAL
    if vacant == 0:
        return colorset['RED']
    elif vacant == 1:
        return colorset['YELLOW']
    elif vacant == 'u':
        return FLOOR_OFF
    else:
        return colorset['GREEN']

def main():
    init()
    try:
        while True:
            now = datetime.datetime.now()
            # for battery saving
            if now.hour >= 21 or now.hour < 8:
                if now.hour >= 21:
                    tomorrow = now + datetime.timedelta(days=1)
                    wakeup = tomorrow.replace(hour=8)
                else:
                    wakeup = now.replace(hour=8)
                sleepmin = (wakeup - now).seconds / 60
                sleep_floor_led(sleepmin)
                time.sleep(300) # 5 min
            else:
                doorstatus = fetchstatus()
                if doorstatus is None: # fetch failed
                    # Serial2Send app in TWE-Lite treats status as valid while 5[s]
                    #alloff_floor_led()
                    time.sleep(1)
                else:
                    onoffled(doorstatus)
                    time.sleep(2)
    finally:
        alloff_floor_led()
        ser.close()

if __name__ == "__main__":
    main()
