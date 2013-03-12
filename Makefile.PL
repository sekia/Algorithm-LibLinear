use inc::Module::Install;

name 'Algorithm-LibLinear';
license 'mit';
all_from 'lib/Algorithm/LibLinear.pm';

requires 'List::MoreUtils';
requires 'Smart::Args';

requires_cplusplus;
use_xshelper '-clean', '-realclean';
cc_include_paths 'src/liblinear', 'src/liblinear/blas';
cc_src_paths 'src';
cc_libs 'stdc++';

tests 't/*.t t/*/*.t t/*/*/*.t';
author_tests 'xt';

test_requires 'Test::Exception::LessClever';
test_requires 'Test::LeakTrace';
test_requires 'Test::More';
auto_set_repository;
auto_include;
WriteAll;
