package Algorithm::LibLinear::DataSet;

use 5.014;
use Algorithm::LibLinear;  # For Algortihm::LibLinear::Problem
use Algorithm::LibLinear::Types;
use Carp qw//;
use List::MoreUtils qw/any/;
use Smart::Args;

sub new {
    args
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
    $class->new(data_set => $class->parse_input_file($source));
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

sub as_string {
    args
        my $self;

    my $result = '';
    for my $entry (@{ $self->as_arrayref }) {
        my $feature = $entry->{feature};
        my @feature_dump =
            map { "$_:$feature->{$_}" } sort { $a <=> $b } keys %$feature;
        $result .= join(' ', $entry->{label}, @feature_dump) . "\n";
    }
    return $result;
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

sub scale {
    args
        my $self,
        my $parameter => 'Algorithm::LibLinear::ScalingParameter';

    my ($lower_bound, $upper_bound) =
        ($parameter->lower_bound, $parameter->upper_bound);
    my $min_max_values = $parameter->min_max_values;
    my @scaled_data_set = map {
        my $feature = $_->{feature};
        my $label = $_->{label};
        my %scaled_feature;
        for my $index (keys %$feature) {
            my $unscaled = $feature->{$index};
            my ($min, $max) = @{ $min_max_values->[$index - 1] // [0, 0] };
            next if $min == $max;
            given ($unscaled) {
                when ($min) { $scaled_feature{$index} = $lower_bound }
                when ($max) { $scaled_feature{$index} = $upper_bound }
                default {
                    my $ratio = ($_ - $min) / ($max - $min);
                    my $scaled =
                        $lower_bound + ($upper_bound - $lower_bound) * $ratio;
                    $scaled_feature{$index} = $scaled;
                }
            }
        }
        +{ feature => \%scaled_feature, label => $label, };
    } @{ $self->as_arrayref };
    return __PACKAGE__->new(data_set => \@scaled_data_set);
}

sub size { 0 + @{ $_[0]->as_arrayref } }

1;
