package Algorithm::LibLinear::ScalingParameter;

use 5.014;
use Carp qw//;
use Algorithm::LibLinear;  # For $SUPRESS_DEPRECATED_WARNING.
use List::MoreUtils qw/none minmax/;
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

    unless ($Algorithm::LibLinear::SUPRESS_DEPRECATED_WARNING) {
        Carp::carp(
            'Algorithm::LibLinear::ScalingParameter is deprecated.',
            ' This class will be removed from near future release.',
            ' Please use Algorithm::LibLinear::FeatureScaling instead.',
        );
    }

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
        my $filename => +{ isa => 'Str', optional => 1, },
        my $fh => +{ isa => 'FileHandle', optional => 1, },
        my $string => +{ isa => 'FileHandle', optional => 1, };

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

sub save {
    args
        my $self,
        my $filename => +{ isa => 'Str', optional => 1, },
        my $fh => +{ isa => 'FileHandle', optional => 1, };
    unless ($filename or $fh) {
        Carp::croak('Neither "filename" nor "fh" is given.');
    }
    open $fh, '>', $filename or Carp::croak($!) unless $fh;
    print $fh $self->as_string;
}

sub lower_bound { $_[0]->{lower_bound} }

sub min_max_values { $_[0]->{min_max_values} }

sub upper_bound { $_[0]->{upper_bound} }

1;

__DATA__

=head1 NAME

Algorithm::LibLinear::ScalingParameter

=head1 SYNOPSIS

  use Algorithm::LibLinear::DataSet;
  use Algorithm::LibLinear::ScalingParameter;
  
  my $training_data = Algorithm::LibLinear::DataSet->load(fh => \*DATA);
  my $parameter = Algorithm::LibLinear::ScalingParameter->new(data_set => $training_data);
  my $scaled_training_data = $training_data->scale(parameter => $parameter);
  say $scaled_training_data->as_string;
  # 1 1:0.8541665 2:1 3:1 4:0.3396225 5:0.4474885 6:0 7:1 8:0.2900765 9:0 10:0.387097 12:1 13:0
  # -1 1:0.7916665 2:0 3:0.6666665 4:0.198113 5:1 6:0 7:1 8:0.6793895 9:0 10:0.2580645 12:0 13:1
  # 1 1:0.5833335 2:1 3:0.3333335 4:0.283019 5:0.308219 6:0 7:0 8:0.53435115 9:0 10:0.048387 11:0 12:0 13:1
  # ...
  
  __DATA__
  +1 1:0.708333 2:1 3:1 4:-0.320755 5:-0.105023 6:-1 7:1 8:-0.419847 9:-1 10:-0.225806 12:1 13:-1 
  -1 1:0.583333 2:-1 3:0.333333 4:-0.603774 5:1 6:-1 7:1 8:0.358779 9:-1 10:-0.483871 12:-1 13:1 
  +1 1:0.166667 2:1 3:-0.333333 4:-0.433962 5:-0.383562 6:-1 7:-1 8:0.0687023 9:-1 10:-0.903226 11:-1 12:-1 13:1 
  ...

=head1 DESCRIPTION

C<Algorithm::LibLinear::ScalingParameter> contains configuration for feature scaling. The parameter is used by L<Algorithm::LibLinear::DataSet>'s C<scale> method.

=head1 METHODS

=head2 new([data_set => $data_set] [, lower_bound => 0] [, upper_bound => 1.0] [, min_max_values => \@min_max_values])

Constructor. At least you have to specify either C<data_set> or C<min_max_values>.
C<data_set> is an instance of C<Algorithm::LibLinear::DataSet>. 
C<min_max_values> is an ArrayRef of 2-element ArrayRefs. Each ArrayRef should contain minimum and maximum value of corresponding feature.

=head2 load([fh => \*FH] [, filename => $path] [, string => $string])

Class method.

Restores parameter from LIBSVM/LIBLINEAR scaling parameter file.

=head2 as_string

Dumps scaling parameter as LIBSVM/LIBLINEAR format.

=head2 lower_bound

=head2 upper_bound

The lower/upper bound of scaled feature value.

=head2 save([filename => $path] [, fh => \*FH])

Writes scaling parameter into a file.

=cut
