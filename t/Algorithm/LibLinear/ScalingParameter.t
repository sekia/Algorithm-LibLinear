use Algorithm::LibLinear::DataSet;
use Algorithm::LibLinear::ScalingParameter;
use Test::Exception::LessClever;
use Test::More;

my $data_set = Algorithm::LibLinear::DataSet->load(fh => \*DATA);
my $parameter = new_ok 'Algorithm::LibLinear::ScalingParameter' => [
    data_set => $data_set
];
ok my $scaled_data_set = $data_set->scale(parameter => $parameter);
is $scaled_data_set->size, $data_set->size;

{
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
        [ 1, 4, 3, 3, ],
        'Constant feature value should be ommited.',
    );
}

{
    my $data_set_with_additional_feature = Algorithm::LibLinear::DataSet->new(
        data_set => [ +{ feature => +{ 1 => 2.0, 6 => 1.0, }, label => 1, } ],
    );
    lives_and {
        my $scaled_data_set =
            $data_set_with_additional_feature->scale(parameter => $parameter);
        my $scaled_feature = $scaled_data_set->as_arrayref->[0]{feature};
        is 0 + keys %$scaled_feature, 3,
            'New feature should be ommited since scaling factor is unknown.';
    } 'Scaling data set with unknown feature should not raise error.';
}

{
    my $data_set = Algorithm::LibLinear::DataSet->new(
        data_set => [
            +{ feature => +{ 1 => 1, 3 => 1 }, label => 1 },
            +{ feature => +{ 2 => 2 }, label => 1 },
            +{ feature => +{ 2 => 1 }, label => 1 },
        ]
    );
    my $scaling_parameter = Algorithm::LibLinear::ScalingParameter->new(
        data_set => $data_set,
        lower_bound => -1,
        upper_bound => 1,
    );
    my $scaled_data_set = $data_set->scale(parameter => $scaling_parameter);
    my @scaled_features =
        map { $_->{feature} } @{ $scaled_data_set->as_arrayref };
    is_deeply(
        \@scaled_features,
        [
            +{ 1 => 1, 2 => -1, 3 => 1 },
            +{ 1 => -1, 2 => 1, 3 => -1 },
            +{ 1 => -1, 3 => -1 },
        ],
    );
}

done_testing;

__DATA__
+1  1:1.0  2:2.0  3:1.41
+1  1:2.0  2:2.0  3:1.73  4:-1.0  5:1.0
+1  1:3.0  2:2.0  3:2.00  4:-2.0
+1  1:4.0  2:2.0  3:2.23  4:-3.0  5:1.0
