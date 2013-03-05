use inc::Module::Install;

name 'Algorithm-LibLinear';
all_from 'lib/Algorithm/LibLinear.pm';

checklibs lib => 'blas';

requires_cplusplus;
use_xshelper '-clean', '-realclean';
cc_include_paths 'src/liblinear';
cc_src_paths 'src';
cc_libs 'blas', 'stdc++';

tests 't/*.t';
author_tests 'xt';

test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
