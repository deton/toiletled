#!/usr/bin/python
# coding: utf8
import json, urllib2, sys, time, datetime, telnetlib

THISFLOOR = '5'
RGBOFF = '000000'
COLORSET_THISFLOOR = {
    'RED': 'ff0000', 'YELLOW': 'ffff00', 'BLUE': '0000ff', 'OFF': '000000'
}
COLORSET_BRIGHT = {
    'RED': '500000', 'YELLOW': '505000', 'BLUE': '000050', 'OFF': '000000'
}
COLORSET_NORMAL = {
    'RED': '2a0000', 'YELLOW': '2a2a00', 'BLUE': '00002a', 'OFF': '000000'
}

if len(sys.argv) <= 1:
    print 'Usage: python toiletled.py <url>'
    quit()
url = sys.argv[1]

first_engaged_times = {}

# Linino ONE bridge to Arduino
tn = telnetlib.Telnet('localhost', 6571)

def onoff_floor_led(str):
    tn.write('\n' + str)

def alloff_floor_led():
    tn.write('\n' + RGBOFF * 6)

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
    blinkflag = {}
    for door in doorstatus:
        floor = door.partition('-')[0]
        floorstatus[floor].append(doorstatus[door])
        # blinkflag
        if doorstatus[door] == 'engaged':
            if door not in first_engaged_times:
                first_engaged_times[door] = now
            else:
                # keep engaged 1 hour. sensor is broken? or battery is empty
                if now - first_engaged_times[door] > 3600:
                    blinkflag[floor] = True
        else:
            if door in first_engaged_times:
                del first_engaged_times[door]
    # vacant count or 'u'(nknown) for floor 1-6
    floorvacant = {}
    for floor in sorted(floorstatus.viewkeys()):
        count = reduce(countvacant, floorstatus[floor], 0)
        if count == 0 and 'unknown' in floorstatus[floor]:
            count = 'u'
        floorvacant[floor] = count
    # rgb color for each floor.
    if floorvacant[THISFLOOR] == 0 or floorvacant[THISFLOOR] == 'u':
        colorsetother = COLORSET_BRIGHT
    else:
        colorsetother = COLORSET_NORMAL
    floorcolorstr = ''
    for floor in sorted(floorvacant.viewkeys()):
        if blinkflag.get(floor, False):
            floorcolorstr += 'T' # tenTou
        else:
            floorcolorstr += 'M' # tenMetu
        if floorvacant[floor] == 0:
            c = 'RED'
        elif floorvacant[floor] == 1:
            c = 'YELLOW'
        elif floorvacant[floor] == 'u':
            c = 'OFF'
        else:
            c = 'BLUE'
        if floor == THISFLOOR:
            floorcolorstr += COLORSET_THISFLOOR[c]
        else:
            floorcolorstr += colorsetother[c]
    onoff_floor_led(floorcolorstr)

def main():
    init()
    try:
        while True:
            doorstatus = fetchstatus()
            if doorstatus is None: # fetch failed
                alloff_floor_led()
                time.sleep(1)
            else:
                onoffled(doorstatus)
                time.sleep(2)
    finally:
        alloff_floor_led()

if __name__ == "__main__":
    main()
