#!/usr/bin/perl -w
# Alexey Kutsenko, Science for Life Laboratories, okt 2011

package TaxonomyNCBI;
#use diagnostics;

=Usage (example):

    1. To create DB:                                    or             1. To create DB:
	#!/usr/bin/perl -w                                                 #!/usr/bin/perl -w
	use TaxonomyNCBI;                                                  use TaxonomyNCBI; 
	my $db=TaxonomyNCBI->new();                                        my $db=TaxonomyNCBI->new();
	$db->setDirDownload($dir);                                         
	$db->readTaxonomy();                                               $db->readTaxonomy( DIR=>$dir, GI_ref=>\@gi );
	$db->reduceCIlist( @gi | \@gi);                                    
	$db->saveTXTfile($file);                                           $db->saveTXTfile($file);
	$db->saveBINfile($file);                                           $db->saveBINfile($file);
	
	2. To use DB:
	#!/usr/bin/perl -w
	use TaxonomyNCBI; 
	my $db=TaxonomyNCBI->readBINfile($file);
	my $taxid=$db->getGI_TaxonID($gi);
	my $string=$db->getTaxon_toString($taxid);
=cut

=Class public methods:

    "common methods":
	new
	setDirDownload
    getDirDownload         
	deleteDirDownload
	readTaxonomyNCBI  	
	reduceGIlist
	deleteGI
	saveBINfile
	
	"getGI methods":
    getGI_List_toRef       
    getGI_List_toNumber    
    getGI_List_toList      
    getGI_exists           
    getGI_TaxonID   
	
	"getTaxon methods":
    getTaxon_Parent        
    getTaxon_Rank          
	getTaxon_ID4UpperRank
    getTaxon_DivisionCode  
    getTaxon_DivisionDesc  
	getTaxon_toString
    getTaxon_Names_toString
    getTaxon_ScientificName
    getTaxon_CommonName    
    getTaxon_OtherNames    

	"test methods":
	saveTXTfile
    getGI2TAXID_toHash     
=cut

=Class downloads:
# 1. Download and unzip two taxonomy zip file from NCBI: 
# 1.1) "ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdmp.zip"        => "names.dmp"         = "TaxonomyID - Name of Organism"
#                                                              => "nodes.dmp"         = main taxonomy file
names.dmp
---------
Taxonomy names file has these fields:
	tax_id					-- an id of the node (taxon) associated with this name
	name_txt				-- name itself
	unique name				-- the unique variant of the name if the name not unique
	name class				-- (synonym, common name, ...)
Example:
3218    |       Physcomitrella patens   						|               |       scientific name |
3218    |       Physcomitrella patens (Hedw.) Bruch & Schimp.   |               |       authority       |
3847    |       Glycine max     								|               |       scientific name |
3847    |       Glycine max (L.) Merr.  						|               |       authority       |
3847    |       Glycine max; cv. Wye    						|               |       misspelling     |
3847    |       soybean 										|               |       genbank common name     |
3847    |       soybeans        								|               |       common name     |
47644   |       Lessertia       								|               |       scientific name |
47644   |       Lessertia DC.   								|               |       authority       |

nodes.dmp
---------
This file represents taxonomy nodes. The description for each node includes the following fields:
	tax_id					-- node(taxon) id in GenBank taxonomy database
 	parent tax_id				-- parent node (parent taxon) id in GenBank taxonomy database
 	rank					-- rank of this node (superkingdom, kingdom, ...) 
 	embl code				-- locus-name prefix; not unique
 	division id				-- see division.dmp file
 	inherited div flag  (1 or 0)		-- 1 if node inherits division from parent
    ... some more
Example:
38209   |       38208   |       species |       BB      |       4       |       1       |       1       |       1       |       1       |       1    |1       |       0       |               |
38210   |       160024  |       genus   |               |       4       |       1       |       1       |       1       |       1       |       1    |0       |       0       |               |
38211   |       38210   |       species |       SP      |       4       |       1       |       1       |       1       |       1       |       1    |	

# 1.2) "ftp://ftp.ncbi.nih.gov/pub/taxonomy/gi_taxid_nucl.zip" => "gi_taxid_nucl.dmp" = "GenBankID - TaxonomyID" for nucleotide sequences

