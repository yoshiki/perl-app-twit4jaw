use inc::Module::Install;
name 'twit4jaw';
all_from 'bin/twit4jaw.pl';

requires 'Daemonise';
requires 'Getopt::Long';
requires 'Pod::Usage';
requires 'Path::Class';
requires 'JSON::Syck';
requires 'Encode';
requires 'Encode::JavaScript::UCS';
requires 'List::Util';
requires 'LWP::Simple';
requires 'Net::Twitter::Lite';

install_script 'bin/twit4jaw.pl';

tests 't/*.t';

build_requires 'Test::More';
use_test_base;
auto_include;
WriteAll;
