WGET = wget
GIT = git
PHANTOMJS = phantomjs

all: impl
clean:
	rm -fr local/*.json local/*.out

updatenightly: clean impl
	$(GIT) add *.js

deps:

json-ps: local/perl-latest/pm/lib/perl5/JSON/PS.pm
clean-json-ps:
	rm -fr local/perl-latest/pm/lib/perl5/JSON/PS.pm
local/perl-latest/pm/lib/perl5/JSON/PS.pm:
	mkdir -p local/perl-latest/pm/lib/perl5/JSON
	$(WGET) -O $@ https://raw.githubusercontent.com/wakaba/perl-json-ps/master/lib/JSON/PS.pm

impl: json-ps kyuureki.js deps

kyuureki.js: bin/generate.pl local/map.txt
	perl -Ilocal/perl-latest/pm/lib/perl5 bin/generate.pl

local/map.txt:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-locale/staging/data/calendar/kyuureki-map.txt

test: test-deps
	$(PHANTOMJS) t/test1.js
	diff -u local/map.txt local/test1.out > local/test1.diff
	$(PHANTOMJS) t/test2.js
	diff -u local/map.txt local/test2.out > local/test2.diff

test-deps: impl