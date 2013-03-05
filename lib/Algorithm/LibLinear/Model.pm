package Algorithm::LibLinear::Model;

use 5.014;
use Algorithm::LibLinear;  # For Algorithm::LibLinear::Model::Raw
use Algorithm::LibLinear::Types;
use Carp qw//;
use Smart::Args;

sub new {
    args
        my $class => 'ClassName',
        my $raw_model => 'Algorithm::LibLinear::Model::Raw';

    bless +{ raw_model => $raw_model, } => $class;
}

sub load {
    args
        my $class => 'ClassName',
        my $filename => 'Str';

    my $raw_model = Algorithm::LibLinear::Model::Raw->load($filename);
    $class->new(raw_model => $raw_model);
}

sub class_labels { $_[0]->raw_model->class_labels }

sub is_probability_model { $_[0]->raw_model->is_probability_model }

sub num_classes { $_[0]->raw_model->num_classes }

sub num_features { $_[0]->raw_model->num_features }

sub raw_model { $_[0]->{raw_model} }

sub predict {
    args
        my $self,
        my $feature => 'Algorithm::LibLinear::Feature';

    $self->raw_model->predict($feature);
}

sub predict_probability {
    args
        my $self,
        my $feature => 'Algorithm::LibLinear::Feature';

    unless ($self->is_probability_model) {
        Carp::croak(
            'This method makes no sense when the model is trained as a'
            . ' classifier.',
        );
    }
    $self->raw_model->predict_probability($feature);
}

sub predict_values {
    args
        my $self,
        my $feature => 'Algorithm::LibLinear::Feature';

    $self->raw_model->predict_values($feature);
}

sub save {
    args
        my $self,
        my $filename => 'Str';

    $_[0]->raw_model->save($filename);
}

1;
