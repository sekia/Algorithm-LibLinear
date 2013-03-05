package Algorithm::LibLinear::DataSet;

use 5.014;
use Algorithm::LibLinear;  # For Algortihm::LibLinear::Problem
use Algorithm::LibLinear::Types;
use Carp;
use List::MoreUtils qw/any/;
use Smart::Args;

sub new {
    args_pos
        my $class => 'ClassName',
        my $data_set => 'ArrayRef[Algorithm::LibLinear::LabeledData]';

    bless +{ data_set => $data_set } => $class;
}

sub load {
    args
        my $class => 'ClassName',
        my $fh => +{ isa => 'FileHandle', optional => 1, },
        my $filename => +{ isa => 'Str', optional => 1, },
        my $string => +{ isa => 'Str', optional => 1, };

    unless (any { defined } ($fh, $filename, $string)) {
        Carp::croak('No source specified.');
    }
    my $source = $fh;
    $source //= do {
        open my $fh, '<', +($filename // \$string) or die $!;
        $fh;
    };
    $class->new($class->parse_input_file($source));
}

sub add_data {
    args
        my $self,
        my $data => 'Algorithm::LibLinear::LabeledData';

    push @{ $self->data_set }, $data;
}

sub as_arrayref { $_[0]->{data_set} }

sub as_problem {
    args
        my $self,
        my $bias => +{ isa => 'Num', optional => 1, };

    my (@features, @labels);
    for my $data (@{ $self->as_arrayref }) {
        push @features, $data->{feature};
        push @labels, $data->{label};
    }
    Algorithm::LibLinear::Problem->new(
        \@labels, \@features, defined $bias ? ($bias) : (),
    );
}

sub parse_input_file {
    args_pos
        my $class => 'ClassName',
        my $source => 'FileHandle';

    my @data_set;
    while (defined(my $line = <$source>)) {
        chomp $line;
        my ($label, @feature) = split /\s+/, $line;
        $label += 0;
        my %feature = map {
            my ($index, $value) = split /:/;
            $index += 0;
            $value += 0;
            ($index => $value);
        } @feature;
        push @data_set, +{ feature => \%feature, label => $label, };
    }
    return \@data_set;
}

sub size { @{ $_[0]->as_arrayref } + 0 }

1;
