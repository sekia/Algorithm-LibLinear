use strict;
use warnings;
use Algorithm::LibLinear;
use Test::Exception::LessClever;
use Test::More;

new_ok 'Algorithm::LibLinear';

throws_ok { Algorithm::LibLinear->new(cost => 0) } qr/C <= 0/;

throws_ok { Algorithm::LibLinear->new(epsilon => 0) } qr/eps <= 0/;

throws_ok { Algorithm::LibLinear->new(loss_sensitivity => -1) } qr/p < 0/;

done_testing;
