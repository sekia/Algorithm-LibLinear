package Algorithm::LinearSVM::Model;

use 5.014;
use Algorithm::LinearSVM;  # For Algorithm::LinearSVM::Model::Raw
use Smart::Args;

sub new {
    args
        my $class => 'ClassName',
        my $raw_model => 'Algorithm::LinearSVM::Model::Raw';

    bless +{ raw_model => $raw_model, } => $class;
}

sub load {
    args
        my $class => 'ClassName',
        my $filename => 'Str';

    my $raw_model = Algorithm::LinearSVM::Model::Raw->load($filename);
    $class->new(raw_model => $raw_model);
}

sub class_labels { $_[0]->raw_model->class_labels }

sub is_probability_model { $_[0]->raw_model->is_probability_model }

sub num_classes { $_[0]->raw_model->num_classes }

sub num_features { $_[0]->raw_model->num_features }

sub raw_model { $_[0]->{raw_model} }

sub save {
    args
        my $self,
        my $filename => 'Str';

    $_[0]->raw_model->save($filename);
}

1;