gi_taxid_nucl.dmp
-----------------
The file is about 160 MB and contains  two columns: the nucleotide's gi and taxid.
Example:
 ACCESSION(GI munber) 	TAXON_ID
 -------------------  	--------
 6227535 				3218
 6227536 				3847
 24000260        		10116
 24000261        		47664
=cut

=Class data structure:
	$self->{DIR} = string                                 # directory to store NCBI ftp files
	$self->{GI} = hash
	$self->{GI}->{$gi} = hash 	
	$self->{GI}->{$gi}->{taxid} = string                  # taxon ID that correspods GI accession
	$self->{TAXON} = hash
	$self->{TAXON}->{$taxid}->{rank} = string             # taxon rank
	$self->{TAXON}->{$taxid}->{parent} = string           # taxon parent ID
	$self->{TAXON}->{$taxid}->{div}->{code} = string      # taxon division code
	$self->{TAXON}->{$taxid}->{div}->{desc} = string      # taxon division name
	$self->{TAXON}->{$taxid}->{desc}->{"scientific name"}  = string      # taxon name 1
	$self->{TAXON}->{$taxid}->{desc}->{"common name"} = string           # taxon name 2
	$self->{TAXON}->{$taxid}->{desc}->{"other names"} = string           # taxon name 3
=cut

1;

# constructor  	# arguments: no ( @_ = ($this) )
sub new {	
	my $this = shift;
	my $class = ref($this) || $this;
	my $self = { 	DIR => undef,
					GI => {},
					TAXON => {}
				};
	bless $self, $class;
	return $self;
}
sub readTaxonomyNCBI { # initialize instance 	# argument: ( [ DIR = > $dir, ] [ GI_ref => \@list_GI_numbers ] )
	my $self = shift;
	# get arguments
	my %arg = ( DIR 	=> undef, # default argument
				GI_ref  => undef, # default argument
				@_ );
	my ( $dir, $gi ) = ( $arg{DIR}, $arg{GI_ref} );
	if ( defined $gi && not (ref $gi eq 'ARRAY' ) ) { die "ERROR: Call <",ref $self,"::readTaxonomyNCBI> : Argument <GI_ref> is not a reference !\n";}
	# initialize
	 if ( defined $dir ) { $self->setDirDownload($dir)  # if dir is     specified in arguments list -> reset the dir
	 } elsif ( defined $self->getDirDownload() ) { 1;   # if dir is NOT specified in arguments list AND was     defined previously -> do nothing
	 } else { $self->setDirDownload() }                 # if dir is NOT specified in arguments list AND was NOT defined previously -> set dir to default
	print STDERR "INFO: Reading Taxonomy:\n      from directory \<",$self->getDirDownload(),"\>\n"; 
	$self->_downloadFiles();
	$self->_readTaxon();
	$gi ? $self->_readGi2Taxid($gi)
	    : $self->_readGi2Taxid();
	return;
}

