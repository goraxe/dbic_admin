#
#===============================================================================
#
#         FILE:  01load.t
#
#  DESCRIPTION:  
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Gordon Irving (), <Gordon.irving@sophos.com>
#      COMPANY:  Sophos
#      VERSION:  1.0
#      CREATED:  28/11/09 13:54:30 GMT
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Test::More;                      # last test to print

use Path::Class;
use FindBin qw($Bin);
use lib dir($Bin, '..','lib')->stringify;
use lib dir($Bin,'lib')->stringify;

use ok 'DBIx::Class::Admin';

use DBICTest;
my $schema = DBICTest->init_schema(
    no_deploy=>1,
    no_populate=>1,
	);

my $admin = DBIx::Class::Admin->new(schema=> $schema);
$admin->create('MySQL');

done_testing;
