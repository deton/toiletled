#!/usr/bin/python
# coding: utf8
import json, urllib2, sys, time, datetime, telnetlib

if len(sys.argv) <= 1:
    print 'Usage: python toiletled.py <url>'
    quit()
url = sys.argv[1]

# Linino ONE bridge to Arduino
tn = telnetlib.Telnet('localhost', 6571)

def onoff_floor_led(str):
    tn.write('\n' + str)

def alloff_floor_led():
    tn.write('\nuuuuuu')

def init():
    alloff_floor_led()

def fetchstatus():
    doorstatus = None
    try:
        r = None
        r = urllib2.urlopen(url)
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
    if doorstatus is None:
        alloff_floor_led()
        return
    # {"6":["vacant","engaged",...],...,"1":["unknown",...]}
    floorstatus = {'1':[],'2':[],'3':[],'4':[],'5':[],'6':[]}
    for door in doorstatus:
        floor = door.partition('-')[0]
        floorstatus[floor].append(doorstatus[door])
    # vacant count or 'u'(nknown) for floor 1-6. ex: 'uu4444'
    floorvacantstr = ''
    for floor in sorted(floorstatus.viewkeys()):
        floorvacant = reduce(countvacant, floorstatus[floor], 0)
        if floorvacant == 0 and 'unknown' in floorstatus[floor]:
            floorvacant = 'u'
        floorvacantstr += str(floorvacant)
    onoff_floor_led(floorvacantstr)

def main():
    init()
    try:
        while True:
            onoffled(fetchstatus())
            time.sleep(2)
    finally:
        alloff_floor_led()

if __name__ == "__main__":
    main()
