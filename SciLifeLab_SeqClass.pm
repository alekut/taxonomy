package SciLifeLab_SeqClass;
#use diagnostics;

=Usage (example):
	#!/usr/bin/perl -w
	use SciLifeLab_SeqClass;
	....
	{ # tag TaxonomyNCBI.pm class and add to the DB the NCBI's Taxonomy 
		$db->tagTaxonomyNCBI();
		$db->setDirDownload($dir);
		$db->readTaxonomyNCBI(@gi);
	}
=cut

=Class data structure:
=cut

=Class public methods:
	new
	reduceGIlist
	tagClass_TaxonomyNCBI
=cut

=Class downloads:
=cut

require   TaxonomyNCBI;
@ISA = qw(TaxonomyNCBI);
1;

# constructor
# usage: $my_db = SciLifeLab_SecClass->new($dir,@list_GI_numbers) or ...->new($dir,\@list_GI_numbers)
sub createDB {
	my $this  = shift;
	my $class = ref $this || $this;
	my $self  = {  GI => {}  };
	bless $self, $class;
	# get arguments
	my %arg = ( DIR 	            => undef, # default argument
				GI_ref              => undef, # default argument
				includeTaxonomyNCBI => "yes", # default argument
				@_ );
	my ( $dir, $gi_ref, $ncbi ) = ( $arg{DIR}, $arg{GI_ref}, lc $arg{includeTaxonomyNCBI} );
	if ($gi_ref && not (ref $gi_ref eq 'ARRAY' ) ) {die "ERROR: Call <",$class,"::createDB> : Argument <GI_ref> is not a reference !\n"}
	# initialize
	if ($gi_ref) { $self->_readGIfromBLAST($gi_ref);
	} else       { $self->_readGIfromBLAST(); }
	if ( $ncbi eq "yes" ) { 	# tag TaxonomyNCBI.pm class and add the NCBI's Taxonomy DB to my DB 
		#print STDERR "$class: gi_ref=",$gi_ref,"\n";
		#print STDERR "ok if \$gi_ref" if $gi_ref;
		#$gi_ref ? $self->readTaxonomyNCBI( DIR => $dir, MODE => "array_ref", GI_ref => $gi_ref ) 
		#		: $self->readTaxonomyNCBI( DIR => $dir, MODE => "get_GI_from_BLAST" );  
		my $gi_ref = $self->getGI_List_toRef();
#		print "STEP 1 >>>>>>>>>>>>>> $class: >>>>>>>>>>>>>>>>>>>\n";
#		print "gi_ref=$gi_ref\n";
#		foreach my $gi ( @{$gi_ref} ) { print "$gi\n"; }
		$self->readTaxonomyNCBI( DIR => $dir, GI_ref => $gi_ref );
=a		print "STEP 7 >>>>>>>>>>>>>> $class: 2 (END) ( after readTaxonomy )  >>>>>>>>>>>>>>>>>>>\n"; # step 7

	my $a = $self->getGI_List_toRef(); # step 7
	foreach my $g ( @{$a} ) { my $tax = $self->getGI_TaxonID($g);
							printf "g=$g, # tax(->)=%s tax(\$)=%s # DivCod=%s # string=%s\n",
							$self->getGI_TaxonID($g),
							$tax,
							$self->getTaxon_DivisionCode($tax),
							$self->getTaxon_toString($tax); }#step 7
=cut
        if ($self->can("getGI_TaxonID") ) {
		   foreach my $gi (  @{$gi_ref} ) { $self->setGI_MyClassification01($gi) }
		   print STDERR "INFO: \"My Classiification\" is added to the database\n";
		} else {
		   print STDERR "INFO: \"My Classiification\" is not added to the database - because \"Taxonomy NCBI\" is not downloaded!\n";
		}
		print STDERR "INFO: Database created! Number of sequences = ",$self->getGI_List_toNumber(),"\n";

=b		print "STEP 8 >>>>>>>>>>>>>> $class: 2 (END) ( after readTaxonomy )  >>>>>>>>>>>>>>>>>>>\n"; # step 8

	my $a = $self->getGI_List_toRef(); # step 8
	foreach my $g ( @{$a} ) { my $tax = $self->getGI_TaxonID($g);
							printf "g=$g, # MyClass=%s # tax(->)=%s tax(\$)=%s # DivCod=%s # string=%s \n",
							$self->getGI_MyClassification01($g),
							$self->getGI_TaxonID($g),
							$tax,
							$self->getTaxon_DivisionCode($tax),
							$self->getTaxon_toString($tax); }#step 8
=cut							
	}
	return $self;
}              

