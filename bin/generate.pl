use strict;
use warnings;
use JSON::PS;

my $FirstYear;
my $LastYear;

my $Data = {};

my $map_file_name = "local/map.txt";
open my $map_file, '<', $map_file_name or die "$0: $map_file_name: $!";
my $last_seireki_date;
local $/ = undef;
for (split /\x0D?\x0A/, scalar <$map_file>) {
  if (/^([\d'-]+)\t([\d'-]+-01)$/) {
    my $G = $1;
    my $Q = $2;
    if ($Q =~ /^(-?[0-9]+)-01-01$/) {
      $FirstYear //= 0+$1;
      $LastYear = 0+$1;
      $Data->{kyuureki_year_to_gregorian_date}->[$1 - $FirstYear] = $G;
    }
  }
  if (/^([\d'-]+)\t(([\d'-]+)-[0-9]+)$/) {
    $Data->{kyuureki_month_to_day_number}->{$3}++;
    if ($3 =~ /^(-?[0-9]+)-([0-9]+)'$/) {
      $Data->{kyuureki_year_to_leap_month}->[$1 - $FirstYear] = $2;
    }
    $last_seireki_date = $1;
  }
}
if ($last_seireki_date =~ /^(-?\d+)-(\d+)-(\d+)$/) {
  $Data->{kyuureki_year_to_gregorian_date}->[$1 - $FirstYear]
      = sprintf '%04d-%02d-%02d', $1, $2, $3+1;
}

$Data->{kyuureki_year_to_gregorian_date} = join '', map {
  if (/-01-([0-9]{2})$/) {
    pack 'C', $1
  } elsif (/-02-([0-9]{2})$/) {
    pack 'C', 31 + $1;
  } else {
    die $_;
  }
} @{$Data->{kyuureki_year_to_gregorian_date}};

$Data->{kyuureki_year_to_leap_month}->[$LastYear + 1 - $FirstYear] ||= 0;
$Data->{kyuureki_year_to_leap_month} = join '', map { sprintf '%X', ($_ || 0) } @{$Data->{kyuureki_year_to_leap_month}};

for (sort { $a cmp $b } keys %{$Data->{kyuureki_month_to_day_number}}) {
  /^(-?[0-9]+)-/ or die $_;
  my $year = $1;
  my $value = $Data->{kyuureki_month_to_day_number}->{$_};
  my $vector = $Data->{kyuureki_year_to_month_types}->[$year - $FirstYear];
  if ($value == 30) {
    $vector .= '1';
  } elsif ($value == 29) {
    $vector .= '0';
  } else {
    die "$_ has $value days";
  }
  $Data->{kyuureki_year_to_month_types}->[$year - $FirstYear] = $vector;
}
delete $Data->{kyuureki_month_to_day_number};

for (@{$Data->{kyuureki_year_to_month_types}}) {
  $_ = (pack 'B8', '0'.substr $_, 0, 7) . (pack 'B8', '0'.substr $_.'000000', 7, 7);
}
$Data->{kyuureki_year_to_month_types} = join '', @{$Data->{kyuureki_year_to_month_types}};

$Data->{year_range} = [$FirstYear, $LastYear];

$Data->{gregorian_month_to_offset} = [
  undef,
  0,
  31,
  31+28,
  31+28+31,
  31+28+31+30,
  31+28+31+30+31,
  31+28+31+30+31+30,
  31+28+31+30+31+30+31,
  31+28+31+30+31+30+31+31,
  31+28+31+30+31+30+31+31+30,
  31+28+31+30+31+30+31+31+30+31,
  31+28+31+30+31+30+31+31+30+31+30,
  31+28+31+30+31+30+31+31+30+31+30+31,
];

