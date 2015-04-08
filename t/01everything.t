#!/usr/bin/perl -w

use Test::More;

use strict qw(vars);
use diagnostics;

use Net::Patricia;
use Storable;

our $debug = 1;

plan tests => 64;

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $t = new Net::Patricia;

isa_ok($t, 'Net::Patricia', 'creating base object');

ok($t->add_string('127.0.0.0/8'), 'adding 127.0.0.0/8');

my $thawed = Storable::thaw(Storable::nfreeze($t));

for my $o ({ name => "original", obj => $t }, { name => "thawed", obj => $thawed }) {
    is($o->{obj}->match_string("127.0.0.1"), "127.0.0.0/8", "$o->{name}: looking for 127.0.0.1");

    is($o->{obj}->match_integer(2130706433), "127.0.0.0/8", "$o->{name}: looking for 2130706433");

    ok(!$o->{obj}->match_string("10.0.0.1"), "$o->{name}: looking for 10.0.0.1");

    ok(!$o->{obj}->match_integer(42), "$o->{name}: looking for 42");
}

{
   my $ten = new Thingy 10;
   my $twenty = new Thingy 20;
ok($t->add_string("10.0.0.0/8", $ten), "adding 10.0.0.0/8");
}

diag "Destructor 10 should *not* have run yet (but 20 should have).\n" if $debug;

foreach my $subnet (qw(10.42.42.0/31 10.42.42.0/26 10.42.42.0/24 10.42.42.0/32 10.42.69.0/24)) {
   ok($t->add_string($subnet), "adding $subnet");
}

$thawed = Storable::thaw(Storable::nfreeze($t));
for my $o ({ name => "original", obj => $t }, { name => "thawed", obj => $thawed }) {

    my $str1 = $o->{obj}->match_string("10.42.42.0/24");
    my $str2 = $o->{obj}->match_string("10.42.69.0/24");

    isnt($str1, $str2, "$o->{name}: compare matches from 10.42.42.0/24 and 10.42.69.0/24");

    is(${$o->{obj}->match_integer(168430090)}, 10, "$o->{name}: looking for 168430090");

    ok($o->{obj}->match_string("10.0.0.1"), "$o->{name}: looking for 10.0.0.1");

    ok(!$o->{obj}->match_exact_integer(167772160), "$o->{name}: looking for 167772160");

    ok($o->{obj}->match_exact_integer(167772160, 8), "$o->{name}: looking for 167772160, 8");

    is(${$o->{obj}->match_exact_string("10.0.0.0/8")}, 10, "$o->{name}: looking for 10.0.0.0/8");
}

ok(!$t->remove_string("42.0.0.0/8"), "removing 42.0.0.0/8");

is(${$t->remove_string("10.0.0.0/8")}, 10, "removing 10.0.0.0/8");

$thawed = Storable::thaw(Storable::nfreeze($t));
diag "Destructor 10 should have just run (twice, once for the destroyed clone).\n" if $debug;

for my $o ({ name => "original", obj => $t }, { name => "thawed", obj => $thawed }) {
    ok(!$o->{obj}->match_exact_integer(167772160, 8), "$o->{name}: looking for exact 167772160, 8");

    # print "YOU SHOULD SEE A USAGE ERROR HERE:\n";
    # $o->{obj}->match_exact_integer(167772160, 8, 10);

    is($o->{obj}->climb_inorder(sub { diag "$o->{name}: climbing at $_[0]\n" }), 6, "$o->{name}: climb inorder");

    ok($o->{obj}->climb, "$o->{name}: climb");
}

eval '$t->add_string("_")'; # invalid key
like($@, qr/invalid/, 'adding "_"');

ok($t->add_string("0/0"), "add 0/0");

$thawed = Storable::thaw(Storable::nfreeze($t));
for my $o ({ name => "original", obj => $t }, { name => "thawed", obj => $thawed }) {
    ok($o->{obj}->match_string("10.0.0.1"), "$o->{name}: lookup 10.0.0.1");
}

