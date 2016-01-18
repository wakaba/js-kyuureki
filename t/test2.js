var fs = require ('fs');
var content = fs.read ('local/map.txt');

require ('../kyuureki');

var resultLines = [];
content.split (/\u000D?\u000A/).forEach (function (line) {
  var m = line.match (/^(-?\d+)-(\d+)-(\d+)\t/);
  if (m) {
    var result = Kyuureki.gregorianToKyuureki
        (parseInt (m[1], 10), parseInt (m[2], 10), parseInt (m[3], 10));
    result.negative = result[0] < 0;
    if (result.negative) result[0] = -result[0];
    var line = m[1] + "-" + m[2] + "-" + m[3] + "\t" +
        (result.negative ? "-" : "") +
        (result[0] < 10 ? "000" + result[0] : result[0] < 100 ? "00" + result[0] : result[0] < 1000 ? "0" + result[0] : result[0]) + "-" +
        (result[1] < 10 ? "0" + result[1] : result[1]) +
        (result[2] ? "'" : '') + "-" +
        (result[3] < 10 ? "0" + result[3] : result[3]) + "\n";
    resultLines.push (line);
  }
});

fs.write ('local/test2.out', resultLines.join (""));

phantom.exit ();
