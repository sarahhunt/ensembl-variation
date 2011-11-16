=head1 LICENSE

 Copyright (c) 1999-2011 The European Bioinformatics Institute and
 Genome Research Limited.  All rights reserved.

 This software is distributed under a modified Apache license.
 For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <dev@ensembl.org>.

 Questions may also be sent to the Ensembl help desk at
 <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::Variation::Utils::BaseVepPlugin

=head1 SYNOPSIS

    package FunkyPlugin;

    use Bio::EnsEMBL::Variation::Utils::BaseVepPlugin;

    use base qw(Bio::EnsEMBL::Variation::Utils::BaseVepPlugin);
    
    sub feature_types {
        return ['Transcript'];
    }

    sub get_header_info {
        return {
            FunkyPlugin => "Description of funcky plugin"
        };
    }

    sub run {
        my ($self, $transcript_variation_allele) = @_;

        # do analysis
        
        my $results = ...
        
        return {
            FunkyPlugin => $results
        };
    }

    1;

=head1 DESCRIPTION

To make writing plugin modules for the VEP easier, get 
your plugin to inherit from this class, override (at least)
the feature_types, get_header_info and run methods to behave
according to the documentation below, and then run the VEP
with your plugin with --plugin <module name>

=cut

package Bio::EnsEMBL::Variation::Utils::BaseVepPlugin;

use strict;
use warnings;

=head2 new

  Arg [1]    : a VEP configuration hashref
  Description: Creates and returns a new instance of this plugin
  Returntype : Bio::EnsEMBL::Variation::Utils::BaseVepPlugin instance (most likely a subclass)
  Status     : Experimental

=cut

sub new {
    my $class = shift;
    
    my $config = shift;

    return bless {
        config          => $config,
        feature_types   => ['Transcript'],
    }, $class;
}

=head2 config

  Arg [1]    : a VEP configuration hashref
  Description: Get/set the VEP configuration hashref
  Returntype : hashref 
  Status     : Experimental

=cut

sub config {
    my ($self, $config) = @_;
    $self->{config} = $config if $config;
    return $self->{config};
}

=head2 get_header_info

  Description: Return a hashref with any Extra column keys as keys and a description
               of the data as a value, this will be included in the VEP output file 
               header to help explain the data produced by this plugin
  Returntype : hashref 
  Status     : Experimental

=cut

sub get_header_info {
    my ($self) = @_;
    return undef;
}

sub prefetch {
    my ($self) = @_;
    return undef;
}

=head2 feature_types

  Description: To indicate which types of genomic features a plugin is interested
               in, plugins should return a listref of the types of feature they can deal 
               with. Currently this list can only include 'Transcript', 'RegulatoryFeature'
               and 'MotifFeature'
  Returntype : listref
  Status     : Experimental

=cut

sub feature_types {
    my ($self, $types) = @_;
    $self->{feature_types} = $types if $types;
    return $self->{feature_types};
}

=head2 check_feature_type
  
  Arg[1]     : the feature type as a string or as a reference to an object
  Description: Check if this plugin is interested in a particular feature type 
  Returntype : boolean
  Status     : Experimental

=cut

sub check_feature_type {
    my ($self, $type) = @_;

    # if we're passed an object instead of a type string
    # get the type of reference
    if (ref $type) {
        $type = ref $type;
    }

    for my $t (@{ $self->{feature_types} }) {
        if ($type =~ /$t/i) {
            return 1;
        }
    }

    return 0;
}

=head2 run

  Arg[1]     : An instance of a subclass of Bio::EnsEMBL::Variation::VariationFeatureOverlapAllele
  Description: Run this plugin, this is where most of the plugin logic should reside. 
               When the VEP is about to finish one line of output (for a given variant-feature-allele 
               combination) it will call this method, passing it a relevant subclass of a
               Bio::EnsEMBL::Variation::VariationFeatureOverlapAllele object according to 
               feature types it is interested in, as returned by the feature_types method:
               
               feature type         argument type
               'Transcript          Bio::EnsEMBL::Variation::TranscriptVariationAllele
               'RegualtoryFeature'  Bio::EnsEMBL::Variation::RegulatoryFeatureVariationAllele
               'MotifFeature'       Bio::EnsEMBL::Variation::MotifFeatureVariationAllele

               Once the plugin has done its analysis it should return the results as a hashref
               with a key for each type of data (which should match the keys described in 
               get_header_info) and a corresponding value for this allele object. Please refer
               to the variation API documentation to see what methods are available on each
               of the possible classes, bearing in mind that common functionality can be found
               in the VariationFeatureOverlapAllele superclass.

  Returntype : hashref
  Status     : Experimental

=cut

sub run {
    my ($self, $tva) = @_;
    warn "VEP plugins should implement the 'run' method\n";
    return undef;
}

1;