my @a = $t->add_cidr("211.200.0.0-211.205.255.255", "cidr block!");

is(@a, 2, "adding cidr block");

$thawed = Storable::thaw(Storable::nfreeze($t));
for my $o ({ name => "original", obj => $t }, { name => "thawed", obj => $thawed }) {
    is($o->{obj}->match_string("211.202.0.1"), "cidr block!", "$o->{name}: looking for 211.202.0.1");
}

@a = $t->remove_cidr("211.200.0.0-211.205.255.255");

is(@a, 2, "removing cidr block");

undef $t;

$t = new Net::Patricia(AF_INET6);

isa_ok($t, "Net::Patricia::AF_INET6", "constructing a Net::Patrica::AF_INET6");

ok($t->add_string("2001:220::/35", "hello, world"), "adding 2001:220::/35");

$thawed = Storable::thaw(Storable::nfreeze($t));
for my $o ({ name => "original", obj => $t }, { name => "thawed", obj => $thawed }) {
    is($o->{obj}->match_string("2001:220::/128"), "hello, world", "$o->{name}: looking for 2001:220::/128");
}

# test that "hex_ip" strings work:
ok($t->add_string("2001:DB8::/32", "RFC3849"), "adding 2001:DB8::/32");
ok($t->match_string("2001:db8::"), "looking for 2001:db8::");
ok($t->match_string("2001:0db8:0000:0000:0000:0000:0000:0000"), "looking for 2001:0db8:0000:0000:0000:0000:0000:0000");
ok($t->match_string("20010db8000000000000000000000000"), "looking for 20010db8000000000000000000000000");
undef $t;
undef $thawed;

{
my $t = new Net::Patricia(AF_INET6);
# { These IP addresses below were chosen so that the trie contains three nodes,
#   two nodes with values and one "internal" node, the root, representing
#   "::/0", i.e., like this:
#
#                  [::/0]
#                  /    \
#      0:0:0:dead::     a000:0:0:beef::
#   
#   The following tests depend on this structure.
$t->add_string("0:0:0:dead::");
$t->add_string("a000:0:0:beef::");
# }
ok(2 == $t->climb(sub {1}), 'node count');

{
my $argCount = 0;
my $matchArgs = 0;
ok(2 == $t->climb(sub { $argCount = scalar(@_); if ($_[0] =~ m/dead|beef/) { $matchArgs++}; 1 }), 'climb callback');
ok(1 == $argCount, 'climb callback arg count');
ok(2 == $matchArgs, 'climb callback arg 0');
}

{
my $argCount = 0;
my $argValue = '';
ok(2 == $t->climb_inorder(sub { $argCount = scalar(@_); $argValue = $_[0]; 1}), 'node count, inorder');
ok(1 == $argCount, 'climb inorder callback arg count');
like($argValue, qr/beef/, 'climb inorder callback arg value');
}

{
my $argCount = 0;
my @rootBits;
my $callback = sub {
   $argCount = scalar(@_);
   if (!defined($_[0]) and -1 == $_[2]) {
      push(@rootBits, $_[1]);
   }
   1
};
ok(3 == $t->climb_inorder($callback, $callback), 'climb inorder two callbacks node count');
ok(3 == $argCount, 'climb inorder two callbacks arg count');
ok(1 == @rootBits, 'climb inorder two callbacks root visit count');
ok(0 == $rootBits[0], 'climb inorder two callbacks root bits');
}

ok(1 == $t->climb_inorder_limit(0, sub {1}, sub {1}), 'climb inorder limit two callbacks node count');

undef $t;
}

done_testing();

package Thingy;

use diagnostics;

sub new {
   my $class = shift(@_);
   my $self = shift(@_);
   return bless \$self, $class;
}

sub DESTROY {
   my $self = shift(@_);
   print STDERR "$$self What a world, what a world...\n";
}
