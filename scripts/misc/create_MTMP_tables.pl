#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.



=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk.org>.

=cut

## script to create a tables of evidence values and/or population genotypes for mart building

## evidence tables are always re-created even if present (may change)
## population genotype tables are only created if missing (don't change)
## the population genotype table is not created for human


use strict;
use warnings;
use DBI;
use Getopt::Long;

my ($db, $host, $user, $pass, $mode, $tmpdir, $filename);

GetOptions ("db=s"    => \$db,
            "host=s"  => \$host,
            "user=s"  => \$user,
            "pass=s"  => \$pass,
            "mode:s"  => \$mode,
            "tmpdir:s" => \$tmpdir,
            "tmpfile:s" => \$filename,
    );

die usage() unless defined $host && defined $user && defined $pass && defined $mode;

$tmpdir ||= `pwd`;
chomp $tmpdir;

my $databases;
if( defined $db){
    push @{$databases}, $db;
}
else{
    ## find all variation databases on the host
    $databases = get_dbs_by_host($host, $user, $pass);
} 

if($mode =~/evi/){
    create_mtmp_evidence($databases);
}
elsif($mode =~/pop_geno/){
    create_mtmp_population_genotype($databases);
}
elsif($mode =~/both/){
    create_mtmp_evidence($databases);
    create_mtmp_population_genotype($databases);
}
else{
    warn "\nERROR: Mode needed\n\n";
    die usage();
}

sub create_mtmp_evidence{

  my $databases =shift;

  foreach my $db_name (@{$databases}){
    
    my $dbh = DBI->connect( "dbi:mysql:$db_name\:$host\:3306", $user, $pass, undef);

    $dbh->do(qq[update variation set evidence_attribs = NULL where evidence_attribs = '';]);
    $dbh->do(qq[update variation_feature set evidence_attribs = NULL where evidence_attribs = '';]);
    $dbh->do(qq[update variation set clinical_significance = NULL where clinical_significance = '';]);
    $dbh->do(qq[update variation_feature set clinical_significance = NULL where clinical_significance = '';]);

    $dbh->do(qq[drop table if exists MTMP_evidence]);    
    $dbh->do(qq[create table MTMP_evidence (
              variation_id int(10) , 
              evidence SET('Multiple_observations','Frequency','HapMap','1000Genomes','Cited','ESP','Phenotype_or_Disease'), 
              primary key( variation_id ) ) ])||die;

    
    my $evidence_id = get_evidence_id($dbh);

    
    $filename = "$db_name\.dat" unless defined $filename;
    open my $out, ">$tmpdir/$filename"||die "Failed to open $filename to write evidence statuses : $!\n"; 
    
    my $ev_ext_sth  = $dbh->prepare(qq[ select variation_id, evidence_attribs from variation ]);
    
    my $ev_ins_sth  = $dbh->prepare(qq[ insert into  MTMP_evidence variation_id ,evidence
                                    values (?,?)
                                  ]);
    
    $ev_ext_sth->{mysql_use_result} = 1;
    $ev_ext_sth->execute()||die ;
    

    while ( my $aref = $ev_ext_sth->fetchrow_arrayref() ) {
        
        unless(defined $aref->[1]){
            print $out "$aref->[0]\t\\N\n";
            next;
        }
        
        my @ev_old = split/\,/, $aref->[1];
        
        my @ev_new;
    
        foreach my  $old(@ev_old){ 
            
            die "No id for $old\n" unless defined  $evidence_id->{$old}; 
            push @ev_new, $evidence_id->{$old};             
        }
        
        my $new = join(",", @ev_new);
        
        print $out "$aref->[0]\t$new\n";
        
    }

    close $out;

    $dbh->do( qq[ LOAD DATA LOCAL INFILE "$tmpdir/$filename" INTO TABLE  MTMP_evidence]) || die "Error loading $filename data \n";
    unlink "$tmpdir/$filename" || warn "Faile
d to remove temp file: $tmpdir/$filename :$!\n";
  }
}

