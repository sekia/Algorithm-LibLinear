package Algorithm::LibLinear;

use 5.014;
use Algorithm::LibLinear::DataSet;
use Algorithm::LibLinear::Model;
use Algorithm::LibLinear::Types;
use Smart::Args;
use XSLoader;

our $VERSION = '0.01';

XSLoader::load(__PACKAGE__, $VERSION);

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

my %solvers = (
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

sub new {
    args
        my $class => 'ClassName',
        my $cost => +{ isa => 'Num', default => 1, },
        my $epsilon => +{ isa => 'Num', optional => 1, },
        my $loss_sensitivity => +{ isa => 'Num', default => 0.1, },
        my $solver => +{
            isa => 'Algorithm::LibLinear::SolverDescriptor',
            default => 'L2R_L2LOSS_SVC_DUAL',
        },
        my $weights => +{
            isa => 'ArrayRef[Algorithm::LibLinear::TrainingParameter::ClassWeight]',
            default => [],
        };

    $epsilon //= $default_eps{$solver};
    my (@weight_labels, @weights);
    for my $weight (@$weights) {
        push @weight_labels, $weight->{label};
        push @weights, $weight->{weight};
    }
    my $training_parameter = Algorithm::LibLinear::TrainingParameter->new(
        $solvers{$solver},
        $epsilon,
        $cost,
        \@weight_labels,
        \@weights,
        $loss_sensitivity,
    );
    bless +{ training_parameter => $training_parameter } => $class;
}

sub cost { $_[0]->training_parameter->cost }

sub cross_validation {
    args
        my $self,
        my $data_set => 'Algorithm::LibLinear::DataSet',
        my $num_folds => 'Int';

    my $targets = $self->training_parameter->cross_validation(
        $data_set->as_problem,
        $num_folds,
    );
    my @labels = map { $_->{label} } @{ $data_set->as_arrayref };
    if ($self->is_regression_solver) {
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

sub epsilon { $_[0]->training_parameter->epsilon }

sub is_regression_solver { $_[0]->training_parameter->is_regression_solver }

sub loss_sensitivity { $_[0]->training_parameter->loss_sensitivity }

sub training_parameter { $_[0]->{training_parameter} }

sub train {
    args
        my $self,
        my $data_set => 'Algorithm::LibLinear::DataSet';

    my $raw_model = Algorithm::LibLinear::Model::Raw->train(
        $data_set->as_problem,
        $self->training_parameter,
    );
    Algorithm::LibLinear::Model->new(raw_model => $raw_model);
}

sub weights {
    args
        my $self;

    my $labels = $self->training_parameter->weight_labels;
    my $weights = $self->training_parameter->weights;
    [ map {
        +{ label => $labels->[$_], weight => $weights->[$_], }
    } 0 .. $#$labels ];
}

1;
__END__

=head1 NAME

Algorithm::LibLinear -

=head1 SYNOPSIS

  use Algorithm::LibLinear;

=head1 DESCRIPTION

Algorithm::LibLinear is

=head1 AUTHOR

Koichi SATOH E<lt>sato@seesaa.co.jpE<gt>

=head1 SEE ALSO

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
