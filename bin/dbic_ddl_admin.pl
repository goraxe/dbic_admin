#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  dbic_ddl_admin.pl
#
#        USAGE:  ./dbic_ddl_admin.pl 
#
#  DESCRIPTION:  script to create, 
#
#       AUTHOR:  Gordon Irving (), <goraxe@goraxe.me.uk>
#      VERSION:  1.0
#      CREATED:  15/11/09 11:48:34 GMT
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use Getopt::Long::Descriptive;

use FindBin qw($Bin);
use Path::Class;
use lib dir($Bin,'..','lib')->stringify;

use Module::Load;

my ($opts, $usage) = describe_options(
	"%c: %o",
	(
		['Actions'],
		["action" => hidden => { one_of => [
			['create|c' => 'Create version diffs needs preversion',],
			['upgrade|u' => 'Upgrade the database to the current schema '],
			['install|i' => 'Install the schema to the database',],
			['deploy|d' => 'Deploy the schema to the database',],
			['help|h' => 'display this help'],
		], required=> 1 }],
		['Options'],
		['lib|I:s' => 'Additonal library path to search in'], 
		['schema|s:s' => 'The class of the schema to load', { required => 1 } ],
		['config-stanza|S:s' => 'Where in the config to find the connection_info, supply in form MyApp::Model::DB',],
		['config|C:s' => 'Supply the config file for parsing by Config::Any', { depends => 'config_stanza'} ],
		['connect-info|n:s%' => ' supply the connect info as additonal options ie -I dsn=<dsn> user=<user> password=<pass> '],
		['sql-dir|q:s' => 'The directory where sql diffs will be created'],
		['sql-type|t:s' => 'The RDBMs falvour you wish to use'],
		['version|v:i' => 'Supply a version install'],
		['preversion|p:s' => 'The previous version to diff against',],
	)
);


if ($opts->{help}) {
	print $usage->text;
	exit 0;
}

if (exists $opts->{lib}) {
	push @INC, $opts->{lib};
}

my $connect_info = [];
my $schema_class= $opts->{schema};

# load the schema class
load $schema_class; 

# just load the config, return a hash
my $config;
if ($opts->{config}) {
	eval "require Config::Anyf;" or die "Config::Any is required to parse the config";
	my $cfg = Config::Any->load_files ( {files => [$opts->{config}], use_ext =>1, flatten_to_hash=>1});

	# just grab the config from the config file
	$cfg = $cfg->{$opts->{config}};
	$config = find_stanza($cfg, $opts->{config_stanza});

}

my $sql_dir = $opts->{sql_dir} || $config->{sql_dir} || './sql';

if ($opts->{connect_info}) {
	$opts->{connect_info}->{ignore_version} = 1;
	push @$connect_info, $opts->{connect_info};
}
else {
	$connect_info = $config->{connect_info};
}

# initalise the schema object
my $schema = $schema_class->connect(@$connect_info, {ignore_version => 1});
my $version = $opts->{version} || $schema->schema_version();
my $sqlt_type = $opts->{sql_type} || $schema->storage->sqlt_type();

$schema->upgrade_directory($sql_dir);

my $action = $opts->{action};
print "going to perform action $action\n";
main->$action();

sub create {
	if (exists $opts->{preversion} ) {
		print "attempting to create diff file for $opts->{preversion}\n";
	}
	$schema->create_ddl_dir( $sqlt_type, $version, $sql_dir, $opts->{preversion} );
}

sub upgrade {
	if (!$schema->get_db_version()) {
		# schema is unversioned
		warn "could not determin current schema version, please either install or deploy";
	} else {
		$schema->upgrade();
	}
}

sub install {
	if (!$schema->get_db_version()) {
		# schema is unversioned
		print "Going to install schema version";
		$schema->install($version);
	} else {
		warn "schema already has a version not installing, try upgrade instead";
	}

}

sub deploy {
	if (!$schema->get_db_version() ) {
		# schema is unversioned
		$schema->deploy();
	} else {
		warn "there already is a database with a version here, try upgrade instead";
	}
}

sub find_stanza {
	my ($cfg, $stanza) = @_;
	my @path = split /::/, $stanza;
	while (my $path = shift @path) {
		if (exists $cfg->{$path}) {
			$cfg = $cfg->{$path};
		}
		else {
			die "could not find $stanza in config, $path did not seem to exist";
		}
	}
	return $cfg;
}

