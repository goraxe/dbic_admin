package #hide from pause
  DBICTest::BaseResult;

use strict;
use warnings;

use base qw/DBIx::Class/;
use DBICTest::BaseResultSet;

__PACKAGE__->load_components (qw/Core/);
__PACKAGE__->table ('bogus');
__PACKAGE__->resultset_class ('DBICTest::BaseResultSet');

1;