####################
# get data methods #  (public methods)
####################
sub getDirDownload          { my $self = shift;       return $self->{DIR} }
sub getGI2TAXID_toHash      { my ($self,$gi) = @_;    return $self->{GI} } # ref to hash
sub getGI_List_toRef        { my $self = shift;       return [ sort {$a<=>$b} keys %{$self->{GI}} ] }
sub getGI_List_toNumber     { my $self = shift;       return 0 + keys %{$self->{GI}} } 
sub getGI_List_toList       { my $self = shift;       return     keys %{$self->{GI}} }
sub getGI_TaxonID           { my ($self,$gi) = @_;    return            $self->{GI}->{$gi}->{taxid} }
sub getGI_exists            { my ($self,$gi) = @_;    return     exists $self->{GI}->{$gi} }
sub getTaxon_Parent         { my ($self,$taxid) = @_; return $self->{TAXON}->{$taxid}->{parent} }
sub getTaxon_Rank           { my ($self,$taxid) = @_; return $self->{TAXON}->{$taxid}->{rank} }
sub getTaxon_DivisionCode   { my ($self,$taxid) = @_; return $self->{TAXON}->{$taxid}->{div}->{code} }
sub getTaxon_DivisionDesc   { my ($self,$taxid) = @_; return $self->{TAXON}->{$taxid}->{div}->{desc} }
sub getTaxon_ScientificName { my ($self,$taxid) = @_; return $self->{TAXON}->{$taxid}->{desc}->{"scientific name"} }
sub getTaxon_CommonName     { my ($self,$taxid) = @_; return $self->{TAXON}->{$taxid}->{desc}->{"common name"} }
sub getTaxon_OtherNames     { my ($self,$taxid) = @_; return $self->{TAXON}->{$taxid}->{desc}->{"other names"} }
sub getTaxon_Names_toString { my ($self,$taxid) = @_; my @toString;
	if ( my $s = $self->getTaxon_ScientificName($taxid) ) { push @toString, ((length $s > 45) ? substr($s,0,45)."..." : $s )."[sci]"     };
	if ( my $s = $self->getTaxon_CommonName($taxid) )     { push @toString, ((length $s > 25) ? substr($s,0,25)."..." : $s )."[common]"  };
	if ( my $s = $self->getTaxon_OtherNames($taxid) )     { push @toString, $s  };
	return join(" : ",@toString);
}									 
sub getTaxon_toString { my ($self,$taxid) = @_; my @toString;
						foreach my $s (   
						                $self->getTaxon_Rank($taxid),
						                $self->getTaxon_DivisionCode($taxid) , 
						                $self->getTaxon_DivisionDesc($taxid) ,
                                        $self->getTaxon_Names_toString($taxid)
						              ) { push @toString, $s?$s:""; 	# version 1 = "A:B::D" if C=undef
						                  #$s && push @toString, $s; 	# version 2 = "A:B:D"  if C=undef
						                }
						return join(" : ",@toString);
}
sub getTaxon_ID4UpperRank { my ($self,$taxid,$UpperRank) = @_; 
							do { 	my $rank = $self->getTaxon_Rank($taxid);
									return $taxid if ( defined $rank && $rank eq $UpperRank );
									$taxid = $self->getTaxon_Parent($taxid);
								} while defined $taxid && $taxid != 1;
							return "";
						  }

####################
# set data methods # (public and local methods)
####################
sub setDirDownload 	        { my ($self,$dir) = @_;         $dir ||= "./taxonomyNCBI_tmp_".`date +%Y_%m_%d_%s`; chomp $dir;
                                                            $self->{DIR} = $dir }
sub setGI_TaxonID           { my ($self,$gi,$taxid) = @_;   $self->{GI}->{$gi}->{taxid} = $taxid }
sub deleteGI                { my ($self,$gi) = @_;   delete $self->{GI}->{$gi} } # possible upgrade of the method: delete also respective taxon if applicable
sub setTaxon_Parent         { my ($self,$taxid,$data) = @_; $self->{TAXON}->{$taxid}->{parent} = $data }
sub setTaxon_Rank           { my ($self,$taxid,$data) = @_; $self->{TAXON}->{$taxid}->{rank}  = $data   }
sub setTaxon_DivisionCode   { my ($self,$taxid,$data) = @_; $self->{TAXON}->{$taxid}->{div}->{code}  = $data   }
sub setTaxon_DivisionDesc   { my ($self,$taxid,$data) = @_; $self->{TAXON}->{$taxid}->{div}->{desc}  = $data   }
sub setTaxon_ScientificName { my ($self,$taxid,$data) = @_; $self->{TAXON}->{$taxid}->{desc}->{"scientific name"}  = $data   }
sub setTaxon_CommonName     { my ($self,$taxid,$data) = @_; $self->{TAXON}->{$taxid}->{desc}->{"common name"}  = $data   }
sub setTaxon_OtherNames     { my ($self,$taxid,$data) = @_; $self->{TAXON}->{$taxid}->{desc}->{"other names"}  = $data   }
sub reduceGIlist  { # delete GIs not presented in the input list # argument: (@list_GI_numbers) or (\@list_GI_numbers)
	  my $self = shift;
	  return 1 unless @_;
      my $gi_list = $_[0]; 	                                     
      $gi_list = \@_ unless ( ref $gi_list eq 'ARRAY' );             # if argument is not a reference to a list -> convert to a reference 
      my %tmp;                                                   # set a temporal GI list as a hash
      foreach my $gi (@$gi_list) { chomp $gi; $tmp{$gi}=1 }; 			
	  my $gi_all = $self->getGI_List_toRef();                   # get all GI 
	  foreach my $gi ( @{$gi_all} ) { $self->deleteGI($gi) unless exists $tmp{$gi}; } # delete GIs not presented in the input list
}
sub deleteDirDownload  { # argument: ($directory)
   my ($self,$dir) = @_;
   $dir = $self->getDirDownload() unless $dir;
   system("rm -f $dir/*") == 0 || die "ERROR: Can't remove files in $dir\n$!\n";
   system("if [ -d $dir ]; then rmdir $dir; fi") == 0 || die "ERROR: Can't remove/manipulate the directory $dir\n$!\n";
   print STDERR "INFO: remove directory=$dir\n";
}
sub saveBINfile { use Storable; my ($this,$file) = @_; print STDERR "INFO: Saving to BIN file : <$file> ...\n";    store($this,$file); return }
sub readBINfile { use Storable; my ($this,$file) = @_; print STDERR "INFO: Reading from BIN file : <$file> ...\n"; $this = retrieve($file); return $this }

