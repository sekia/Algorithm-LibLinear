use strict;
use warnings;
use Test::Exception::LessClever;
use Test::More;

BEGIN { use_ok 'Algorithm::LibLinear' }

{
    my $learner = new_ok 'Algorithm::LibLinear';
    is $learner->cost, 1;
    is $learner->epsilon, 0.1;
    ok +(not $learner->is_regression_solver),
        'A solver for classification is selected by default';
    is_deeply $learner->weights, [];
}

{
    my @weights = (
        +{ label => -1, weight => 0.6, },
        +{ label => 1, weight => 0.3, },
    );
    my $learner = new_ok 'Algorithm::LibLinear' => [
        cost => 10,
        epsilon => 0.42,
        loss_sensitivity => 0.84,
        solver => 'L2R_L2LOSS_SVR_DUAL',
        weights => \@weights,
    ];
    is $learner->cost, 10;
    is $learner->epsilon, 0.42;
    is $learner->loss_sensitivity, 0.84;
    ok $learner->is_regression_solver,
        'Solver "L2R_L2LOSS_SVR_DUAL" is a regression solver.';
    is_deeply $learner->weights, \@weights;
}

throws_ok {
    Algorithm::LibLinear->new(cost => 0);
} qr/C <= 0/;

throws_ok {
    Algorithm::LibLinear->new(epsilon => 0);
} qr/eps <= 0/;

throws_ok {
    Algorithm::LibLinear->new(loss_sensitivity => -1);
} qr/p < 0/;

done_testing;