####################
# get data methods # (public methods)
####################
sub getGI_List_toRef         { my $self = shift;    return [ sort {$a<=>$b} keys %{$self->{GI}} ] }
sub getGI_List_toNumber      { my $self = shift;    return 0 + keys %{$self->{GI}} } 
sub getGI_List_toList             { my $self = shift;    return keys %{$self->{GI}} }
sub getGI_exists             { my ($self,$gi) = @_; return exists $self->{GI}->{$gi} }
sub getGI_Desc               { my ($self,$gi) = @_; return $self->{GI}->{$gi}->{DESC} if exists $self->{GI}->{$gi} }
sub getGI_MyClassification01 { my ($self,$gi) = @_; return $self->{GI}->{$gi}->{MyClassification01} if exists $self->{GI}->{$gi} } # classification by Fredrik Lysholm

####################
# set data methods # (public methods)
####################
sub setGI_Desc { my ($self,$gi,$data) = @_; $self->{GI}->{$gi}->{DESC} = $data; }
sub deleteGI   { my ($self,$gi) = @_; delete $self->{GI}->{$gi} }
sub setGI_MyClassification01 { # classification by Fredrik Lysholm # argument: GI 
	my ($self,$gi) = @_; 
	# get data
	$self->can("getGI_TaxonID") || die "object $self can't method getGI_TaxonID - Taxonomy NCBI not added!\n";
	my $tax = $self->getGI_TaxonID($gi); 			# get taxons ID
	return unless defined $tax;
	my $div = $self->getTaxon_DivisionCode($tax); 	# get taxons division
	my $seq = $self->getGI_Desc($gi); 				# get GI description (sequence description) 
	# set data
	my $data = myClassification01($div,$seq);
	$self->{GI}->{$gi}->{MyClassification01} = $data;
}
sub saveBINfile { use Storable; my ($this,$file) = @_; print STDERR "INFO: Saving to BIN file : <$file> ...\n";    store($this,$file); }
sub readBINfile { use Storable; my ($this,$file) = @_; print STDERR "INFO: Reading from BIN file : <$file> ...\n"; $this = retrieve($file); return $this }

