package Algorithm::LibLinear::ScalingParameter;

use 5.014;
use Carp qw//;
use List::MoreUtils qw/minmax/;
use List::Util qw/max/;
use Smart::Args;

sub new {
    args
        my $class => 'ClassName',
        my $data_set => +{
            isa => 'Algorithm::LibLinear::DataSet',
            optional => 1,
        },
        my $lower_bound => +{ isa => 'Num', default => -1.0, },
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

    $self->{min_max_values} =
        $min_max_values // $self->compute_min_max_values(data_set => $data_set);

    return $self;
}

sub load {
    args
        my $class => 'ClassName',
        my $filename => +{ isa => 'Str', optional => 1, },
        my $fh => +{ isa => 'FileHandle', optional => 1, };

    unless ($filename or $fh) {
        Carp::croak('Neither "filename" nor "fh" is given.');
    }
    open $fh, '<', $filename or Carp::croak($!) unless $fh;

    chomp(my $header = <$fh>);
    Carp::croak('At present, y-scaling is not supported.') if $header eq 'y';
    Carp::croak('Invalid format.') if $header ne 'x';

    chomp(my $bounds = <$fh>);
    my ($lower_bound, $upper_bound) = split /\s+/, $bounds;

    my @min_max_values;
    while (defined(my $min_max_values = <$fh>)) {
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

sub parse {
    args
        my $class => 'ClassName',
        my $dump => 'Str';
    open my $str_fh, '<', \$dump or die $!;
    $class->load(fh => $str_fh);
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
        my ($min, $max) = minmax map { $_->{$i} // () } @feature_vectors;
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
