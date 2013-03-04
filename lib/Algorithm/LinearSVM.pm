package Algorithm::LinearSVM;

use 5.014;
use Algorithm::LinearSVM::DataSet;
use Algorithm::LinearSVM::Model;
use Algorithm::LinearSVM::Types;
use Smart::Args;
use XSLoader;

our $VERSION = '0.01';

our %solvers = (
    # Solvers for classification problem
    L2R_LR => 0,
    L2R_L2LOSS_SVC_DUAL => 1,
    L2R_L2LOSS_SVC => 2,
    L2R_L1LOSS_SVC_DUAL => 3,
    MCSVM_CS => 4,
    L1R_L2LOSS_SVC => 5,
    L1R_LR => 6,
    L2R_LR_DUAL => 7,

    # Solvers for regression problem
    L2R_L2LOSS_SVR => 11,
    L2R_L2LOSS_SVR_DUAL => 12,
    L2R_L1LOSS_SVR_DUAL => 13,
);

my %default_eps = (
    L2R_LR => 0.01,
    L2R_L2LOSS_SVC_DUAL => 0.1,
    L2R_L2LOSS_SVC => 0.01,
    L2R_L1LOSS_SVC_DUAL => 0.1,
    MCSVM_CS => 0.1,
    L1R_L2LOSS_SVC => 0.01,
    L1R_LR => 0.01,
    L2R_LR_DUAL => 0.1,

    # Solvers for regression problem
    L2R_L2LOSS_SVR => 0.001,
    L2R_L2LOSS_SVR_DUAL => 0.1,
    L2R_L1LOSS_SVR_DUAL => 0.1,
);

XSLoader::load(__PACKAGE__, $VERSION);

sub new {
    args
        my $class => 'ClassName',
        my $cost => +{ isa => 'Int', default => 1, },
        my $epsilon => +{ isa => 'Num', optional => 1, },
        my $loss_sensitivity => +{ isa => 'Num', default => 0.1, },
        my $solver => +{
            isa => 'Algorithm::LinearSVM::SolverDescriptor',
            default => 'L2R_L2LOSS_SVC_DUAL',
        },
        my $weights => +{
            isa => 'ArrayRef[Algorithm::LinearSVM::Parameter::ClassWeight]',
            default => [],
        };

    $epsilon //= $default_eps{$solver};

    my (@weight_labels, @weights);
    for my $weight (@$weights) {
        push @weight_labels, $weight->{label};
        push @weights, $weight->{weight};
    }
    my $parameter = Algorithm::LinearSVM::Parameter->new(
        $solvers{$solver},
        $epsilon,
        $cost,
        \@weight_labels,
        \@weights,
        $loss_sensitivity,
    );
    bless +{ parameter => $parameter } => $class;
}

sub cross_validation {
    args
        my $self,
        my $data_set => 'Algorithm::LinearSVM::DataSet',
        my $num_folds => 'Int';

    my $targets =
        $self->parameter->cross_validation($data_set->as_problem, $num_folds);
    my @labels = map { $_->{label} } @{ $data_set->as_arrayref };
    if ($self->parameter->is_regression_solver) {
        my $total_square_error = 0;
        for my $i (0 .. $data_set->size - 1) {
            $total_square_error += ($targets->[$i] - $labels[$i]) ** 2;
        }
        # Returns mean squared error.
        # TODO: Squared correlation coefficient (see train.c in LIBLINEAR.)
        return $total_square_error / $data_set->size;
    } else {
        my $num_corrects;
        for my $i (0 .. $data_set->size - 1) {
            ++$num_corrects if $targets->[$i] == $labels[$i];
        }
        return $num_corrects / $data_set->size;
    }
}

sub parameter { $_[0]->{parameter} }

sub train {
    args
        my $self,
        my $data_set => 'Algorithm::LinearSVM::DataSet';

    my $raw_model = Algorithm::LinearSVM::Model::Raw->train(
        $data_set->as_problem,
        $self->parameter,
    );
    Algorithm::LinearSVM::Model->new(raw_model => $raw_model);
}

1;
__END__

=head1 NAME

Algorithm::LinearSVM -

=head1 SYNOPSIS

  use Algorithm::LinearSVM;

=head1 DESCRIPTION

Algorithm::LinearSVM is

=head1 AUTHOR

Koichi SATOH E<lt>sato@seesaa.co.jpE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
