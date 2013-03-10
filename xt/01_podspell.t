use Test::More;
eval q{ use Test::Spelling };
plan skip_all => "Test::Spelling is not installed." if $@;
add_stopwords(map { split /[\s\:\-]/ } <DATA>);
$ENV{LANG} = 'C';
all_pod_files_spelling_ok('lib');
__DATA__
Koichi SATOH
sato@seesaa.co.jp
Algorithm::LibLinear
LIBLINEAR
LIBSVM
MERCHANTABILITY
NONINFRINGEMENT
Redistributions
sublicense
