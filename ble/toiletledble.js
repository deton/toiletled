var noble = require('noble');
var http = require('http');

var SERVERURL = process.argv[2] || 'http://192.168.179.2:8000/toilet.json';
var THISFLOOR = '5';
var IGNOREFLOOR = '2'; // XXX: no sensor at floor 2. always unknown
var FLOOR_OFF    = '   ';
var FLOOR_GREEN  = '*  ';
var FLOOR_YELLOW = ' * ';
var FLOOR_RED    = '  *';
var THISFLOOR_GREEN  = ')  ';
var THISFLOOR_YELLOW = ' ) ';
var THISFLOOR_RED    = '  )';
var FLOOR_GREEN_BLINK  = '!  ';
var FLOOR_YELLOW_BLINK = ' ! ';
var FLOOR_RED_BLINK    = '  !';
var ALL_OFF = FLOOR_OFF + FLOOR_OFF + FLOOR_OFF + FLOOR_OFF + FLOOR_OFF;

var firstEngagedTimes = {};

var serviceUuid = 'a55087fdad764aa0b0fb5fcf807c1273'; // toiletled
var characteristicUuid = '9a9c37867a31402aa79d8f53a083f384';

noble.on('stateChange', function (state) {
  if (state === 'poweredOn') {
    console.log('scanning...');
    noble.startScanning([serviceUuid], false);
  } else {
    noble.stopScanning();
  }
});

var ledCharacteristic = null;

noble.on('discover', function (peripheral) {
  noble.stopScanning();
  console.log('found peripheral:', peripheral.advertisement);
  peripheral.once('connect', function onConnect() {
    peripheral.discoverServices([serviceUuid], function (err, services) {
      if (err) {
        console.log('discoverService error:', err);
        peripheral.disconnect();
        return;
      }
      serviceLoop(0);
      function serviceLoop(idx) {
        if (idx >= services.length) {
          if (!ledCharacteristic) {
            console.log('missing characteristics');
            peripheral.disconnect();
          }
          return;
        }
        var service = services[idx];
        console.log('found service:', service.uuid);
	var timer = setTimeout(function () {
          console.log('discoverCharacteristics timeout');
          serviceLoop(idx + 1);
        }, 60000);
        service.discoverCharacteristics([], function (err, characteristics) {
          if (err) {
            clearTimeout(timer);
            console.log('discoverCharacteristics error:', err);
            serviceLoop(idx + 1);
            return;
          }
          characteristics.forEach(function (characteristic) {
            console.log('found characteristic:', characteristic.uuid);
            if (characteristicUuid == characteristic.uuid) {
              ledCharacteristic = characteristic;
            }
          });
          clearTimeout(timer);
          serviceLoop(idx + 1);
        });
      }
    });
  });
  peripheral.once('disconnect', function () {
    console.log('on disconnect');
    ledCharacteristic = null;
    noble.startScanning([serviceUuid], false);
  });
  peripheral.connect();
});

function sendBle(msg, cb) {
  var msgbuf = new Buffer(msg);
  if (ledCharacteristic === null) {
    cb('not connected');
    return;
  }
  ledCharacteristic.write(msgbuf, true, function (err) {
    if (err) {
      console.log('send error:' + err);
      cb(err);
      return;
    }
    console.log('write:' + msgbuf);
    cb(null);
  });
}

function makeblemsg(doorStatus) {
  function countVacant(n, x) {
    return (x == 'vacant') ? n + 1 : n;
  }
  // {"6":["vacant","engaged",...],...,"1":["unknown",...]}
  var floorStatus = {'1':[],'2':[],'3':[],'4':[],'5':[],'6':[]};
  var isAmbiguous = {};
  var now = Date.now();
  for (var door in doorStatus) {
    var floor = door[0];
    floorStatus[floor].push(doorStatus[door]);
    // isAmbiguous
    if (doorStatus[door] == 'engaged') {
      if (!(door in firstEngagedTimes)) {
        firstEngagedTimes[door] = now;
      } else {
        // keep engaged 1 hour. sensor is broken? or battery is empty
        if (now - firstEngagedTimes[door] > 3600000) {
          isAmbiguous[floor] = true;
        }
      }
    } else {
      if (door in firstEngagedTimes) {
        delete firstEngagedTimes[door];
      }
    }
  }
  // vacant count or 'u'(nknown) for floor 1-6
  var floorVacant = {};
  for (var floor in floorStatus) {
    var count = floorStatus[floor].reduce(countVacant, 0);
    if (count == 0 && floorStatus[floor].indexOf('unknown') >= 0) {
      count = 'u';
    }
    floorVacant[floor] = count;
  }
  var blemsg = '';
  for (var floor = '1'; floor <= '6'; floor++) {
    if (floor == IGNOREFLOOR) { // XXX: no sensor at floor 2. always unknown
      continue;
    }
    blemsg += decideReqChar(floorVacant[floor], floor, isAmbiguous[floor]);
  }
  return blemsg;
}

function decideReqChar(vacant, floor, isAmbiguous) {
  if (vacant == 0) {
    return (floor != THISFLOOR) ? FLOOR_RED : isAmbiguous ? FLOOR_RED_BLINK : THISFLOOR_RED;
  } else if (vacant == 1) {
    return (floor != THISFLOOR) ? FLOOR_YELLOW : isAmbiguous ? FLOOR_YELLOW_BLINK : THISFLOOR_YELLOW;
  } else if (vacant == 'u') {
    return FLOOR_OFF;
  } else {
    return (floor != THISFLOOR) ? FLOOR_GREEN : isAmbiguous ? FLOOR_GREEN_BLINK : THISFLOOR_GREEN;
  }
}

function fetchToiletStatus(cb) {
  var req = http.get(SERVERURL, function (res) {
    res.setEncoding('utf8');
    var respBody = '';
    res.on('data', function (chunk) {
      respBody += chunk;
    });
    res.on('end', function () {
      cb(null, JSON.parse(respBody));
    });
  });
  req.on('error', function (e) {
    cb(e);
  });
  req.on('timeout', function () {
    console.log('fetch timeout');
    req.abort(); // triggers 'error' event. 'Error: socket hang up'
  })
  req.setTimeout(5000);
}

function mainloop() {
  if (ledCharacteristic !== null) {
    fetchToiletStatus(function (err, status) {
      if (err) {
        console.log('fetch error:' + err);
        sendBle(ALL_OFF, function () {
          setTimeout(mainloop, 1000);
        });
      } else {
        sendBle(makeblemsg(status), function () {
          setTimeout(mainloop, 2000);
        });
      }
    });
  } else {
    setTimeout(mainloop, 2000);
  }
}

mainloop();