#####################
# load data methods # (public and local methods)
#####################
sub _readGIfromBLAST {  	# local method 	# argument: (@list_GI_numbers) or (\@list_GI_numbers)
	my $self = shift;

	my %tmp;
	if ( @_ != 0 ) { # @_ = GI list if applicable
		my $gi_list = $_[0];                               # set argument as a reference to list if applicable
		$gi_list = \@_ unless ( ref $gi_list eq 'ARRAY' ); 
		foreach my $gi (@$gi_list) { $tmp{$gi}++ };        # set a temporal GI list as a hash if applicable
	}
	
	# get access to BLAST database
	#   "To Do" in UNIX before run this program:
	#   module load bioinfo-tools;
	#   module load blast;
	#   export BLASTDB=/bubo/nobackup/uppnex/blast_databases;"
	my $blastDB = "nt";
	chomp ( my $environmental_var_BLASTDB = `echo \$BLASTDB` );
	( $environmental_var_BLASTDB ) ?
		print STDERR "INFO: (Environmental variable for access to BLAST databases is set to BLASTDB=$environmental_var_BLASTDB)\n" 
		: 
		die "ERROR: Environmental variable for BLAST databases access is NOT set: BLASTDB=$environmental_var_BLASTDB\n";
	print STDERR "INFO: Processing BLAST database \"$blastDB\" : ";
	
	# for nice output: progression bar
	my $sequences = `fastacmd -d $blastDB -I | awk 'NR==3 {print \$1}' | tr -d ','`; 
	print STDERR "Number of sequences = ",$sequences+0,"\n";
	my $spd = 5*1e5; # for nice output: sequences per dot
	print STDERR "      ","_" x ( int ($sequences/$spd) + 1 ),"\n      ";
	
	# get from BLAST database GIs and their descriptions 
	#my $pln = "fastacmd -d $blastDB -D1 | egrep '^>' | head -100000"; # for test
	my $pln = "fastacmd -d $blastDB -D1 | egrep '^>' ";
	open(P, "-|", $pln) || die("ERROR: Unable to launch process: $pln.\n");
	while (<P>) {	print STDERR "." if $. % $spd == 0;
					my ($gi,$desc)=split(/\s+/,$_,2);
					$gi =~ /gi\|(\d+)/; 
					if ( defined $1 ) {	$gi = $1; 
						next if ( @_ != 0 && not exists $tmp{$gi} ); # skip GIs not presented in the input list if applicable (if the list exists)
						chomp $desc;
						$self->setGI_Desc($gi,$desc);  # get all GIs OR # get only GIs presented in the input list if the list exists
					}
				}
	close(P);
	print STDERR ".\n";
}

####################
# inside functions # (local)
####################
sub myClassification01 { # classification by Fredrik Lysholm # arguments: GI description and taxons division
=documentation
	# classification by Fredrik Lysholm:
	"U" => if division field is missed in input data for some reason (filed for division in file "nodes.dmp" is empty?)
	"P" => division="Phages" or ((division="Bacteria" or "Viruses" or "Environment") and GI contains word "phage" )
	"M" => division="Mammals" or "Primates" or "Rodents"
	"B" => division="Bacteria" or (division="Environment" and GI contains word "bacteri")
	"E" => division="Environment" or "Synthetic" or "Unassigned";
	"V" => division="Viruses"
	"O" => other: division="Plants" or "Invertebrates" or "Vertebrates" or ""
=cut
	my ($div,$seq) = @_;
	# note! order is important!
	return "U" if (! defined $div);
	return "M" if ($div eq "MAM" || $div eq "PRI" || $div eq "ROD");
	return "P" if ($div eq "PHG" || (($div eq "BCT" || $div eq "VRL" || $div eq "ENV") && $seq =~ m/phage/i));
	return "V" if ($div eq "VRL");
	return "B" if ($div eq "BCT" || ($div eq "ENV" && $seq =~ m/bacteri/i));
	return "E" if ($div eq "ENV" || $div eq "SYN" || $div eq "UNA");
	return "O";
#	return "U" if ($div eq "UNK"); # there is no "UNK" division code in the NCBI taxonomy data
}

################
# test methods #
################
sub saveTXTfile {
	my ($self,$f) = @_;
	print STDERR "INFO: Saving to TXT file : <$f> ...\n";
	open(FL, ">$f" ) || die "ERROR: Can't open file  $f  for writing: $!\n";
	  my $gi_list = $self->getGI_List_toRef(); 		
#print STDERR 	  "$gi_list  no: ",$self->getGI_List_toNumber(),"\n";
	foreach my $gi ( @{$gi_list} ) {    # get all GI as keys of hash
		if ( defined $self->{TAXON} ) {
		         $tax=$self->getGI_TaxonID($gi);
		         printf FL "%9i %s # %s # %s # %s\n", 
				 $gi,
				 ($tax ||= "" ),
				 (my $x = $self->getTaxon_toString($tax) || "" ),
				 (my $y = $self->getGI_MyClassification01($gi) || "" ),
				 (my $z = $self->getGI_Desc($gi) || "" );
		} else { printf FL "%9i # %s\n", $gi,(my $x = $self->getGI_Desc($gi) || ""); }
	}
	close FL || die "ERROR: Can't close file  $f  after writing: $!\n";
}