#####################
# load data methods # (local methods)
#####################
sub _downloadFiles { 		# local method 	# argument: ( [$directory] )
=NCBI taxonomy files need to be downloaded:
	taxdmp.zip:
			nodes.dmp
			names.dmp
			...
	gi_taxid_nucl.zip:
			gi_taxid_nucl.dmp
=cut
   my ($self,$dir) = @_;
   $dir = $self->getDirDownload() unless $dir;
   system("if [ ! -d $dir ]; then mkdir $dir; fi") == 0 || die "ERROR: Can't create/manipulate the directory $dir\n$!\n";
   &_load_AND_unzip($dir,"taxdmp.zip")        unless ( -e "$dir/nodes.dmp" && -e "$dir/names.dmp" );
   &_load_AND_unzip($dir,"gi_taxid_nucl.zip") unless ( -e "$dir/gi_taxid_nucl.dmp" );
   return 1;
   
   sub _load_AND_unzip { # subroutine to download and unzip files
	  my ($dir,$file) = @_;
      print STDERR "INFO: download $file into $dir\n";
      system("curl -o $dir/$file ftp://ftp.ncbi.nih.gov/pub/taxonomy/$file") == 0 || die "ERROR: Can't download $file from NCBI\n";
      print STDERR "INFO: $file downloaded\n";
	  #system("cd $dir; unzip $file 2>&1 1>/dev/null");
	  my $unzip_res = `cd $dir; unzip $file 2>&1`; 
	  print STDERR "$unzip_res";
      print STDERR "INFO: $file unzipped\n";   
   } # end of sub _load_AND_unzip 
}

sub _readTaxon { 		# local method 	# argument: ( [$directory] )
   # read, rearrange and save taxonomy
   # structure of my taxonomy data: see above "=Class data structure:" in the beginning of the package  
   my ($self,$dir) = @_;
   $dir = $self->getDirDownload() unless $dir;
   # open taxonomy files
   my $f1 = "nodes.dmp";
   my $f2 = "names.dmp";
   my $f3 = "division.dmp";
   open (NODES,    "<$dir/$f1" ) || die "ERROR: Can't open taxonomy database file   $f1  : $!\n";
   open (NAMES,    "<$dir/$f2" ) || die "ERROR: Can't open taxonomy database file   $f2  : $!\n";
   open (DIVISION, "<$dir/$f3" ) || die "ERROR: Can't open taxonomy database file   $f3  : $!\n";

   # read division
   my (%division_code,%division_desc); 
   while(<DIVISION>) {
      my ($div_id,$code3char,$desc) = my_local_trim( split(/\|/, $_) );
	  $division_code{$div_id} = $code3char;
	  $division_desc{$div_id} = $desc ;
   }
   
   # read nodes
   print STDERR "INFO: Reading <$f1> : Getting main NCBI taxonomy table ... \n";
   while (<NODES>) { 
      my ($id,$parent,$rank,$tmp2,$div) = my_local_trim( split(/\|/, $_, 6) );
	  $self->setTaxon_Parent($id,$parent);
	  $self->setTaxon_Rank($id,$rank);
	  $self->setTaxon_DivisionCode($id,$division_code{$div});
	  $self->setTaxon_DivisionDesc($id,$division_desc{$div});
   }

   #read names
   print STDERR "INFO: Reading <$f2> : Getting taxon names ... \n";
   while (<NAMES>)    { 
      my ($id,$name,$unique_name,$name_class) = my_local_trim( split(/\|/, $_, 5) );
      if ( $name_class eq "scientific name" ) { $self->setTaxon_ScientificName($id,$name) }
      elsif ( $name_class eq  "common name" ) { $self->setTaxon_CommonName($id,$name) }
      else                                    { my $old_name = $self->getTaxon_OtherNames($id);
	                                            $name = ( $old_name ? $old_name : "" ).$name."[$name_class] ";
	                                            $self->setTaxon_OtherNames($id,$name) };
   }

   close NODES; close NAMES; close DIVISION;   
}

