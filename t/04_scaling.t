use Algorithm::LibLinear::DataSet;
use Algorithm::LibLinear::ScalingParameter;
use Test::More;

my $data_set = Algorithm::LibLinear::DataSet->new(data_set => [
    +{
        feature => +{ 1 => 1.0, 2 => 2.0, 3 => 1.41, },
        label => 1,
    },
    +{
        feature => +{ 1 => 2.0, 2 => 2.0, 3 => 1.73, 4 => -1.0, },
        label => 1,
    },
    +{
        feature => +{ 1 => 3.0, 2 => 2.0, 3 => 2.00, 4 => -2.0, },
        label => 1,
    },
    +{
        feature => +{ 1 => 4.0, 2 => 2.0, 3 => 2.23, 4 => -3.0, },
        label => 1,
    },
]);

my $parameter = new_ok 'Algorithm::LibLinear::ScalingParameter' => [
    data_set => $data_set
];

ok my $scaled_data_set = $data_set->scale(parameter => $parameter);
is $scaled_data_set->size, $data_set->size;

my $scaled_within_range = 1;
VALUE_RANGE_CHECK:
for my $scaled_data (@{ $scaled_data_set->as_arrayref }) {
    for my $value (values %{ $scaled_data->{feature} }) {
        unless ($parameter->lower_bound <= $value
                    and $value <= $parameter->upper_bound) {
            $scaled_within_range = 0;
            last VALUE_RANGE_CHECK;
        }
    }
}
ok $scaled_within_range, 'Data set is scaled successfully.';

my $labels_are_saved = 1;
for my $i (0 .. $data_set->size - 1) {
    my $unscaled_data = $data_set->as_arrayref->[$i];
    my $scaled_data = $scaled_data_set->as_arrayref->[$i];
    is $unscaled_data->{label}, $scaled_data->{label};
    if ($unscaled_data->{label} != $scaled_data->{label}) {
        $labels_are_saved = 0;
        last;
    }
}
ok $labels_are_saved, 'Class labels should be unchanged after scaling.';

my @nums_nonzero_features =
    map { 0 + keys %{ $_->{feature} } } @{ $scaled_data_set->as_arrayref };
is_deeply(
    \@nums_nonzero_features,
    [ 2, 3, 3, 3, ],
    'Constant feature value should be ommited.',
);

done_testing;