my $js_code = q{
(function (self) {
  var MONTH_TO_OFFSET = $Data->{gregorian_month_to_offset};
  var FIRST_GREGORIAN_DAY = $Data->{kyuureki_year_to_gregorian_date};
  var MONTH_TYPES = $Data->{kyuureki_year_to_month_types};
  var LEAP_MONTH = $Data->{kyuureki_year_to_leap_month};
  var MIN_YEAR = $Data->{year_range}->[0];
  var MAX_YEAR = $Data->{year_range}->[1];

  var gregorianToKyuureki = function (y, m, d) {
    if (y < MIN_YEAR || MAX_YEAR + 1 < y || (y == MAX_YEAR + 1 && m > 2)) {
      return [null, null, null, null];
    }

    var day = d + MONTH_TO_OFFSET[m];
    var isLeapYear = ((y % 4) == 0 && !((y % 100 == 0) && !(y % 400 == 0)));
    if (isLeapYear && m > 2) day++;

    var offset = MIN_YEAR;
    var firstDay = FIRST_GREGORIAN_DAY.charCodeAt (y - offset, 1);

    if (day < firstDay) {
      y--;
      day += 365;
      isLeapYear = ((y % 4) == 0 && !((y % 100 == 0) && !(y % 400 == 0)));
      if (isLeapYear) day++;
      firstDay = FIRST_GREGORIAN_DAY.charCodeAt (y - offset, 1);
    }
    day -= firstDay - 1;

    var mtOffset = 2 * (y - offset);
    var mt = ((MONTH_TYPES.charCodeAt (mtOffset) & 127) << 7) |
              (MONTH_TYPES.charCodeAt (mtOffset + 1) & 127);

    var leapMonth = parseInt (LEAP_MONTH.charAt (y - offset), 16);
    var month = 1;
    while (true) {
      var days = (mt & (1 << (14 - month))) ? 30 : 29;
      if (day <= days || month === 13) {
        break;
      } else {
        day -= days;
        month++;
      }
    }
    if (!leapMonth) {
      return [y, month, false, day];
    } else if (month === leapMonth + 1) {
      return [y, month-1, true, day];
    } else if (leapMonth < month) {
      return [y, month-1, false, day];
    } else {
      return [y, month, false, day];
    }
  }; // gregorianToKyuureki

  function kyuurekiToGregorian (y, m, l, d) {
    if (y < MIN_YEAR || MAX_YEAR < y) {
      return [null, null, null];
    }

    var offset = MIN_YEAR;
    var firstDay = FIRST_GREGORIAN_DAY.charCodeAt (y - offset);
    var leapMonth = parseInt (LEAP_MONTH.charAt (y - offset), 16);
    var mtOffset = 2 * (y - offset);
    var mt = ((MONTH_TYPES.charCodeAt (mtOffset) & 127) << 7) |
              (MONTH_TYPES.charCodeAt (mtOffset + 1) & 127);

    if (leapMonth && leapMonth < m) m++;
    if (l) m++;

    for (var i = 14 - 1; i > 14 - m; i--) {
      d += (mt & (1 << i)) ? 30 : 29;
    }
    d += firstDay - 1;

    var leapDay = ((y % 4) == 0 && !((y % 100 == 0) && !(y % 400 == 0)))?1:0;
    if (MONTH_TO_OFFSET[13] + leapDay < d) {
      d -= MONTH_TO_OFFSET[13] + leapDay;
      if (d > 31) {
        return [y+1, 2, d-31];
      } else {
        return [y+1, 1, d];
      }
    }

    var months = [12, 11, 10, 9, 8, 7, 6, 5, 4, 3];
    for (var i = 0; i < months.length; i++) {
      if (MONTH_TO_OFFSET[months[i]] + leapDay < d) {
        return [y, months[i], d - MONTH_TO_OFFSET[months[i]] - leapDay];
      }
    }
    if (MONTH_TO_OFFSET[2] < d) return [y, 2, d - MONTH_TO_OFFSET[2]]
    if (MONTH_TO_OFFSET[1] < d) return [y, 1, d - MONTH_TO_OFFSET[1]]
    return [null, null, null];
  }; // kyuurekiToGregorian

  if (!self.Kyuureki) self.Kyuureki = {};
  self.Kyuureki.gregorianToKyuureki = gregorianToKyuureki;
  self.Kyuureki.kyuurekiToGregorian = kyuurekiToGregorian;
}) (self);

/* License: Public Domain. */
};

$js_code =~ s{\$Data->\{(\w+)\}->\[(\d+)\]}{
  $Data->{$1}->[$2];
}ge;
$js_code =~ s{\$Data->\{(\w+)\}}{
  perl2json_bytes_for_record $Data->{$1};
}ge;

my $module_file_name = 'kyuureki.js';
open my $module_file, '>', $module_file_name or die "$0: $module_file_name: $!";
print $module_file $js_code;

## License: Public Domain.
