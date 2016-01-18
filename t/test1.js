var fs = require ('fs');
var content = fs.read ('local/map.txt');

require ('../kyuureki');

var resultLines = [];
content.split (/\u000D?\u000A/).forEach (function (line) {
  var m = line.match (/\t(-?\d+)-(\d+)('|)-(\d+)$/);
  if (m) {
    var result = Kyuureki.kyuurekiToGregorian
        (parseInt (m[1], 10), parseInt (m[2], 10),
         !!m[3], parseInt (m[4], 10));
    result.negative = result[0] < 0;
    if (result.negative) result[0] = -result[0];
    var line = (result.negative ? "-" : "") +
        (result[0] < 1000 ? "0" + result[0] : result[0]) + "-" +
        (result[1] < 10 ? "0" + result[1] : result[1]) + "-" +
        (result[2] < 10 ? "0" + result[2] : result[2]) + "\t" +
        m[1] + "-" + m[2] + m[3] + "-" + m[4] + "\n";
    resultLines.push (line);
  }
});

fs.write ('local/test1.out', resultLines.join (""));

phantom.exit ();