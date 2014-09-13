var system = require ('system');
var args = system.args;

require ('../../kyuureki');

var k = Kyuureki.gregorianToKyuureki
    (parseInt (args[1], 10), parseInt (args[2], 10), parseInt (args[3], 10));
console.log (k.join ("\t"));

phantom.exit ();