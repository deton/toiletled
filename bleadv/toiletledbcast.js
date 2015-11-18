var bleno = require('bleno');
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

bleno.on('stateChange', function(state) {
  console.log('on -> stateChange: ' + state);

  if (state !== 'poweredOn') {
    bleno.stopAdvertising();
  }
});

/*
bleno.on('advertisingStart', function() {
  console.log('on -> advertisingStart');
});
*/

/*
bleno.on('advertisingStop', function() {
  console.log('on -> advertisingStop');
});
*/

function sendBle(msg, cb) {
  //console.log(msg);
  if (bleno.state !== 'poweredOn') {
    cb('not poweredOn');
    return;
  }
  //bleno.stopAdvertising(function (err) {
    //if (err) {
      //cb(err);
      //return;
    //}
    var nameBuffer = new Buffer('toiLED'); // 'ToiletLED' is too long in 31 bytes.
    var nameDataLength = nameBuffer.length;
    var msgBuffer = new Buffer(msg);
    var msglen = msgBuffer.length;
    var manufacturerDataLength = 2 + msglen; // +2: company identifier
    var advertisementDataLength = 3 + 2+nameDataLength + 2+manufacturerDataLength;
    var advertisementData = new Buffer(advertisementDataLength);

    var i = 0;
    advertisementData.writeUInt8(2, i++); // length=2
    advertisementData.writeUInt8(0x01, i++); // type=Flags
    // 0x04(BR/EDR Not Supported) & 0x02(General Discoverable Mode)
    advertisementData.writeUInt8(0x06, i++);

    advertisementData.writeUInt8(nameDataLength + 1, i++); // +1: for type
    advertisementData.writeUInt8(0x08, i++); // type=Shortened Local Name
    //advertisementData.writeUInt8(0x09, i++); // type=Complete Local Name
    nameBuffer.copy(advertisementData, i);
    i += nameDataLength;

    advertisementData.writeUInt8(manufacturerDataLength + 1, i++);
    advertisementData.writeUInt8(0xff, i++); // type=Manufacturer Specific Data
    advertisementData.writeUInt16LE(0xffff, i); // company identifier for test
    i += 2;
    msgBuffer.copy(advertisementData, i);
    var scanData = new Buffer(0);
    bleno.startAdvertisingWithEIRData(advertisementData, scanData, function (err) {
      cb(err);
    });
  //});
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
  fetchToiletStatus(function (err, status) {
    if (err) {
      console.log('fetch error:' + err);
      sendBle(ALL_OFF, function (err) {
        if (err) {
          //console.log(err);
        }
        setTimeout(mainloop, 1000);
      });
    } else {
      sendBle(makeblemsg(status), function (err) {
        if (err) {
          //console.log(err);
        }
        setTimeout(mainloop, 2000);
      });
    }
  });
}

mainloop();
