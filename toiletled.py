#!/usr/bin/python
# coding: utf8
import json, urllib2, sys, time

if len(sys.argv) <= 1:
    print 'Usage: python toiletled.py <url>'
    quit()
url = sys.argv[1]

floor2output = {'1':'D2','2':'D3','3':'D4','4':'D5','5':'D6','6':'HSHK'}

# http://wiki.linino.org/doku.php?id=wiki:lininoio_sysfs
def enable_digital_output(output):
    # cf. https://github.com/ideino/ideino-linino-lib/blob/master/utils/layouts/linino_one.json
    gpio_mapping = {'D8':'104','D9':'105','D10':'106','D11':'107','D5':'114',
        'D13':'115','D3':'116','D2':'117','D4':'120','D12':'122','D6':'123',
        'HSHK':'130'} # D7->HSHK
    with open('/sys/class/gpio/export', 'w') as f:
        f.write(gpio_mapping[output])
    with open('/sys/class/gpio/' + output + '/direction', 'w') as f:
        f.write('out')

def init():
    for output in floor2output.viewvalues():
        enable_digital_output(output)

def set_digital_out(output, value):
    '''Set value for digial out: '1' or '0'.'''
    with open('/sys/class/gpio/' + output + '/value', 'w') as f:
        f.write(value)

def onoff_floor_led(floor, onoff):
    set_digital_out(floor2output[floor], onoff)

def alloff_floor_led():
    for floor in floor2output:
        onoff_floor_led(floor, '0')

def fetchstatus():
    doorstatus = None
    try:
        r = None
        r = urllib2.urlopen(url)
        # {"6-1":"vacant","6-2":"engaged",...,"1-1":"unknown",...}
        doorstatus = json.loads(r.read())
    except Exception, err:
        print 'HTTP error: ', err
    finally:
        if r: r.close()
    return doorstatus

def onoffled(doorstatus):
    def everyengaged(x, y):
        if x == 'engaged':
            return y
        else:
            return x
    if doorstatus is None:
        alloff_floor_led()
        return
    # {"6":["vacant","engaged",...],...,"1":["unknown",...]}
    floorstatus = {'1':[],'2':[],'3':[],'4':[],'5':[],'6':[]}
    for door in doorstatus:
        floor = door.partition('-')[0]
        floorstatus[floor].append(doorstatus[door])
    floorengaged = {} # {"6":"engaged",...,"2":"vacant","1":"unknown"}
    for floor in floorstatus:
        floorengaged[floor] = reduce(everyengaged, floorstatus[floor])
    for floor in floorengaged:
        onoff_floor_led(floor, '1' if floorengaged[floor] == 'engaged' else '0')

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
