package Algorithm::LibLinear::FeatureScaling;

use 5.014;
use Algorithm::LibLinear::Types;
use Carp qw//;
use List::MoreUtils qw/minmax none/;
use List::Util qw/max/;
use Smart::Args;

sub new {
    args
        my $class => 'ClassName',
        my $data_set => +{
            isa => 'Algorithm::LibLinear::DataSet',
            optional => 1,
        },
        my $lower_bound => +{ isa => 'Num', default => 0, },
        my $min_max_values => +{
            isa => 'ArrayRef[ArrayRef[Num]]',
            optional => 1,
        },
        my $upper_bound => +{ isa => 'Num', default => 1.0, };

    unless ($data_set or $min_max_values) {
        Carp::croak('Neither "data_set" nor "min_max_values" is specified.');
    }

    my $self = bless +{
        lower_bound => $lower_bound,
        upper_bound => $upper_bound,
    } => $class;

    $self->{min_max_values} = $min_max_values
        // $self->compute_min_max_values(data_set => $data_set);

    return $self;
}

sub load {
    args
        my $class => 'ClassName',
        my $fh => +{ isa => 'FileHandle', optional => 1, },
        my $filename => +{ isa => 'Str', optional => 1, },
        my $string => +{ isa => 'Str', optional => 1, };

    if (none { defined } ($filename, $fh, $string)) {
        Carp::croak('No source specified.');
    }
    my $source = $fh;
    $source //= do {
        open $fh, '<', +($filename // \$string) or Carp::croak($!);
        $fh;
    };

    chomp(my $header = <$source>);
    Carp::croak('At present, y-scaling is not supported.') if $header eq 'y';
    Carp::croak('Invalid format.') if $header ne 'x';

    chomp(my $bounds = <$source>);
    my ($lower_bound, $upper_bound) = split /\s+/, $bounds;

    my @min_max_values;
    while (defined(my $min_max_values = <$source>)) {
        chomp $min_max_values;
        my (undef, $min, $max) = split /\s+/, $min_max_values;
        push @min_max_values, [ $min, $max ];
    }

    $class->new(
        lower_bound => $lower_bound,
        min_max_values => \@min_max_values,
        upper_bound => $upper_bound,
    );
}

sub as_string {
    args
        my $self;
    my $acc =
        sprintf "x\n%.16g %.16g\n", $self->lower_bound, $self->upper_bound;
    my $index = 0;
    for my $min_max_value (@{ $self->min_max_values }) {
        $acc .= sprintf "\%d %.16g %.16g\n", ++$index, @$min_max_value;
    }
    return $acc;
}

sub compute_min_max_values {
    args
        my $self,
        my $data_set => 'Algorithm::LibLinear::DataSet';

    my @feature_vectors = map { $_->{feature} } @{ $data_set->as_arrayref };
    my $last_index = max map { keys %$_ } @feature_vectors;
    my @min_max_values;
    for my $i (1 .. $last_index) {
        my ($min, $max) = minmax map { $_->{$i} // 0 } @feature_vectors;
        push @min_max_values, [ $min, $max ];
    }
    return \@min_max_values;
}

sub lower_bound { $_[0]->{lower_bound} }

sub min_max_values { $_[0]->{min_max_values} }

sub save {
    args
        my $self,
        my $fh => +{ isa => 'FileHandle', optional => 1, },
        my $filename => +{ isa => 'Str', optional => 1, };

    unless ($filename or $fh) {
        Carp::croak('Neither "filename" nor "fh" is given.');
    }
    open $fh, '>', $filename or Carp::croak($!) unless $fh;
    print $fh $self->as_string;
}

sub scale {
    args_pos
        my $self,
        my $target_type => 'Str',
        my $target;

    my $method = $self->can("scale_$target_type");
    unless ($method) {
        Carp::croak("Cannot scale such type of target: $target_type.");
    }
    $self->$method($target);
}

sub scale_data_set {
    args_pos
        my $self,
        my $data_set => 'Algorithm::LibLinear::DataSet';

    my @scaled_data_set =
        map { $self->scale_labeled_data($_) } @{ $data_set->as_arrayref };
    Algorithm::LibLinear::DataSet->new(data_set => \@scaled_data_set);
}

sub scale_feature {
    args_pos
        my $self,
        my $feature => 'Algorithm::LibLinear::Feature';

    my ($lower_bound, $upper_bound) = ($self->lower_bound, $self->upper_bound);
    my $min_max_values = $self->min_max_values;
    my %scaled_feature;
    for my $index (1 .. @$min_max_values) {
        my $unscaled = $feature->{$index} // 0;
        my ($min, $max) = @{ $min_max_values->[$index - 1] // [0, 0] };
        next if $min == $max;
        my $scaled;
        if ($unscaled == $min) {
            $scaled = $lower_bound;
        } elsif ($unscaled == $max) {
            $scaled = $upper_bound;
        } else {
            my $ratio = ($unscaled - $min) / ($max - $min);
            $scaled = $lower_bound + ($upper_bound - $lower_bound) * $ratio;
        }
        $scaled_feature{$index} = $scaled if $scaled != 0;
    }
    return \%scaled_feature;
}

sub scale_labeled_data {
    args_pos
        my $self,
        my $labeled_data => 'Algorithm::LibLinear::LabeledData';

    +{
        feature => $self->scale_feature($labeled_data->{feature}),
        label => $labeled_data->{label},
    };
}

sub upper_bound { $_[0]->{upper_bound} }

1;

__DATA__

=head1 NAME

Algorithm::LibLinear::FeatureScaling

=head1 SYNOPSIS

  use Algorithm::LibLinear::DataSet;
  use Algorithm::LibLinear::FeatureScaling;
  
  my $scale = Algorithm::LibLinear::FeatureScaling->new(
    lower_bound => -10,
    data_set => Algorithm::LibLinear::DataSet->new(...),
    upper_bound => 10,
  );
  
  my $scaled_feature = $scale->scale(feature => +{ 1 => 30, 2 => - 25, ... });
  my $scaled_labeled_data = $scale->scale(
    labeled_data => +{ feature => +{ 1 => 30, ... }, label => 1 },
  );
  my $scaled_data_set = $scale->scale(
    data_set => Algorithm::LibLinear::DataSet->new(...),
  );

=cut
