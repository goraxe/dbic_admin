#
#===============================================================================
#
#         FILE:  Admin.pm
#
#  DESCRIPTION:  Administrative functions for DBIx::Class Schemata
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Gordon Irving (), <Gordon.irving@sophos.com>
#      VERSION:  1.0
#      CREATED:  28/11/09 12:27:15 GMT
#     REVISION:  ---
#===============================================================================

package DBIx::Class::Admin;

use Moose;
use MooseX::Types;
use MooseX::Types::Path::Class;
use Class::C3::Componentised;

=c
		['lib|I:s' => 'Additonal library path to search in'], 
		['schema|s:s' => 'The class of the schema to load', { required => 1 } ],
		['config-stanza|S:s' => 'Where in the config to find the connection_info, supply in form MyApp::Model::DB',],
		['config|C:s' => 'Supply the config file for parsing by Config::Any', { depends => 'config_stanza'} ],
		['connect-info|n:s%' => ' supply the connect info as additonal options ie -I dsn=<dsn> user=<user> password=<pass> '],
		['sql-dir|q:s' => 'The directory where sql diffs will be created'],
		['sql-type|t:s' => 'The RDBMs falvour you wish to use'],
		['version|v:i' => 'Supply a version install'],
		['preversion|p:s' => 'The previous version to diff against',],

    'schema=s'  => \my $schema_class,
    'class=s'   => \my $resultset_class,
    'connect=s' => \my $connect,
    'op=s'      => \my $op,
    'set=s'     => \my $set,
    'where=s'   => \my $where,
    'attrs=s'   => \my $attrs,
    'format=s'  => \my $format,
    'force'     => \my $force,
    'trace'     => \my $trace,
    'quiet'     => \my $quiet,
    'help'      => \my $help,
    'tlibs'      => \my $t_libs,
=cut

=head1 Attributes

=cut
has lib => (
	is		=> 'ro',
	isa		=> 'Dir',
	coerce	=> 1,
	trigger => \&_set_inc,
);

sub _set_inc {
	my ($self, $lib) = @_;
	push @INC, $lib->stringify;
}


has 'schema_class' => (
	is		=> 'ro',
	isa		=> 'ClassName',
	coerce	=> 1,
);

has 'schema' => (
	is			=> 'ro',
	isa			=> 'DBIx::Class::Schema',
	lazy_build	=> 1,
);

sub _build_schema {
	my ($self)  = @_;
	ensure_class_loaded($self->schema_class);
	return $self->schema_class->connect($self->connect_info,  );
}

has 'config_stanza' => (
	is			=> 'ro',
	isa			=> 'Str',
);

has 'sql_dir' => (
	is			=> 'ro',
	isa			=> 'Dir',
	coerce		=> 1,
);

has 'sql_type' => (
	is			=> 'ro',
	isa			=> 'Str',
);

has version => (
	is			=> 'ro',
	isa			=> 'Str',
);

has preversion => (
	is			=> 'rw',
	isa			=> 'Str',
	predicate	=> 'has_preversion',
);

sub create {
	my ($self, $sqlt_type, ) = @_;
	if ($self->has_preversion) {
		print "attempting to create diff file for ".$self->preversion."\n";
	}
	my $schema = $self->schema();
	$schema->create_ddl_dir( $sqlt_type, $schema->schema_version, $self->sql_dir, $self->preversion );
}

sub upgrade {
	my ($self) = @_;
	my $schema = $self->schema();
	if (!$schema->get_db_version()) {
		# schema is unversioned
		warn "could not determin current schema version, please either install or deploy";
	} else {
		$schema->upgrade();
	}
}

sub install {
	my ($self) = @_;

	my $schema = $self->schema();
	if (!$schema->get_db_version()) {
		# schema is unversioned
		print "Going to install schema version";
		$schema->install($self->version);
	} else {
		warn "schema already has a version not installing, try upgrade instead";
	}

}

sub deploy {
	my ($self) = @_;
	my $schema = $self->schema();
	if (!$schema->get_db_version() ) {
		# schema is unversioned
		$schema->deploy();
	} else {
		warn "there already is a database with a version here, try upgrade instead";
	}
}

sub find_stanza {
	my ($self, $cfg, $stanza) = @_;
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

# FIXME ensure option spec compatability
#die('Do not use the where option with the insert op') if ($where);
#die('Do not use the attrs option with the insert op') if ($attrs);
sub insert_data {
	my ($self, $resultset, $set) = @_;
	my $obj = $resultset->create( $set );
    print ''.ref($resultset).' ID: '.join(',',$obj->id())."\n" if (!$self->quiet);
}

sub update_data {
	my ($self, $resultset, $set, $where) = @_;
    $resultset = $resultset->search( ($where||{}) );
    my $count = $resultset->count();
    print "This action will modify $count ".ref($resultset)." records.\n" if (!$self->quiet);
    if ( $self->force || $self->confirm() ) {
        $resultset->update_all( $set );
    }
}

# FIXME
#die('Do not use the set option with the delete op') if ($set);
sub delete_data {
	my ($self, $resultset, $where, $attrs) = @_;

    $resultset = $resultset->search( ($where||{}), ($attrs||()) );
    my $count = $resultset->count();
    print "This action will delete $count ".ref($resultset)." records.\n" if (!$self->quiet);
    if ( $self->force || $self->confirm() ) {
        $resultset->delete_all();
    }
}


#FIXME
# die('Do not use the set option with the select op') if ($set);
sub select_data {
	my ($self, $resultset, $where, $attrs) = @_;

	
    $resultset = $resultset->search( ($where||{}), ($attrs||()) );
}

# TODO, make this more generic, for different data formats
sub output_data {
	my ($self, $resultset) = @_;

#	eval {
#		ensure_class_loaded 'Data::Tabular::Dumper';
#	};
#	if($@) {
#		die "Data::Tabular::Dumper is needed for outputing data";
#	}
	my $csv_class;
	# load compatible CSV generators
	foreach $csv_class (qw(Text::CSV_XS Text::CSV_PP)) {
		eval { ensure_class_loaded $csv_class};
		if($@) {
			$csv_class = undef;
			next;
		} 
	}
	if (not defined $csv_class) {
		die ('The select op requires either the Text::CSV_XS or the Text::CSV_PP module');
	}

    my $csv = $csv_class->new({
       sep_char => ( $self->csv_format eq 'tsv' ? "\t" : ',' ),
    });

    my @columns = $resultset->result_source->columns();
    $csv->combine( @columns );
    print $csv->string()."\n";
    while (my $row = $resultset->next()) {
        my @fields;
        foreach my $column (@columns) {
            push( @fields, $row->get_column($column) );
        }
        $csv->combine( @fields );
        print $csv->string()."\n";
    }
}

sub confirm {
    print "Are you sure you want to do this? (type YES to confirm) ";
    my $response = <STDIN>;
    return 1 if ($response=~/^YES/);
    return;
}

1;
