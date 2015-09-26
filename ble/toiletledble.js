var noble = require('noble');
var http = require('http');

var SERVERURL = process.argv[2] || 'http://192.168.179.6/~toilet/toilet.php';
var FLOOR_OFF    = '   ';
var FLOOR_GREEN  = '!  ';
var FLOOR_YELLOW = ' ! ';
var FLOOR_RED    = '  !';
var FLOOR_GREEN_BLINK  = '"  ';
var FLOOR_YELLOW_BLINK = ' " ';
var FLOOR_RED_BLINK    = '  "';
var ALL_OFF = '\n' + FLOOR_OFF + FLOOR_OFF + FLOOR_OFF + FLOOR_OFF + FLOOR_OFF;

var first_engaged_times = {};

// http://www.robotsfx.com/robot/img/radio/BLESerial/BLESerial_how5.html
var serviceUuid = '569a1101b87f490c92cb11ba5ea5167c'; // BLESerial
var characteristicUuid = '569a2001b87f490c92cb11ba5ea5167c'; // for write/send
var peripheralId = 'f924afcb99ae'; // my BLESerial device

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
  if (peripheral.id != peripheralId) {
    return;
  }
  noble.stopScanning();
  console.log('found peripheral:', peripheral.advertisement);
  peripheral.on('connect', function () {
    peripheral.discoverServices([serviceUuid], function (err, services) {
      services.forEach(function (service) {
        console.log('found service:', service.uuid);
        service.discoverCharacteristics([], function (err, characteristics) {
          characteristics.forEach(function (characteristic) {
            console.log('found characteristic:', characteristic.uuid);
            if (characteristicUuid == characteristic.uuid) {
              ledCharacteristic = characteristic;
            }
          });
          if (!ledCharacteristic) {
            console.log('missing characteristics');
          }
        });
      });
    });
  });
  peripheral.on('disconnect', function () {
    console.log('on disconnect');
    ledCharacteristic = null;
    noble.startScanning([serviceUuid], false);
  });
  peripheral.connect();
});

function sendBle(msg, cb) {
//  console.log(msg);
//  cb(null);
  var msgbuf = new Buffer(msg);
  if (ledCharacteristic === null) {
    cb('not connected');
  }
  ledCharacteristic.write(msgbuf, true, function (err) {
    if (err) {
      console.log('send error:' + err);
      cb(err);
    }
    console.log('write:' + msgbuf);
    cb(null);
  });
}

function makeblemsg(doorstatus) {
  function countvacant(n, x) {
    return (x == 'vacant') ? n + 1 : n;
  }
  // {"6":["vacant","engaged",...],...,"1":["unknown",...]}
  var floorstatus = {'1':[],'2':[],'3':[],'4':[],'5':[],'6':[]};
  var blinkflag = {};
  var now = Date.now();
  for (var door in doorstatus) {
    var floor = door[0];
    floorstatus[floor].push(doorstatus[door]);
    // blinkflag
    if (doorstatus[door] == 'engaged') {
      if (!(door in first_engaged_times)) {
        first_engaged_times[door] = now;
      } else {
        // keep engaged 1 hour. sensor is broken? or battery is empty
        if (now - first_engaged_times[door] > 3600000) {
          blinkflag[floor] = true;
        }
      }
    } else {
      if (door in first_engaged_times) {
        delete first_engaged_times[door];
      }
    }
  }
  // vacant count or 'u'(nknown) for floor 1-6
  floorvacant = {};
  for (var floor in floorstatus) {
    var count = floorstatus[floor].reduce(countvacant, 0);
    if (count == 0 && floorstatus[floor].indexOf('unknown') >= 0) {
      count = 'u';
    }
    floorvacant[floor] = count;
  }
  var blemsg = '\n'; // begin mark
  for (var floor = 1; floor <= 6; floor++) {
    if (floor == 2) { // XXX: no sensor at floor 2. always unknown
      continue;
    }
    if (floorvacant[floor] == 0) {
      blemsg += blinkflag[floor] ? FLOOR_RED_BLINK : FLOOR_RED;
    } else if (floorvacant[floor] == 1) {
      blemsg += blinkflag[floor] ? FLOOR_YELLOW_BLINK : FLOOR_YELLOW;
    } else if (floorvacant[floor] == 'u') {
      blemsg += FLOOR_OFF;
    } else {
      blemsg += blinkflag[floor] ? FLOOR_GREEN_BLINK : FLOOR_GREEN;
    }
  }
  return blemsg;
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
    req.abort(); // triggers 'error' event. 'Error: socket hang up'
  })
  req.setTimeout(5000);
}

function mainloop() {
  if (ledCharacteristic !== null) {
    fetchToiletStatus(function (err, status) {
      if (err) {
        console.log('fetch toilet status error:' + err);
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