sub get_evidence_id{

    my $dbh = shift;

    my %ids;
    
    my $att_ext_sth  = $dbh->prepare(qq[ select attrib.attrib_id, attrib.value
                                     from attrib, attrib_type
                                     where  attrib_type.code ='evidence'
                                     and attrib.attrib_type_id =attrib_type.attrib_type_id
                                    ]);

    $att_ext_sth->execute()||die;
    my $attdata = $att_ext_sth->fetchall_arrayref();
    foreach my $l(@{$attdata}){

        $ids{$l->[0]} = $l->[1];
    }

    return \%ids;
}

sub create_mtmp_population_genotype{
  my $databases = shift;

  foreach my $db_name (@{$databases}){

    ## this table is not created for human databases as it is too large to use
    next if $db_name =~/homo_sapiens/;

    my $dbh = DBI->connect( "dbi:mysql:$db_name\:$host\:3306", $user, $pass, undef);

    ## no need to re-create if the table is already present for a new import
    my $check_present_sth = $dbh->prepare(qq[show tables like 'MTMP_population_genotype']);
    $check_present_sth->execute()||die "Failed to check for existing tables \n";
    my $dat = $check_present_sth->fetchall_arrayref();
    next if $dat->[0]->[0] eq 'MTMP_population_genotype';

    print "Creating MTMP_population_genotype for $db_name\n";
    $dbh->do(qq[CREATE TABLE `MTMP_population_genotype` (
            `population_genotype_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
            `variation_id` int(10) unsigned NOT NULL,
            `subsnp_id` int(15) unsigned DEFAULT NULL,
            `allele_1` varchar(25000) DEFAULT NULL,
            `allele_2` varchar(25000) DEFAULT NULL,
            `frequency` float DEFAULT NULL,
            `population_id` int(10) unsigned DEFAULT NULL,
            `count` int(10) unsigned DEFAULT NULL,
            PRIMARY KEY (`population_genotype_id`),
            UNIQUE KEY `pop_genotype_idx` (`variation_id`,`subsnp_id`,`frequency`,`population_id`,`allele_1`(5),`allele_2`(5)),
            KEY `variation_idx` (`variation_id`),
            KEY `subsnp_idx` (`subsnp_id`),
            KEY `population_idx` (`population_id`)
            ) ENGINE=MyISAM DEFAULT CHARSET=latin1 ]);

    $dbh->do(qq[INSERT IGNORE INTO MTMP_population_genotype
            SELECT p.population_genotype_id, p.variation_id, p.subsnp_id, 
                   ac1.allele, ac2.allele, p.frequency, p.population_id, p.count
            FROM population_genotype p, genotype_code gc1, genotype_code gc2, allele_code ac1, allele_code ac2
            WHERE p.genotype_code_id = gc1.genotype_code_id  
            AND gc1.haplotype_id = 1 
            AND gc1.allele_code_id = ac1.allele_code_id
            AND p.genotype_code_id = gc2.genotype_code_id 
            AND gc2.haplotype_id = 2 
            AND gc2.allele_code_id = ac2.allele_code_id]);
    }
}

sub usage{

    die "\n\tUsage: create_MTMP_tables.pl -host [host] 
                                     -user [write-user name] 
                                     -pass [write-user password] 
                                     -mode [evidence|pop_geno|both]\n

\t\tOptions: -db [database name]    default: all* variation databases on the host
\t\t         -tmpdir [directory for temp files]
\t\t         -tmpfile [ name for temp files]

\t\t* Note: MTMP_population_genotype is not required for human databases\n\n";

}
    
sub get_dbs_by_host{

    my ($host, $user, $pass) = @_;

    my @databases;

    my $dbh = DBI->connect("dbi:mysql:information_schema:$host:3306", $user, $pass, undef);

    my $db_ext_sth = $dbh->prepare(qq[ show databases like '%variation%']);

    $db_ext_sth->execute()||die;
    my $db_list = $db_ext_sth->fetchall_arrayref();
    foreach my $l(@{$db_list}){
        next if $l->[0] =~/master/;
        print "Doing $l->[0] on $host\n";
        push @databases, $l->[0] ;
    }

    return \@databases;
}