sub _readGi2Taxid { 		# local method 	# arguments: ( [\@list_GI_numbers] )
   my $self = shift;
   my $gi_list = shift;     # if applicable an argument is a refernece to GI list

   # open taxonomy files
   my $dir = $self->getDirDownload();
   my $f1 = "gi_taxid_nucl.dmp";
   print STDERR "INFO: Reading <$f1> : Getting pairs \"Genebank accession(GI)\" - \"taxon ID\" \n";
   open (GI_TAXID,   "<$dir/$f1" ) || die "ERROR: Can't open $f1 : $!\n";
   # for a friendly interface: progression bar
	# count number of lines in the file: 
	my $lines = `wc -l $dir/$f1 | awk '{print \$1}'`; 	# slowest method
	#my $lines = `cat -n $dir/$f1 | tail -1 | awk '{print \$1}'`; 	# twice faster
	#my $lines = `tail -n +200000000 $dir/$f1 | wc -l` + 200000000; 	# fourfold faster (works if lines number > 200000000 )
	#my $lines = 218000000;
   my $lpd = 1*1e7; # for nice output: "lines per dot"
   print STDERR "      ","_" x ( int($lines/$lpd) + 1 ),"\n      ";
   
   # set a temporal GI list as a hash if applicable
   my %tmp; 
   if ( ref $gi_list eq 'ARRAY' ) {  
      foreach my $gi (@$gi_list) { chomp $gi; $tmp{$gi}++ };        
   }
   
   # read pairs "GI accession"->"taxon ID"
   my $line;
   while ($line = <GI_TAXID>) { 
      print STDERR "." if $. % $lpd == 0; 		  # for a friendly interface: progression bar runs
      my ($gi,$taxid ) = split (/\s+/, $line);
	  next if ( defined $gi_list && not exists $tmp{$gi}); # skip GIs not presented in the input list if applicable (if the list exists)
      $self->setGI_TaxonID($gi,$taxid);           # get all GIs OR # get only GIs presented in the input list if the list exists
   }
   close GI_TAXID; 
   print STDERR ".\n";
   return;  
}

####################
# inside functions #
####################
sub my_local_trim { my @a = @_; foreach (@a) { s/\s+//; s/\s+$// }; return @a } # to trim whitespace (spaces and tabs) from the beginning and end of every string in an array

################
# test methods #
################
sub saveTXTfile {
	my ($self,$f) = @_;
	print STDERR "INFO: Saving to TXT file : <$f> ...\n";
	open(FL, ">$f" ) || die "ERROR: Can't open file  $f  for writing: $!\n";
	  my $gi_list = $self->getGI_List_toRef(); 			# get all GI 
	foreach my $gi ( @{$gi_list} ) {
		$tax=$self->getGI_TaxonID($gi);
		printf FL "%9i %s # %s\n", $gi,$tax,$self->getTaxon_toString($tax);
	}
	close FL || die "ERROR: Can't close file  $f  after writing: $!\n";
}	
